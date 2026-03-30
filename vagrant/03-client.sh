#!/bin/bash
# Provision the CLIENT VM.
set -euo pipefail

PEER_IP="${PEER_IP:-192.168.100.1}"
KEYS="/vagrant/vagrant/keys"

[ -f "$KEYS/private_client" ] || { echo "ERROR: keys not found. Run: bash vagrant/keygen.sh"; exit 1; }

# ── WireGuard interface ───────────────────────────────────────────────────────
ip link add wg0 type wireguard 2>/dev/null || true
ip addr add 10.0.0.2/24 dev wg0 2>/dev/null || true
ip link set wg0 up
wg set wg0 private-key "$KEYS/private_client" listen-port 51820
ip link set wg0 mtu 1420

wg set wg0 \
    peer "$(cat $KEYS/public_gateway)" \
    allowed-ips 10.20.10.0/24,10.0.0.1/32 \
    endpoint "${PEER_IP}:51820" \
    persistent-keepalive 5

ip route replace 10.20.10.0/24 dev wg0

# ── Dummy interface (source for iperf to gateway) ─────────────────────────────
ip link add dum0 type dummy 2>/dev/null || true
ip addr add 10.10.10.10/24 dev dum0 2>/dev/null || true
ip link set dum0 up

# ── rp_filter ─────────────────────────────────────────────────────────────────
sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null
sysctl -w net.ipv4.conf.wg0.rp_filter=0 >/dev/null 2>/dev/null || true
sysctl -w net.ipv4.conf.dum0.rp_filter=0 >/dev/null 2>/dev/null || true

echo ""
echo "==> Client WireGuard status:"
wg show wg0
