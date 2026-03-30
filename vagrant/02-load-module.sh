#!/bin/bash
# Copy wireguard.ko from host (via /vagrant) and load it.
# Runs on every "vagrant up" so code changes on host take effect immediately.
set -euo pipefail

KERNEL="5.15.0-173-generic"
KO_SRC="/vagrant/wireguard-5.15-aes/wireguard.ko"
KO_DST="/lib/modules/${KERNEL}/extra/wireguard.ko"

echo "==> Kernel: $(uname -r)"
if [ "$(uname -r)" != "$KERNEL" ]; then
    echo "ERROR: expected kernel $KERNEL but running $(uname -r)"
    echo "       Re-build the base box: cd vagrant && bash build-base.sh"
    exit 1
fi

if [ ! -f "$KO_SRC" ]; then
    echo "ERROR: $KO_SRC not found."
    echo "       Build on host: cd wireguard-5.15-aes && make -C /lib/modules/${KERNEL}/build M=\$(pwd) modules"
    exit 1
fi

# Remove previously loaded wireguard (stock or old custom)
rmmod wireguard 2>/dev/null || true

# Load required dependencies
for mod in libchacha20poly1305 libcurve25519 udp_tunnel ip6_udp_tunnel \
           curve25519-x86_64 libcurve25519-generic chacha20poly1305 \
           gcm aes_generic aesni_intel; do
    modprobe "$mod" 2>/dev/null || true
done

# Install and load the fresh .ko from host
install -D -m 644 "$KO_SRC" "$KO_DST"
insmod "$KO_DST" && echo "==> insmod OK" || {
    echo "ERROR: insmod failed"
    dmesg | tail -20
    exit 1
}
sleep 1

echo "==> lsmod:"
lsmod | grep wireguard || echo "(wireguard not in lsmod)"

# Check which cipher is active
if dmesg | grep -q "AES-GCM unavailable"; then
    echo "==> Cipher: ChaCha20-Poly1305 (AES-NI not available)"
else
    echo "==> Cipher: AES-256-GCM (AES-NI hardware acceleration)"
fi
