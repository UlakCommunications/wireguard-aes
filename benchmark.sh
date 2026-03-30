#!/bin/bash
# AES-256-GCM vs ChaCha20-Poly1305 benchmark.
# Runs on the HOST — coordinates gateway + client via vagrant ssh.
#
# Usage:  bash benchmark.sh
# Prereq: vagrant up (both VMs running)
set -euo pipefail

DURATION=30
STREAMS=4
MSS=1360

# Run a shell script (via sudo bash) on gateway/client
gw_script()  { vagrant ssh gateway -- -T "sudo bash /vagrant/vagrant/$*" 2>/dev/null; }
cli_script() { vagrant ssh client  -- -T "sudo bash /vagrant/vagrant/$*" 2>/dev/null; }

# Run a raw command on client
cli_cmd() { vagrant ssh client -- -T "sudo $*" 2>/dev/null; }

run_round() {
    local mode="$1"   # custom | stock
    local label="$2"
    local logfile="/tmp/iperf-${mode}.log"

    echo ""
    echo "────────────────────────────────────────────────────────────────"
    echo "  $label"
    echo "────────────────────────────────────────────────────────────────"

    # Reload module on both sides
    gw_script "reload-module.sh $mode gateway"
    cli_script "reload-module.sh $mode client"

    # Wait for WireGuard handshake + iperf3 server
    echo "── Waiting for tunnel + iperf3 server ───────────────────────"
    for i in $(seq 1 20); do
        if vagrant ssh client -- -T "sudo ping -I 10.10.10.10 10.20.10.10 -c 1 -W 2" &>/dev/null; then
            echo "==> Tunnel up"; break
        fi
        echo "   $i/20 — waiting..."; sleep 2
    done
    for i in $(seq 1 15); do
        if vagrant ssh client -- -T \
            "sudo iperf3 -c 10.20.10.10 -B 10.10.10.10 -t 1 -P 1" &>/dev/null; then
            echo "==> iperf3 server ready"; break
        fi
        echo "   $i/15 — iperf3 not ready..."; sleep 2
    done

    # Ping check
    echo "── Ping (5 packets) ──────────────────────────────────────────"
    cli_cmd "ping -I 10.10.10.10 10.20.10.10 -c 5 -W 5"

    # iperf3
    echo ""
    echo "── iperf3 ${DURATION}s × ${STREAMS} streams ─────────────────────────────────"
    vagrant ssh client -- -T \
        "sudo iperf3 -c 10.20.10.10 -B 10.10.10.10 -t $DURATION -P $STREAMS -M $MSS" \
        2>/dev/null | tee "$logfile" | \
        grep -E "^\[SUM\].*sender|^\[SUM\].*receiver" || true
}

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   WireGuard Cipher Benchmark                                ║"
echo "║   iperf3  ${DURATION}s × ${STREAMS} streams  MSS ${MSS}  (VirtualBox)          ║"
echo "╚══════════════════════════════════════════════════════════════╝"

run_round "custom" "Round 1: AES-256-GCM  (wireguard-5.15-aes, AES-NI)"
run_round "stock"  "Round 2: ChaCha20-Poly1305  (stock kernel wireguard)"
run_round "custom" "Round 3: AES-256-GCM  (re-run for consistency)"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   SUMMARY                                                   ║"
echo "╠══════════════════════════════════════════════════════════════╣"
for pair in "custom:AES-256-GCM   " "stock:ChaCha20-Poly1305"; do
    mode="${pair%%:*}"
    label="${pair##*:}"
    f="/tmp/iperf-${mode}.log"
    sender=$(grep "\[SUM\].*sender"   "$f" 2>/dev/null | awk '{print $(NF-2), $(NF-1)}' || echo "N/A")
    recvr=$(grep "\[SUM\].*receiver"  "$f" 2>/dev/null | awk '{print $(NF-2), $(NF-1)}' || echo "N/A")
    printf "║  %-20s  TX: %-14s  RX: %-12s ║\n" "$label" "$sender" "$recvr"
done
echo "╚══════════════════════════════════════════════════════════════╝"
