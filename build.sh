#!/bin/bash
# Build wireguard-5.15-aes kernel module against 5.15.0-173-generic headers.
set -euo pipefail

KERNEL="5.15.0-173-generic"
MODULE_DIR="$(cd "$(dirname "$0")/wireguard-5.15-aes" && pwd)"

if [ ! -d "/lib/modules/${KERNEL}/build" ]; then
    echo "ERROR: kernel headers for $KERNEL not found."
    echo "       Install: sudo apt-get install linux-headers-${KERNEL}"
    exit 1
fi

echo "==> Building wireguard.ko for kernel $KERNEL ..."
make -C "/lib/modules/${KERNEL}/build" M="$MODULE_DIR" modules

echo ""
echo "==> Build complete: $MODULE_DIR/wireguard.ko"
echo "    Size: $(du -h $MODULE_DIR/wireguard.ko | cut -f1)"
