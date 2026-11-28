# shellcheck disable=SC2034
SKIPUNZIP=1

DEBUG=@DEBUG@
MIN_KSU_VERSION=@MIN_KSU_VERSION@
MIN_KSUD_VERSION=@MIN_KSUD_VERSION@
MIN_APATCH_VERSION=@MIN_APATCH_VERSION@

if [ "$BOOTMODE" ] && [ "$KSU" ]; then
  ui_print "- Installing from KernelSU app"
  ui_print "- KernelSU version: $KSU_KERNEL_VER_CODE (kernel) + $KSU_VER_CODE (ksud)"
  if ! [ "$KSU_KERNEL_VER_CODE" ] || [ "$KSU_KERNEL_VER_CODE" -lt "$MIN_KSU_VERSION" ]; then
    ui_print "*********************************************************"
    ui_print "! KernelSU version is too old!"
    ui_print "! Please update KernelSU to latest version"
    abort    "*********************************************************"
  fi
  if ! [ "$KSU_VER_CODE" ] || [ "$KSU_VER_CODE" -lt "$MIN_KSUD_VERSION" ]; then
    ui_print "*********************************************************"
    ui_print "! ksud version is too old!"
    ui_print "! Please update KernelSU Manager to latest version"
    abort    "*********************************************************"
  fi
elif [ "$BOOTMODE" ] && [ "$APATCH" ]; then
  ui_print "- Installing from APatch app"
  if ! [ "$APATCH_VER_CODE" ] || [ "$APATCH_VER_CODE" -lt "$MIN_APATCH_VERSION" ]; then
    ui_print "*********************************************************"
    ui_print "! APatch version is too old!"
    ui_print "! Please update APatch to latest version"
    abort    "*********************************************************"
  fi
else
  ui_print "*********************************************************"
  ui_print "! Install from KernelSU or APatch app"
  abort    "*********************************************************"
fi
VERSION=$(grep_prop version "${TMPDIR}/module.prop")
ui_print "- Installing VRMZygisk $VERSION"

# check android
if [ "$API" -lt 25 ]; then
  ui_print "! Unsupported sdk: $API"
  abort "! Minimal supported sdk is 25 (Android 7.1)"
else
  ui_print "- Device sdk: $API"
fi

# check architecture
if [ "$ARCH" != "arm64" ]; then
  abort "! Only arm64 devices are supported (arm64-v8a)"
else
  ui_print "- Device platform: arm64"
fi

ui_print "- Extracting verify.sh"
unzip -o "$ZIPFILE" 'verify.sh' -d "$TMPDIR" >&2
if [ ! -f "$TMPDIR/verify.sh" ]; then
  ui_print "*********************************************************"
  ui_print "! Unable to extract verify.sh!"
  ui_print "! This zip may be corrupted, please try downloading again"
  abort    "*********************************************************"
fi
. "$TMPDIR/verify.sh"
extract "$ZIPFILE" 'customize.sh'  "$TMPDIR/.vunzip"
extract "$ZIPFILE" 'verify.sh'     "$TMPDIR/.vunzip"
extract "$ZIPFILE" 'sepolicy.rule' "$TMPDIR"

if [ "$KSU" ]; then
  ui_print "- Checking SELinux patches"
  if ! check_sepolicy "$TMPDIR/sepolicy.rule"; then
    ui_print "*********************************************************"
    ui_print "! Unable to apply SELinux patches!"
    ui_print "! Your kernel may not support SELinux patch fully"
    abort    "*********************************************************"
  fi
fi

ui_print "- Extracting module files"
extract "$ZIPFILE" 'module.prop'     "$MODPATH"
extract "$ZIPFILE" 'post-fs-data.sh' "$MODPATH"
extract "$ZIPFILE" 'late-load.sh'    "$MODPATH"
extract "$ZIPFILE" 'zygisk-init.sh'  "$MODPATH"
extract "$ZIPFILE" 'module-card.sh'  "$MODPATH"
extract "$ZIPFILE" 'uninstall.sh'    "$MODPATH"

# Remove service hooks installed by older module versions.
rm -f "$MODPATH/service.sh" "$MODPATH/rezygisk.sh" /data/adb/service.d/rezygisk.sh
rmdir /data/adb/service.d 2>/dev/null || true

# KernelSU executes a module's late-load.sh instead of post-fs-data.sh when
# its LKM is injected after Android has already booted.

if [ "$KSU" ]; then
  ui_print "- KernelSU late-load entry enabled"
fi

cp "$MODPATH/module.prop" "$MODPATH/module.prop.bak"

chmod 0755 "$MODPATH/uninstall.sh" "$MODPATH/post-fs-data.sh" "$MODPATH/late-load.sh" "$MODPATH/zygisk-init.sh" "$MODPATH/module-card.sh"

mv "$TMPDIR/sepolicy.rule" "$MODPATH"

rm -rf "$MODPATH/bin" "$MODPATH/lib" "$MODPATH/lib64" "$MODPATH/webroot"
mkdir "$MODPATH/bin"
mkdir "$MODPATH/lib64"

ui_print "- Extracting arm64-v8a libraries"
extract "$ZIPFILE" 'bin/arm64-v8a/zygiskd' "$MODPATH/bin" true
mv "$MODPATH/bin/zygiskd" "$MODPATH/bin/zygiskd64"
extract "$ZIPFILE" 'lib/arm64-v8a/libzygisk.so' "$MODPATH/lib64" true
extract "$ZIPFILE" 'lib/arm64-v8a/libzygisk_ptrace.so' "$MODPATH/bin" true
mv "$MODPATH/bin/libzygisk_ptrace.so" "$MODPATH/bin/zygisk-ptrace64"

ui_print "- Setting permissions"
set_perm_recursive "$MODPATH/bin" 0 0 0755 0755
set_perm_recursive "$MODPATH/lib64" 0 0 0755 0644 u:object_r:system_lib_file:s0

# If Huawei's Maple is enabled, system_server is created with a special way which is out of Zygisk's control
HUAWEI_MAPLE_ENABLED=$(grep_prop ro.maple.enable)
if [ "$HUAWEI_MAPLE_ENABLED" == "1" ]; then
  ui_print "- Add ro.maple.enable=0"
  echo "ro.maple.enable=0" >>"$MODPATH/system.prop"
fi
