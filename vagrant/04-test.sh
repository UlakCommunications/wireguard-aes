#!/bin/bash
# Initial connectivity test — runs on CLIENT VM at provisioning time.
set -euo pipefail

echo ""
echo "── Waiting for gateway iperf3 server ───────────────────────────"
for i in $(seq 1 20); do
    if iperf3 -c 10.20.10.10 -B 10.10.10.10 -t 1 -P 1 &>/dev/null; then
        echo "==> iperf3 server reachable"; break
    fi
    echo "   attempt $i/20 — retrying in 2s..."; sleep 2
done

echo ""
echo "── Ping (3 packets) ─────────────────────────────────────────────"
ping -I 10.10.10.10 10.20.10.10 -c 3 -W 5

echo ""
echo "── Cipher (dmesg) ───────────────────────────────────────────────"
dmesg | grep -i "wireguard\|aes\|gcm" | tail -5 || true

echo ""
echo "==> Initial AES test OK. Run benchmark: bash benchmark.sh"
