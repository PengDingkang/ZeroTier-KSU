"""Service lifecycle must preserve WireGuard and other modules' policy rules."""
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

ZT_ROUTES = [
    "10.122.100.0/24 dev ztu5coiqzg proto kernel scope link src 10.122.100.240",
    "10.10.0.0/16 via 10.122.100.1 dev ztu5coiqzg proto static metric 5000",
]
OTHER_ROUTES = [
    "10.1.133.0/24 dev wlan0 proto kernel scope link src 10.1.133.15",
    # Two VPN users (e.g. owner and a second space) share the same tun subnet.
    "172.19.0.0/30 dev tun0 proto kernel scope link src 172.19.0.1",
    "172.19.0.0/30 dev tun1 proto kernel scope link src 172.19.0.1",
]

FAKE_IP = '''import json, os, sys
from pathlib import Path
p = Path(os.environ["IP_STATE"])
args = sys.argv[1:]
if args[:1] == ["-4"]:
    args = args[1:]
state = json.loads(p.read_text())
if args[:2] == ["route", "show"]:
    print("\\n".join(state["routes"]))
    sys.exit(0)
if args[:1] != ["rule"]:
    sys.exit(0)
rules = state["rules"]
if args[1] == "show":
    for pref, dst in sorted(rules, key=lambda r: r[0]):
        print("%d:\\tfrom all %slookup main " % (pref, "to %s " % dst if dst else ""))
    sys.exit(0)
pref = int(args[args.index("pref") + 1])
dst = args[args.index("to") + 1] if "to" in args else None
if args[1] == "add":
    if [pref, dst] in rules:
        sys.exit(2)
    rules.append([pref, dst])
elif args[1] == "del":
    # Like the kernel, an omitted selector matches any value.
    match = [r for r in rules if r[0] == pref and (dst is None or r[1] == dst)]
    if not match:
        sys.exit(2)
    rules.remove(match[0])
p.write_text(json.dumps(state))
'''

DRIVER = '''. "$1/functions.sh"
hostname() { :; }
sleep() { :; }
kill() { :; }
killall() { :; }
nohup() { :; }
ip() { python3 "$FAKE_IP" "$@"; }
checks=0
bin_status() {
  checks=$((checks + 1))
  [ "$FAIL_START" = 0 ] || return 1
  case "$checks" in 2|3) return 0 ;; *) return 1 ;; esac
}
start_service
cp "$IP_STATE" "$AFTER_START"
if [ -n "$ROUTES_AFTER_START" ]; then
  python3 -c 'import json, os, sys; p = sys.argv[1]; s = json.load(open(p)); s["routes"] = json.loads(os.environ["ROUTES_AFTER_START"]); json.dump(s, open(p, "w"))' "$IP_STATE"
  sync_zt_rules
  cp "$IP_STATE" "$AFTER_SYNC"
fi
stop_service
'''


class RoutingTests(unittest.TestCase):
    def run_service(self, failed=False, rules=None, routes=None, routes_after_start=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            props = (ROOT / "module.prop").read_text()
            wrapper = "easytier" if "id=EasyTierForMagisk\n" in props else "zerotier"
            binary = "easytier-core" if wrapper == "easytier" else "zerotier-one"
            peer_priority = 1002 if wrapper == "easytier" else 1001
            original = [[1, None], [peer_priority, None]] + (rules or [])
            state = {"rules": original, "routes": ZT_ROUTES + OTHER_ROUTES if routes is None else routes}
            (root / "ip.json").write_text(json.dumps(state))
            (root / "config").mkdir()
            (root / "config/config.toml").write_text('instance_name = "fixture"\n')
            core = root / binary
            core.write_text("#!/bin/sh\nexit 0\n")
            core.chmod(0o755)
            source = (ROOT / wrapper).read_text().split('\ncase "$1" in\n', 1)[0]
            source = re.sub(r"(?m)^path=.*$", "path=" + shlex.quote(str(root)), source)
            (root / "functions.sh").write_text(source)
            fake_ip = root / "ip.py"
            fake_ip.write_text(FAKE_IP)
            env = dict(
                os.environ,
                FAKE_IP=str(fake_ip),
                IP_STATE=str(root / "ip.json"),
                AFTER_START=str(root / "started.json"),
                AFTER_SYNC=str(root / "synced.json"),
                ROUTES_AFTER_START=json.dumps(routes_after_start) if routes_after_start is not None else "",
                FAIL_START="1" if failed else "0",
            )
            result = subprocess.run(["sh", "-c", DRIVER, "sh", str(root)], env=env, capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            started = json.loads((root / "started.json").read_text())["rules"]
            stopped = json.loads((root / "ip.json").read_text())["rules"]
            synced = None
            if routes_after_start is not None:
                synced = json.loads((root / "synced.json").read_text())["rules"]
            return original, started, synced, stopped

    @staticmethod
    def service_rules(rules):
        return sorted(dst or "all" for pref, dst in rules if pref == 1002)

    def test_stopping_preserves_wireguard_and_other_module(self):
        original, started, _, stopped = self.run_service()
        self.assertTrue(all(rule in started for rule in original), "Start removed another module's rule")
        self.assertEqual(len(started), len(original) + len(ZT_ROUTES), "Service needs an independent rule per route")
        self.assertEqual(stopped, original, "Stop removed WireGuard or another module's rule")

    def test_failed_start_does_not_change_rules(self):
        original, started, _, stopped = self.run_service(failed=True)
        self.assertEqual(started, original)
        self.assertEqual(stopped, original)

    def test_rules_only_cover_zerotier_destinations(self):
        _, started, _, _ = self.run_service()
        self.assertEqual(self.service_rules(started), ["10.10.0.0/16", "10.122.100.0/24"],
                         "Main-table lookup must not capture other interfaces' routes such as VPN tun subnets")

    def test_default_route_via_zerotier_matches_all(self):
        _, started, _, _ = self.run_service(routes=["default via 10.122.100.1 dev ztu5coiqzg"] + OTHER_ROUTES)
        self.assertEqual(self.service_rules(started), ["all"])

    def test_sync_follows_route_changes(self):
        _, _, synced, _ = self.run_service(routes_after_start=ZT_ROUTES[:1] + OTHER_ROUTES)
        self.assertEqual(self.service_rules(synced), ["10.122.100.0/24"], "Stale route rule was kept")

    def test_legacy_catch_all_rule_is_replaced(self):
        original, started, _, stopped = self.run_service(rules=[[1002, None]])
        self.assertEqual(self.service_rules(started), ["10.10.0.0/16", "10.122.100.0/24"])
        self.assertEqual(stopped, original[:2], "Stop must clear every rule at the service priority")


if __name__ == "__main__":
    unittest.main()
