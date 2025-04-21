# Wireguard with AES Support
WireGuard, a high-performance VPN integrated into the Linux kernel, is renowned for its speed and reliance on software-based encryption. However, it faces limitations as a VPN Gateway (VPNGW), particularly in software-defined networks (SDNs), where its throughput drops significantly with multiple client connections and hardware encryption remains underutilized. This study presents an enhanced WireGuard implementation that incorporates AES encryption with hardware acceleration to boost efficiency. Using kernel-based AES results in an 11% increase in throughput, a 5.5% decrease in retransmissions, and a 10% reduction in CPU usage. Meanwhile, user-space AES (implementation [[here](https://github.com/mfyuce/boringtun/tree/registry-trait-with-fast)] ) can deliver up to 19.47% higher throughput on modern CPUs, achieving terabit-per-second speeds and greater efficiency with larger MTUs.

## Building

**More information may be found at [WireGuard.com](https://www.wireguard.com/).**

## License

This project is released under the [GPLv2](COPYING).

## TEST

```bash
cd run
./test_generic_single.sh <how_many_tunnels>
```
