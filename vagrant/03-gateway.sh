#!/bin/bash
# Provision the GATEWAY VM.
set -euo pipefail

PEER_IP="${PEER_IP:-192.168.100.2}"
KEYS="/vagrant/vagrant/keys"

[ -f "$KEYS/private_gateway" ] || { echo "ERROR: keys not found. Run: bash vagrant/keygen.sh"; exit 1; }

# ── WireGuard interface ───────────────────────────────────────────────────────
ip link add wg0 type wireguard 2>/dev/null || true
ip addr add 10.0.0.1/24 dev wg0 2>/dev/null || true
ip link set wg0 up
wg set wg0 private-key "$KEYS/private_gateway" listen-port 51820
ip link set wg0 mtu 1420

wg set wg0 \
    peer "$(cat $KEYS/public_client)" \
    allowed-ips 10.10.10.0/24,10.0.0.2/32 \
    endpoint "${PEER_IP}:51820" \
    persistent-keepalive 5

ip route replace 10.10.10.0/24 dev wg0

# ── Dummy interface (target for iperf from client) ────────────────────────────
ip link add dum0 type dummy 2>/dev/null || true
ip addr add 10.20.10.10/24 dev dum0 2>/dev/null || true
ip link set dum0 up
ip route replace 10.20.10.0/24 dev dum0
wg set wg0 peer "$(cat $KEYS/public_client)" allowed-ips 10.10.10.0/24,10.20.10.0/24,10.0.0.2/32 2>/dev/null || true

# ── rp_filter ─────────────────────────────────────────────────────────────────
sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null
sysctl -w net.ipv4.conf.wg0.rp_filter=0 >/dev/null 2>/dev/null || true
sysctl -w net.ipv4.conf.dum0.rp_filter=0 >/dev/null 2>/dev/null || true

# ── Start iperf3 server (background, bound to dummy IP) ───────────────────────
pkill iperf3 2>/dev/null || true
iperf3 -s -B 10.20.10.10 -D --logfile /var/log/iperf3-server.log
echo "==> iperf3 server started on 10.20.10.10"

echo ""
echo "==> Gateway WireGuard status:"
wg show wg0
