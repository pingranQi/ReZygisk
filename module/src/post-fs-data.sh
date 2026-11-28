#!/system/bin/sh

set -e

MODDIR=${0%/*}
if [ "$ZYGISK_ENABLED" ]; then
  exit 0
fi

cd "$MODDIR"

# Magisk does not run other Zygisk modules' post-fs-data scripts automatically.
if [ "$(which magisk)" ]; then
  for file in ../*; do
    if [ -d "$file" ] && [ -d "$file/zygisk" ] && [ ! -f "$file/disable" ] && [ -f "$file/post-fs-data.sh" ]; then
      (
        cd "$file"
        log -p i -t "zygisk-sh" "Manually trigger post-fs-data.sh for $file"
        sh "$(realpath ./post-fs-data.sh)"
      ) || true
    fi
  done
fi

. "$MODDIR/zygisk-init.sh"
