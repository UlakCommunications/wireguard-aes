#!/bin/bash
# Run inside a VM to reload wireguard module and restore network config.
# Usage: reload-module.sh <custom|stock> <gateway|client>
set -euo pipefail

MODE="${1:-custom}"
ROLE="${2:-client}"

CUSTOM_KO="/vagrant/wireguard-5.15-aes/wireguard.ko"
STOCK_KO="/lib/modules/$(uname -r)/kernel/net/wireguard/wireguard.ko"
KEYS="/vagrant/vagrant/keys"

if [ "$MODE" = "custom" ]; then
    KO="$CUSTOM_KO"
    LABEL="AES-256-GCM"
else
    KO="$STOCK_KO"
    LABEL="ChaCha20-Poly1305 (stock)"
fi

echo "==> [$ROLE] Loading: $LABEL"

ip link del wg0 2>/dev/null || true
rmmod wireguard 2>/dev/null || true

for m in gcm aes_generic aesni_intel libchacha20poly1305 chacha20poly1305; do
    modprobe $m 2>/dev/null || true
done

if [ "$MODE" = "stock" ]; then
    modprobe wireguard || { echo "ERROR: modprobe wireguard failed"; dmesg | tail -10; exit 1; }
else
    insmod "$KO" || { echo "ERROR: insmod failed"; dmesg | tail -10; exit 1; }
fi

# Restore rp_filter (must be done before bringing up interfaces)
sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null

if [ "$ROLE" = "gateway" ]; then
    # WireGuard
    ip link add wg0 type wireguard
    ip addr add 10.0.0.1/24 dev wg0
    ip link set wg0 up mtu 1420
    wg set wg0 private-key "$KEYS/private_gateway" listen-port 51820
    wg set wg0 peer "$(cat $KEYS/public_client)" \
        allowed-ips 10.10.10.0/24,10.20.10.0/24,10.0.0.2/32 \
        endpoint 192.168.100.2:51820 persistent-keepalive 5
    sysctl -w net.ipv4.conf.wg0.rp_filter=0 >/dev/null 2>/dev/null || true

    # Dummy (iperf3 server target)
    ip link add dum0 type dummy 2>/dev/null || true
    ip addr add 10.20.10.10/24 dev dum0 2>/dev/null || true
    ip link set dum0 up
    sysctl -w net.ipv4.conf.dum0.rp_filter=0 >/dev/null 2>/dev/null || true

    ip route replace 10.10.10.0/24 dev wg0

    # Restart iperf3 server
    pkill iperf3 2>/dev/null || true
    sleep 1
    iperf3 -s -B 10.20.10.10 -D --logfile /var/log/iperf3-server.log
    echo "==> iperf3 server restarted on 10.20.10.10"

else  # client
    # WireGuard
    ip link add wg0 type wireguard
    ip addr add 10.0.0.2/24 dev wg0
    ip link set wg0 up mtu 1420
    wg set wg0 private-key "$KEYS/private_client" listen-port 51820
    wg set wg0 peer "$(cat $KEYS/public_gateway)" \
        allowed-ips 10.20.10.0/24,10.0.0.1/32 \
        endpoint 192.168.100.1:51820 persistent-keepalive 5
    sysctl -w net.ipv4.conf.wg0.rp_filter=0 >/dev/null 2>/dev/null || true

    # Dummy (iperf3 client source)
    ip link add dum0 type dummy 2>/dev/null || true
    ip addr add 10.10.10.10/24 dev dum0 2>/dev/null || true
    ip link set dum0 up
    sysctl -w net.ipv4.conf.dum0.rp_filter=0 >/dev/null 2>/dev/null || true

    ip route replace 10.20.10.0/24 dev wg0
fi

echo "==> [$ROLE] $LABEL ready"
