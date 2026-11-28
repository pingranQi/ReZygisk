#!/system/bin/sh

set -e

MODDIR=${0%/*}

if [ "$ZYGISK_ENABLED" ]; then
  sed -i "s|^description=|description=[❌ Disable Magisk's built-in Zygisk] |" "$MODDIR/module.prop"
  exit 0
fi

# Magisk does not run another module's service stage automatically.
if [ "$(which magisk)" ]; then
  for module_dir in /data/adb/modules/*; do
    [ -d "$module_dir/zygisk" ] || continue
    [ -f "$module_dir/disable" ] && continue
    [ -f "$module_dir/service.sh" ] || continue
    (cd "$module_dir" && sh "$(realpath ./service.sh)") &
  done
fi

# Show enabled Zygisk modules on the root manager's module card.
modules=""
for module_dir in /data/adb/modules/*; do
  [ -d "$module_dir/zygisk" ] || continue
  [ -f "$module_dir/disable" ] && continue

  name=$(sed -n 's/^name=//p' "$module_dir/module.prop" 2>/dev/null | head -n 1)
  [ -n "$name" ] || name=${module_dir##*/}

  if [ -n "$modules" ]; then
    modules="$modules, $name"
  else
    modules="$name"
  fi
done

[ -n "$modules" ] || modules="none"
if pidof zygisk-ptrace64 >/dev/null 2>&1; then
  monitor_status="✅"
else
  monitor_status="❌"
fi
if pidof zygiskd64 >/dev/null 2>&1; then
  daemon_status="✅"
else
  daemon_status="❌"
fi

base_prop="$MODDIR/module.prop.bak"
[ -f "$base_prop" ] || base_prop="$MODDIR/module.prop"
base_description=$(sed -n 's/^description=//p' "$base_prop" | head -n 1)
description="[Monitor: $monitor_status, ReZygisk 64-bit: $daemon_status] Modules: $modules · $base_description"

awk -v description="$description" '
  /^description=/ { print "description=" description; next }
  { print }
' "$base_prop" > "$MODDIR/module.prop.tmp"
mv "$MODDIR/module.prop.tmp" "$MODDIR/module.prop"

exit 0
