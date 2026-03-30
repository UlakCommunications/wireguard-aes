#!/bin/bash
# End-to-end test: ping + iperf3 throughput over WireGuard AES-256-GCM tunnel
# Runs on the CLIENT VM after provisioning.
set -euo pipefail

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  WireGuard AES-256-GCM — End-to-End Test"
echo "══════════════════════════════════════════════════════════════"

# Wait for gateway iperf3 server to be ready
echo ""
echo "── Waiting for gateway iperf3 server ───────────────────────"
for i in $(seq 1 15); do
    if iperf3 -c 10.20.10.10 -B 10.10.10.10 -t 1 -P 1 &>/dev/null; then
        echo "==> iperf3 server reachable"
        break
    fi
    echo "   attempt $i/15 — retrying in 2s..."
    sleep 2
done

echo ""
echo "── Ping test (10 packets, source 10.10.10.10 → 10.20.10.10) ─"
ping -I 10.10.10.10 10.20.10.10 -c 10 -W 5

echo ""
echo "── Cipher in use (dmesg) ─────────────────────────────────────"
if dmesg | grep -q "AES-GCM unavailable"; then
    echo "  Cipher: ChaCha20-Poly1305 (AES-NI not available in this VM)"
else
    echo "  Cipher: AES-256-GCM (AES-NI hardware acceleration)"
fi

echo ""
echo "── iperf3 throughput (30s, 4 parallel streams, MSS 1360) ─────"
iperf3 -c 10.20.10.10 -B 10.10.10.10 \
    -t 30 -P 4 -M 1360 \
    --logfile /var/log/iperf3-client.log
cat /var/log/iperf3-client.log | grep -E "SUM|sender|receiver|Gbits|Mbits" | tail -6

echo ""
echo "── WireGuard handshake + transfer counters ───────────────────"
wg show wg0

echo ""
echo "── dmesg (last 15 lines, WireGuard related) ──────────────────"
dmesg | grep -i "wireguard\|wg\|aes\|gcm" | tail -15 || true

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  TEST COMPLETE"
echo "══════════════════════════════════════════════════════════════"
