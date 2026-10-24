#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
for script in customize.sh boot-completed.sh uninstall.sh zerotier tests/test_command_mount.sh scripts/ci/*.sh; do
  sh -n "$script"
  shellcheck "$script"
done
sh tests/test_command_mount.sh
python3 tests/test_core_build.py
python3 tests/test_release_update.py
