#!/bin/bash
# Build the wgaes-base Vagrant box and register it locally.
#
# Run this ONCE on the host before "vagrant up" in the project root.
# Pre-requisite:
#   cd wireguard-5.15-aes && make -C /lib/modules/5.15.0-173-generic/build M=$(pwd) modules
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build-base"
BOX_OUT="$SCRIPT_DIR/wgaes-base.box"
BOX_NAME="wgaes-base"

echo "==> Building wgaes-base box..."
cd "$BUILD_DIR"
vagrant destroy -f 2>/dev/null || true
vagrant up --provider=virtualbox

echo "==> Packaging box to $BOX_OUT ..."
vagrant package --output "$BOX_OUT"
vagrant destroy -f

echo "==> Registering box as '$BOX_NAME' ..."
vagrant box remove "$BOX_NAME" --force 2>/dev/null || true
vagrant box add "$BOX_NAME" "$BOX_OUT"

echo ""
echo "Done! You can now run 'vagrant up' from the project root."
