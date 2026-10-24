"""Check cache invalidation and source pin verification without network access."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/ci/build-core.sh"


class BuildTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "CORE_VERSION").write_text("1.16.0\n")
        (self.root / "CORE_COMMIT").write_text("7b7d39becc4a775d33e8c0f673856fb91dea7f31\n")
        self.env = os.environ | {"ZT_CORE_WORKSPACE": str(self.root)}

    def command(self, *args, env=None):
        return subprocess.run(["sh", str(SCRIPT), *args], env=env or self.env, capture_output=True, text=True, timeout=20)

    def key(self, env=None):
        result = self.command("--cache-key", env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def test_source_and_flags_change_the_cache_key(self):
        original = self.key()
        changed_flags = self.env.get("CXXFLAGS", "") + " -DZT_CACHE_TEST=1"
        self.assertNotEqual(original, self.key(self.env | {"CXXFLAGS": changed_flags}))
        (self.root / "CORE_COMMIT").write_text("1" * 40 + "\n")
        self.assertNotEqual(original, self.key())

    def test_wrong_source_commit_is_rejected(self):
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        git = bin_dir / "git"
        git.write_text(
            '#!/bin/sh\nif [ "$1" = init ]; then\n'
            'for arg in "$@"; do target="$arg"; done\nmkdir -p "$target"\n'
            'elif [ "$3" = rev-parse ]; then printf "%040d\\n" 0; fi\n'
        )
        git.chmod(0o755)
        result = self.command(env=self.env | {"PATH": str(bin_dir) + os.pathsep + os.environ["PATH"]})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("source commit mismatch", result.stderr)
        self.assertFalse((self.root / "zerotier-one").exists())

    def test_invalid_pin_is_rejected(self):
        (self.root / "CORE_COMMIT").write_text("main\n")
        result = self.command("--cache-key")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Invalid CORE_COMMIT", result.stderr)

    def test_corrupt_cached_core_is_not_reused(self):
        cache = self.root / ".cache/core" / self.key()
        cache.mkdir(parents=True)
        (cache / "zerotier-one").write_bytes(b"corrupt cached core")
        (cache / "zerotier-one.sha256").write_text("0" * 64 + "  zerotier-one\n")
        output = self.root / "zerotier-one"
        output.write_bytes(b"existing local core")
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        git = bin_dir / "git"
        marker = self.root / "fetch-attempted"
        git.write_text('#!/bin/sh\ntouch "$TEST_MARKER"\nexit 43\n')
        git.chmod(0o755)
        result = self.command(env=self.env | {
            "PATH": str(bin_dir) + os.pathsep + os.environ["PATH"],
            "TEST_MARKER": str(marker),
        })
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(marker.exists(), "bad cache must trigger a source rebuild")
        self.assertEqual(output.read_bytes(), b"existing local core")


if __name__ == "__main__":
    unittest.main()
