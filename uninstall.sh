#!/system/bin/sh
# Cleanup on module uninstall
# Note: /data/adb/zerotier is kept intentionally to preserve user identity and config

# kill running process
killall zerotier-one 2>/dev/null
