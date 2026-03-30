#!/bin/bash
# In-VM netns benchmark: AES-256-GCM vs ChaCha20-Poly1305
# No VirtualBox NIC overhead — veth pair directly in kernel.
# Runs inside the VM (gateway or client, doesn't matter).
#
# Usage: sudo bash /vagrant/vagrant/netns-bench.sh
set -euo pipefail

DURATION=20
STREAMS=4
MSS=1360
RUNS=3

CUSTOM_KO="/vagrant/wireguard-5.15-aes/wireguard.ko"
STOCK_KO="/lib/modules/$(uname -r)/kernel/net/wireguard/wireguard.ko"

cleanup() {
    ip netns del left  2>/dev/null || true
    ip netns del right 2>/dev/null || true
    ip link del veth-l 2>/dev/null || true
    rmmod wireguard    2>/dev/null || true
    pkill iperf3       2>/dev/null || true
}
trap cleanup EXIT

load_module() {
    local ko="$1"
    rmmod wireguard 2>/dev/null || true
    if [ "$ko" = "stock" ]; then
        modprobe wireguard
    else
        # WireGuard deps + AES deps
        for m in libcurve25519_generic curve25519_x86_64 \
                 libchacha chacha_x86_64 poly1305_x86_64 libchacha20poly1305 \
                 udp_tunnel ip6_udp_tunnel \
                 gcm aes_generic aesni_intel; do
            modprobe $m 2>/dev/null || true
        done
        insmod "$ko"
    fi
}

setup_tunnel() {
    # Network namespaces + veth
    ip netns add left
    ip netns add right
    ip link add veth-l type veth peer name veth-r
    ip link set veth-l netns left
    ip link set veth-r netns right
    ip netns exec left  ip addr add 192.168.99.1/30 dev veth-l
    ip netns exec right ip addr add 192.168.99.2/30 dev veth-r
    ip netns exec left  ip link set veth-l up
    ip netns exec right ip link set veth-r up

    # WireGuard keys
    PRIV_L=$(wg genkey); PUB_L=$(echo "$PRIV_L" | wg pubkey)
    PRIV_R=$(wg genkey); PUB_R=$(echo "$PRIV_R" | wg pubkey)

    # WireGuard interfaces
    ip netns exec left  ip link add wg0 type wireguard
    ip netns exec right ip link add wg0 type wireguard

    ip netns exec left  ip addr add 10.1.0.1/24 dev wg0
    ip netns exec right ip addr add 10.1.0.2/24 dev wg0

    echo "$PRIV_L" | ip netns exec left  wg set wg0 private-key /dev/stdin listen-port 51820
    echo "$PRIV_R" | ip netns exec right wg set wg0 private-key /dev/stdin listen-port 51820

    ip netns exec left  wg set wg0 peer "$PUB_R" allowed-ips 10.1.0.0/24,10.20.20.0/24 endpoint 192.168.99.2:51820
    ip netns exec right wg set wg0 peer "$PUB_L" allowed-ips 10.1.0.0/24,10.10.10.0/24 endpoint 192.168.99.1:51820

    ip netns exec left  ip link set wg0 up mtu 1420
    ip netns exec right ip link set wg0 up mtu 1420

    # Dummy source IPs for iperf
    ip netns exec left  ip link add dum0 type dummy
    ip netns exec right ip link add dum0 type dummy
    ip netns exec left  ip addr add 10.10.10.1/24 dev dum0
    ip netns exec right ip addr add 10.20.20.1/24 dev dum0
    ip netns exec left  ip link set dum0 up
    ip netns exec right ip link set dum0 up
    ip netns exec left  ip route add 10.20.20.0/24 dev wg0
    ip netns exec right ip route add 10.10.10.0/24 dev wg0
    ip netns exec left  sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null
    ip netns exec right sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null

    # Warmup ping
    sleep 1
    ip netns exec left ping 10.20.20.1 -I 10.10.10.1 -c 5 -W 3 >/dev/null || true
}

run_iperf_avg() {
    local label="$1"
    local total_tx=0 total_rx=0

    # Start iperf3 server in right netns
    pkill iperf3 2>/dev/null || true; sleep 0.5
    ip netns exec right iperf3 -s -B 10.20.20.1 -D --logfile /tmp/iperf3-srv.log

    # Warmup
    ip netns exec left iperf3 -c 10.20.20.1 -B 10.10.10.1 \
        -t 10 -P $STREAMS -M $MSS -f m &>/dev/null || true
    sleep 1

    for i in $(seq 1 $RUNS); do
        result=$(ip netns exec left iperf3 -c 10.20.20.1 -B 10.10.10.1 \
            -t $DURATION -P $STREAMS -M $MSS -f m 2>/dev/null)
        tx=$(echo "$result" | grep "\[SUM\].*sender"   | awk '{for(i=1;i<=NF;i++) if($i=="Mbits/sec") print $(i-1)}' | head -1)
        rx=$(echo "$result" | grep "\[SUM\].*receiver" | awk '{for(i=1;i<=NF;i++) if($i=="Mbits/sec") print $(i-1)}' | head -1)
        tx=${tx:-0}; rx=${rx:-0}
        echo "   run $i/$RUNS:  TX ${tx}  RX ${rx}  Mbits/sec"
        total_tx=$(awk "BEGIN {print $total_tx + $tx}")
        total_rx=$(awk "BEGIN {print $total_rx + $rx}")
    done

    avg_tx=$(awk "BEGIN {printf \"%.1f\", $total_tx / $RUNS}")
    avg_rx=$(awk "BEGIN {printf \"%.1f\", $total_rx / $RUNS}")
    echo "   ── avg TX: ${avg_tx}  avg RX: ${avg_rx}  Mbits/sec"
    eval "AVG_TX_${label}=${avg_tx}"
    eval "AVG_RX_${label}=${avg_rx}"
    pkill iperf3 2>/dev/null || true
}

bench_cipher() {
    local ko="$1"
    local label="$2"

    cleanup
    sleep 1
    load_module "$ko"
    setup_tunnel
    run_iperf_avg "$label"
}

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   WireGuard netns Benchmark  (veth, no VirtualBox NIC)      ║"
echo "║   ${RUNS}×${DURATION}s  ×  ${STREAMS} streams  MSS ${MSS}  kernel $(uname -r)            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "── AES-256-GCM  (wireguard-5.15-aes, AES-NI) ────────────────"
bench_cipher "$CUSTOM_KO" "AES"

echo ""
echo "── ChaCha20-Poly1305  (stock kernel wireguard) ───────────────"
bench_cipher "stock" "ChaCha"

echo ""
echo "── AES-256-GCM  (consistency re-run) ────────────────────────"
bench_cipher "$CUSTOM_KO" "AES2"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   RESULTS  (avg of ${RUNS}×${DURATION}s, 1 warm-up discarded)              ║"
echo "╠══════════════════════════════════════════════════════════════╣"
printf "║  %-22s  TX: %8s  RX: %8s  Mbits/sec  ║\n" "AES-256-GCM (R1)"   "$AVG_TX_AES"   "$AVG_RX_AES"
printf "║  %-22s  TX: %8s  RX: %8s  Mbits/sec  ║\n" "ChaCha20-Poly1305"  "$AVG_TX_ChaCha" "$AVG_RX_ChaCha"
printf "║  %-22s  TX: %8s  RX: %8s  Mbits/sec  ║\n" "AES-256-GCM (R2)"   "$AVG_TX_AES2"  "$AVG_RX_AES2"
aes_avg=$(awk "BEGIN {printf \"%.1f\", ($AVG_TX_AES + $AVG_TX_AES2)/2}")
speedup=$(awk "BEGIN {printf \"%+.1f\", ($aes_avg / $AVG_TX_ChaCha - 1)*100}")
echo "╠══════════════════════════════════════════════════════════════╣"
printf "║  AES avg: %-8s  ChaCha: %-8s  speedup: %-10s     ║\n" \
    "${aes_avg}" "${AVG_TX_ChaCha}" "${speedup}%"
echo "╚══════════════════════════════════════════════════════════════╝"
