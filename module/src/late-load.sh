#!/system/bin/sh

set -e

# KernelSU runs this module entry only in LKM late-load mode, in place of
# post-fs-data.sh. Keep both paths on the same bootstrap implementation.
MODDIR=${0%/*}
cd "$MODDIR"

KSU_LATE_LOAD=1
export KSU_LATE_LOAD
. "$MODDIR/zygisk-init.sh"
