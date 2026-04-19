#!/system/bin/sh
# Cleanup on module uninstall
# Note: /data/adb/zerotier is kept to preserve user identity and config

# kill running process
killall zerotier-one 2>/dev/null

# remove fallback binaries (keep config/identity)
rm -f /data/adb/zerotier/zerotier-one
rm -f /data/adb/zerotier/zerotier
