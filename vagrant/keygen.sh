#!/bin/bash
# Pre-generate WireGuard keys before vagrant up.
# Runs on the HOST via Vagrant trigger.
set -euo pipefail

KEYS_DIR="$(dirname "$0")/keys"
mkdir -p "$KEYS_DIR"

# Only regenerate if keys don't exist yet
if [ -f "$KEYS_DIR/private_gateway" ] && [ -f "$KEYS_DIR/private_client" ]; then
    echo "==> Keys already exist, skipping keygen."
    exit 0
fi

echo "==> Generating WireGuard keys..."
umask 077
wg genkey > "$KEYS_DIR/private_gateway"
wg pubkey < "$KEYS_DIR/private_gateway" > "$KEYS_DIR/public_gateway"
wg genkey > "$KEYS_DIR/private_client"
wg pubkey < "$KEYS_DIR/private_client" > "$KEYS_DIR/public_client"

echo "    gateway pubkey: $(cat $KEYS_DIR/public_gateway)"
echo "    client  pubkey: $(cat $KEYS_DIR/public_client)"
echo "==> Keys ready in $KEYS_DIR"
