#!/system/bin/sh

set -e

MODDIR=${0%/*}
cd "$MODDIR"

. "$MODDIR/zygisk-init.sh"
