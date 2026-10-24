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
  root_framework=kernelsu
  ui_print "- KernelSU version: $KSU_VER ($KSU_VER_CODE)"
elif [ "$APATCH" = true ]; then
  root_framework=apatch
  ui_print "- APatch detected"
else
  root_framework=magisk
  ui_print "- Magisk version: $MAGISK_VER ($MAGISK_VER_CODE)"
fi

ui_print "- Installing ZeroTier KSU"

# data directory for config and runtime
zt_data="/data/adb/zerotier"
if [ ! -d "$zt_data" ]; then
  mkdir -p "$zt_data/networks.d" "$zt_data/moons.d"
  set_perm "$zt_data" 0 0 0755
fi

printf '%s\n' "$root_framework" > "$zt_data/root_framework" || abort "! Cannot save root framework"

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

# Install the only permanent copies into the private data directory.
ui_print "- Installing private tools"
cp -f "$MODPATH/zerotier-one" "$zt_data/zerotier-one" || abort "! Cannot install zerotier-one"
cp -f "$MODPATH/zerotier" "$zt_data/zerotier" || abort "! Cannot install zerotier"
ln -sf zerotier-one "$zt_data/zerotier-cli" || abort "! Cannot install zerotier-cli"
ln -sf zerotier-one "$zt_data/zerotier-idtool" || abort "! Cannot install zerotier-idtool"
chmod 755 "$zt_data/zerotier-one" "$zt_data/zerotier"
rm -f "$MODPATH/zerotier-one" "$MODPATH/zerotier"

ui_print "- Setting permissions"
set_perm_recursive "$MODPATH" 0 0 0755 0644

# Mountless by default; preserve only an explicitly saved enabled choice.
mount_enabled=0
if [ -f "$zt_data/mount_enabled" ]; then
  [ "$(cat "$zt_data/mount_enabled")" = 1 ] && mount_enabled=1
  ui_print "- Preserving saved shell command mount choice"
else
  ui_print "- New installs and legacy upgrades default to NO shell command mount"
  ui_print "- After reboot, use full command paths; update scripts using short command names"
fi
printf '%s\n' "$mount_enabled" > "$zt_data/mount_enabled" || abort "! Cannot save mount setting"
sh "$zt_data/zerotier" prepare-command-mount "$MODPATH" "$mount_enabled" || abort "! Cannot prepare command mount"
if [ "$mount_enabled" = 0 ]; then
  ui_print "- Shell command mount: disabled"
else
  ui_print "- Shell command mount: enabled"
fi
if [ "$(sh "$zt_data/zerotier" mount supported)" != 1 ]; then
  ui_print "- Shell command mount unavailable: no enabled mounting metamodule"
fi

ui_print "- Installation complete, reboot your device"
ui_print "- Data dir: /data/adb/zerotier"
ui_print "- Join a network: /data/adb/zerotier/zerotier join <network_id>"
ui_print "- Manage: /data/adb/zerotier/zerotier {start|stop|restart|status}"
ui_print "- Change shell command mount in WebUI (requires reboot)"
