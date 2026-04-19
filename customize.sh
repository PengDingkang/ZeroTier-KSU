#!/sbin/sh

### INSTALLATION ###

if [ "$BOOTMODE" != true ]; then
  ui_print "-----------------------------------------------------------"
  ui_print "! Please install in Magisk/KernelSU/APatch Manager"
  ui_print "! Install from recovery is NOT supported"
  abort "-----------------------------------------------------------"
fi

if [ "$KSU" = true ] && [ "$KSU_VER_CODE" -lt 10670 ]; then
  abort "ERROR: Please update your KernelSU and KernelSU Manager"
fi

if [ "$API" -lt 28 ]; then
  ui_print "! Unsupported sdk: $API"
  abort "! Minimal supported sdk is 28 (Android 9)"
else
  ui_print "- Device sdk: $API"
fi

# detect environment
if [ "$KSU" = true ]; then
  ui_print "- KernelSU version: $KSU_VER ($KSU_VER_CODE)"
elif [ "$APATCH" = true ]; then
  ui_print "- APatch detected"
else
  ui_print "- Magisk version: $MAGISK_VER ($MAGISK_VER_CODE)"
fi

ui_print "- Installing ZeroTier KSU"

# data directory for config and runtime
zt_data="/data/adb/zerotier"
if [ ! -d "$zt_data" ]; then
  mkdir -p "$zt_data/networks.d" "$zt_data/moons.d"
  set_perm "$zt_data" 0 0 0755
fi

# preserve existing identity and planet
if [ ! -f "$zt_data/identity.secret" ]; then
  ui_print "- Fresh install, identity will be generated on first run"
else
  ui_print "- Existing identity found, keeping it"
fi

# install default planet if not exists (user can replace with custom)
if [ ! -f "$zt_data/planet" ]; then
  ui_print "- Using default ZeroTier planet"
fi

# install default module settings if not exists
if [ ! -f "$zt_data/autostart.conf" ]; then
  echo "AUTO_START=1" > "$zt_data/autostart.conf"
  set_perm "$zt_data/autostart.conf" 0 0 0644
  ui_print "- Auto-start is enabled by default"
fi

# install binary to module system/bin overlay
ui_print "- Installing binaries"
mkdir -p "$MODPATH/system/bin"
mv -f "$MODPATH/zerotier-one" "$MODPATH/system/bin/"
# create symlinks for CLI subcommands
ln -sf zerotier-one "$MODPATH/system/bin/zerotier-cli"
ln -sf zerotier-one "$MODPATH/system/bin/zerotier-idtool"
mv -f "$MODPATH/zerotier" "$MODPATH/system/bin/"

# permissions
ui_print "- Setting permissions"
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/system/bin/zerotier-one" 0 0 0755
set_perm "$MODPATH/system/bin/zerotier" 0 0 0755

ui_print "- Installation complete, reboot your device"
ui_print "- Data dir: /data/adb/zerotier"
ui_print "- Join a network: zerotier join <network_id>"
ui_print "- Manage: zerotier {start|stop|restart|status}"
