#!/system/bin/sh

update_module_card() {
  MODDIR=${MODDIR:-/data/adb/modules/rezygisk}
  base_prop="$MODDIR/module.prop.bak"
  [ -f "$base_prop" ] || base_prop="$MODDIR/module.prop"

  boot_id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)
  marker_boot_id=$(cat /data/adb/rezygisk/late-load.boot-id 2>/dev/null)
  if [ -n "$boot_id" ] && [ "$marker_boot_id" = "$boot_id" ]; then
    mode="Late-load"
  else
    mode="Standard"
  fi

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

  base_description=$(sed -n 's/^description=//p' "$base_prop" | head -n 1)
  description="[Mode: $mode] Modules: $modules · $base_description"

  awk -v description="$description" '
    /^description=/ { print "description=" description; next }
    { print }
  ' "$base_prop" > "$MODDIR/module.prop.tmp"
  mv "$MODDIR/module.prop.tmp" "$MODDIR/module.prop"
}
