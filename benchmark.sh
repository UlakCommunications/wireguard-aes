#!/bin/bash
# AES-256-GCM vs ChaCha20-Poly1305 benchmark.
# Runs on the HOST. Each cipher gets 3 warm-up + 3 measured runs back to back.
#
# Usage:  bash benchmark.sh
# Prereq: vagrant up (both VMs running)
set -euo pipefail

DURATION=20
STREAMS=4
MSS=1360
RUNS=3        # measured runs per cipher

gw_script()  { vagrant ssh gateway -- -T "sudo bash /vagrant/vagrant/$*" 2>/dev/null; }
cli_script() { vagrant ssh client  -- -T "sudo bash /vagrant/vagrant/$*" 2>/dev/null; }

wait_ready() {
    for i in $(seq 1 30); do
        vagrant ssh client -- -T "sudo ping -I 10.10.10.10 10.20.10.10 -c 1 -W 2" &>/dev/null && \
        vagrant ssh client -- -T "sudo iperf3 -c 10.20.10.10 -B 10.10.10.10 -t 1 -P 1" &>/dev/null && \
        { echo "==> ready"; return 0; }
        echo "   $i/30 waiting..."; sleep 2
    done
    echo "ERROR: tunnel not ready"; exit 1
}

run_iperf_avg() {
    local label="$1"
    local total_tx=0
    local total_rx=0

    # 1 warm-up run (discarded)
    echo "   warm-up..."
    vagrant ssh client -- -T \
        "sudo iperf3 -c 10.20.10.10 -B 10.10.10.10 -t 10 -P $STREAMS -M $MSS" \
        &>/dev/null || true
    sleep 2

    for i in $(seq 1 $RUNS); do
        echo "   run $i/$RUNS..."
        result=$(vagrant ssh client -- -T \
            "sudo iperf3 -c 10.20.10.10 -B 10.10.10.10 -t $DURATION -P $STREAMS -M $MSS" \
            2>/dev/null)
        tx=$(echo "$result" | grep "\[SUM\].*sender"   | awk '{for(i=1;i<=NF;i++) if($i=="Mbits/sec") print $(i-1)}')
        rx=$(echo "$result" | grep "\[SUM\].*receiver" | awk '{for(i=1;i<=NF;i++) if($i=="Mbits/sec") print $(i-1)}')
        echo "      TX: ${tx} Mbits/sec   RX: ${rx} Mbits/sec"
        total_tx=$(awk "BEGIN {print $total_tx + $tx}")
        total_rx=$(awk "BEGIN {print $total_rx + $rx}")
        sleep 2
    done

    avg_tx=$(awk "BEGIN {printf \"%.1f\", $total_tx / $RUNS}")
    avg_rx=$(awk "BEGIN {printf \"%.1f\", $total_rx / $RUNS}")
    echo "   ── avg TX: ${avg_tx}  avg RX: ${avg_rx} Mbits/sec"
    # store for summary
    eval "AVG_TX_${label}=${avg_tx}"
    eval "AVG_RX_${label}=${avg_rx}"
}

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   WireGuard Cipher Benchmark  (${RUNS}×${DURATION}s, warmup included)  ║"
echo "║   iperf3  ${DURATION}s × ${STREAMS} streams  MSS ${MSS}  (VirtualBox+virtio)   ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# ── Round A: AES-256-GCM ─────────────────────────────────────────────────────
echo ""
echo "── Loading AES-256-GCM (wireguard-5.15-aes) ─────────────────"
gw_script "reload-module.sh custom gateway"
cli_script "reload-module.sh custom client"
wait_ready
run_iperf_avg "AES"

# ── Round B: ChaCha20-Poly1305 ───────────────────────────────────────────────
echo ""
echo "── Loading ChaCha20-Poly1305 (stock kernel) ──────────────────"
gw_script "reload-module.sh stock gateway"
cli_script "reload-module.sh stock client"
wait_ready
run_iperf_avg "ChaCha"

# ── Round C: AES again (consistency check) ───────────────────────────────────
echo ""
echo "── AES-256-GCM again (consistency check) ─────────────────────"
gw_script "reload-module.sh custom gateway"
cli_script "reload-module.sh custom client"
wait_ready
run_iperf_avg "AES2"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   RESULTS  (avg of ${RUNS} × ${DURATION}s runs, after warm-up)              ║"
echo "╠══════════════════════════════════════════════════════════════╣"
printf "║  %-22s  TX: %8s Mbits/s   RX: %8s Mbits/s  ║\n" \
    "AES-256-GCM (R1)"    "$AVG_TX_AES"   "$AVG_RX_AES"
printf "║  %-22s  TX: %8s Mbits/s   RX: %8s Mbits/s  ║\n" \
    "ChaCha20-Poly1305"   "$AVG_TX_ChaCha" "$AVG_RX_ChaCha"
printf "║  %-22s  TX: %8s Mbits/s   RX: %8s Mbits/s  ║\n" \
    "AES-256-GCM (R2)"    "$AVG_TX_AES2"  "$AVG_RX_AES2"

# Calculate speedup
speedup=$(awk "BEGIN {printf \"%.1f\", ($AVG_TX_AES + $AVG_TX_AES2)/2 / $AVG_TX_ChaCha * 100 - 100}")
echo "╠══════════════════════════════════════════════════════════════╣"
printf "║  AES vs ChaCha speedup: %+.1f%%  (positive = AES faster)      ║\n" "$speedup"
echo "╚══════════════════════════════════════════════════════════════╝"
