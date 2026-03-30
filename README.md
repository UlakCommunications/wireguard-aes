# WireGuard with AES-256-GCM Hardware Acceleration

WireGuard uses ChaCha20-Poly1305 by default. On CPUs with AES-NI this leaves
hardware acceleration unused. This project replaces the data-path cipher with
AES-256-GCM (via the kernel `crypto_aead` API) while keeping the original
Noise handshake intact. On hardware without AES-NI it falls back to
ChaCha20-Poly1305 automatically.

**Benchmark result (kernel 5.15, veth/netns, no NIC overhead):**

| Cipher | Throughput |
|---|---|
| AES-256-GCM (AES-NI) | ~3.4 Gbits/sec |
| ChaCha20-Poly1305 (stock) | ~2.5 Gbits/sec |
| **Speedup** | **+34%** |

## Requirements

- Ubuntu 22.04 host (tested with 22.04.x)
- VirtualBox + Vagrant
- `linux-headers-5.15.0-173-generic` installed on the host

```bash
sudo apt-get install linux-headers-5.15.0-173-generic virtualbox vagrant
```

## Quick Start

```bash
git clone <repo>
cd wireguard-5.10.55

# 1. Build the kernel module (requires 5.15 headers on host)
bash build.sh

# 2. Build the Vagrant base box (once — takes ~5 min)
cd vagrant && bash build-base.sh && cd ..

# 3. Start the VMs
vagrant up

# 4. Run the benchmark (inside gateway VM)
vagrant ssh gateway -- -T "sudo bash /vagrant/vagrant/netns-bench.sh"
```

## What the benchmark does

`vagrant/netns-bench.sh` runs entirely inside the VM using Linux network
namespaces and a veth pair — no VirtualBox NIC involved. It:

1. Loads the custom `wireguard-5.15-aes` module (AES-256-GCM)
2. Creates two network namespaces connected by a veth pair
3. Sets up a WireGuard tunnel between them
4. Runs `iperf3` (3 × 20s, 4 streams) and reports averages
5. Repeats with the stock kernel WireGuard (ChaCha20-Poly1305)
6. Reports speedup %

## Repository layout

```
build.sh                   # builds wireguard-5.15-aes/wireguard.ko
wireguard-5.15-aes/        # AES-256-GCM modified WireGuard source (kernel 5.15)
Vagrantfile                # two-VM setup: gateway + client
vagrant/
  build-base.sh            # builds the wgaes-base Vagrant box (run once)
  build-base/              # Vagrantfile for the base box
  01-install-kernel.sh     # installs kernel 5.15.0-173-generic inside VM
  02-load-module.sh        # loads wireguard.ko inside VM
  03-gateway.sh            # configures gateway VM (wg0, iperf3 server)
  03-client.sh             # configures client VM (wg0)
  netns-bench.sh           # in-VM netns benchmark (AES vs ChaCha)
  benchmark.sh             # host-side benchmark via vagrant ssh
benchmark.sh               # host-side orchestration script
```

## How AES-256-GCM is integrated

- `noise.c` / `noise.h`: each `noise_keypair` holds pre-expanded
  `crypto_aead` handles (`aead_enc` / `aead_dec`), set up once at
  handshake time.
- `device.c` / `device.h`: per-CPU `aead_request` buffers allocated at
  device init; freed on device destroy.
- `send.c` / `receive.c`: `encrypt_packet` / `decrypt_packet` use the
  per-CPU request buffer with the keypair's AEAD handle. Zero key
  expansion or allocation per packet.
- If `crypto_alloc_aead("gcm(aes)", ...)` fails (no AES-NI), the device
  falls back to ChaCha20-Poly1305 for all packets.

## License

GPLv2 — see [COPYING](COPYING).
