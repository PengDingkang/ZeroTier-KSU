#!/system/bin/sh
# ZeroTier boot-completed script (module script, NOT general script)
# Runs after boot is fully completed

(
  until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 5
  done
  sleep 5

  auto_start=1
  if [ -f /data/adb/zerotier/autostart.conf ]; then
    # shellcheck disable=SC1091
    . /data/adb/zerotier/autostart.conf
    auto_start=${AUTO_START:-1}
  fi
  [ "$auto_start" = "1" ] || exit 0

  zerotier start

  # update KSU description
  if command -v ksud >/dev/null 2>&1; then
    export KSU_MODULE="ZeroTier-KSU"
    sleep 3
    if pidof zerotier-one >/dev/null 2>&1; then
      # read auth token and get assigned IPs
      token_file="/data/adb/zerotier/authtoken.secret"
      if [ -f "$token_file" ]; then
        token=$(cat "$token_file")
        nets=$(curl -sf -H "X-ZT1-Auth: ${token}" http://127.0.0.1:9993/network 2>/dev/null)
        # extract first assigned IP
        ip=$(echo "$nets" | grep -o '"assignedAddresses":\["[^"]*"' | head -1 | sed 's/.*\["\([^/]*\).*/\1/')
        if [ -n "$ip" ]; then
          ksud module config set override.description "✅ Running | IP: ${ip}" 2>/dev/null
        else
          ksud module config set override.description "✅ Running" 2>/dev/null
        fi
      else
        ksud module config set override.description "✅ Running" 2>/dev/null
      fi
    fi
  fi
)&
