#!/system/bin/sh

set -e

MODDIR=${MODDIR:-${0%/*}}
TMP_PATH=/data/adb/rezygisk
export TMP_PATH

if [ "$ZYGISK_ENABLED" ]; then
  return 0
fi

cd "$MODDIR"

ABI=$(getprop ro.product.cpu.abi)
if [ "$ABI" != "arm64-v8a" ]; then
  log -p e -t "ReZygisk" "Unsupported ABI: $ABI (arm64-v8a required)"
  return 0
fi

# A soft reboot replays boot stages while the monitor and daemon may survive.
# Do not unlink their live sockets or start a second ptrace owner.
have_monitor=0
init_tracer=$(awk '/^TracerPid:/{print $2; exit}' /proc/1/status 2>/dev/null || true)
if [ -n "$init_tracer" ] && [ "$init_tracer" != "0" ]; then
  have_monitor=1
fi
if pidof zygisk-ptrace64 >/dev/null 2>&1; then
  have_monitor=1
fi

if [ "$have_monitor" = "0" ]; then
  rm -rf "$TMP_PATH"
fi

mkdir -p "$TMP_PATH"
chmod 555 "$TMP_PATH"
chcon u:object_r:system_file:s0 "$TMP_PATH" 2>/dev/null || true

# Record the mode for the module card. KernelSU exports KSU_LATE_LOAD only
# during its late-load stage; a normal cold boot clears a stale marker.
BOOT_ID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)
LATE_LOAD_MARKER="$TMP_PATH/late-load.boot-id"
if [ "$KSU_LATE_LOAD" = "1" ]; then
  [ -n "$BOOT_ID" ] && printf '%s\n' "$BOOT_ID" > "$LATE_LOAD_MARKER"
elif [ -f "$LATE_LOAD_MARKER" ]; then
  marker_boot_id=$(cat "$LATE_LOAD_MARKER" 2>/dev/null)
  if [ -z "$BOOT_ID" ] || [ "$marker_boot_id" != "$BOOT_ID" ]; then
    rm -f "$LATE_LOAD_MARKER"
  fi
fi

if [ "$have_monitor" = "0" ]; then
  cp "$MODDIR/module.prop.bak" "$MODDIR/module.prop"
fi

# Capture the module list and mode before monitor startup: monitor.c snapshots
# module.prop once and preserves this description while updating injection state.
. "$MODDIR/module-card.sh"
update_module_card

if [ "$have_monitor" = "1" ]; then
  log -p i -t "ReZygisk" "Monitor already owns init; preserving the active session"
  return 0
fi

"$MODDIR/bin/zygisk-ptrace64" monitor &
