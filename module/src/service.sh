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

. "$MODDIR/module-card.sh"
update_module_card

exit 0
