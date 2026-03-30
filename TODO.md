wireguard-aes: What it does

Core change: replaces the data-plane cipher (ChaCha20-Poly1305) with AES-256-GCM using the Linux kernel crypto API, with runtime fallback if AES-NI isn't available. Handshake and cookie crypto are      
unchanged (still Noise_IKpsk2 with ChaCha20).

The motivation is correct: modern x86 CPUs with AES-NI can saturate multi-core VPN gateways much better than software ChaCha20 under concurrent load. The paper numbers (11% throughput, 10% less CPU) are
plausible for AES-NI hardware.

kernel_6.8.0-59 branch is the more complete one — it contains wireguard-6.8/ (the actual working 6.8 port), the experimentation stack (Grafana + Postgres + Jupyter notebooks), XDP benchmark tools, and  
updated test scripts. master is older and missing all of this.
                                                                                                                                                                                                            
---                                                                                                                                                                                                     
Issues / gaps I found

┌─────┬──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────────────────────────────────────┐
│  #  │                                                                      Issue                                                                       │                 Severity                 │     
├─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────┤
│ 1   │ module_description says "WireGuard CBC-AES" but cipher is GCM                                                                                    │ Low (cosmetic)                           │     
├─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────┤   
│ 2   │ Noise handshake string still says "Noise_IKpsk2_25519_ChaChaPoly_BLAKE2s" even when AES is active                                                │ Medium — misleading for peer negotiation │     
├─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────┤     
│ 3   │ keypair->sending.chacha_key referenced in send.c/receive.c but noise.h only defines key[32] — probably works as a name alias but should be clean │ Medium                                   │     
├─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────┤     
│ 4   │ No verification that AES is actually in use vs fallback at runtime (no /proc or debugfs entry exposing the active cipher)                        │ Medium                                   │   
├─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────┤     
│ 5   │ numtxqueues=50 / numrxqueues=50 in test scripts — extreme for testing, overkill for a 2-VM setup                                                 │ Low                                      │   
├─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────┤     
│ 6   │ master branch is behind kernel_6.8.0-59 by ~230 files; they've diverged                                                                          │ Medium                                   │   
├─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────┤     
│ 7   │ Test scripts (test_generic.sh) require root on the HOST and pre-loaded module — no isolated environment                                          │ High for reproducibility                 │   
└─────┴──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────────────────────────────────────┘
                                                                                                                                                                                                          
---                                                                                                                                                                                                       
Vagrant test environment: yes, fully feasible

Same pattern as wireguard-zk-handshake — same kernel (6.8.0-59-generic), same base box. Structure would be:

vagrant/
build-base.sh       # same as wgzk (kernel only)                                                                                                                                                        
keygen.sh           # just wg keys, no ZK needed                                                                                                                                                        
02-load-module.sh   # copy wireguard-6.8/wireguard.ko, insmod                                                                                                                                           
03-server.sh        # iperf3 server side + WG interface                                                                                                                                                 
03-client.sh        # iperf3 client side + WG interface                                                                                                                                                 
04-test.sh          # iperf3 throughput test + verify AES active                                                                                                                                        
Vagrantfile           # same two-VM pattern

Key difference from wireguard-zk: the test is iperf3 throughput (not just ping), and ideally it should compare AES vs stock WireGuard — which would require running the test twice (once with the custom  
.ko, once with stock). Or just verify the module description shows "WireGuard CBC-AES" as the paper suggests.    