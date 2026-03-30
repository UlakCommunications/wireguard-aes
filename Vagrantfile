# -*- mode: ruby -*-
# WireGuard AES-GCM — two-VM demo (kernel 5.15.0-173-generic)
#
# PRE-REQUISITE (once per machine):
#   1. Build the module on host:
#        cd wireguard-5.15-aes && make -C /lib/modules/5.15.0-173-generic/build M=$(pwd) modules
#   2. Build the base box (installs kernel 5.15.0-173-generic):
#        cd vagrant && bash build-base.sh
#
# USAGE:
#   vagrant up          # generates keys, spins up gateway + client, runs ping + iperf test
#   vagrant destroy -f  # tear everything down
#
# Network layout:
#   gateway  eth1=192.168.100.1  wg0=10.0.0.1/24  dum0=10.20.10.10/24
#   client   eth1=192.168.100.2  wg0=10.0.0.2/24  dum0=10.10.10.10/24

GATEWAY_IP = "192.168.100.1"
CLIENT_IP  = "192.168.100.2"
BASE_BOX   = "wgaes-base"

Vagrant.configure("2") do |config|
  config.vm.box = BASE_BOX
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 1024
    vb.cpus   = 2
    vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
  end

  # Generate WireGuard keys on HOST before any VM boots
  config.trigger.before :up do |t|
    t.name = "Generate WireGuard keys"
    t.run  = { path: "vagrant/keygen.sh" }
  end

  # Both VMs: load wireguard.ko from host
  config.vm.provision "shell", path: "vagrant/02-load-module.sh"

  # ── GATEWAY ─────────────────────────────────────────────────────────────────
  config.vm.define "gateway", primary: true do |gw|
    gw.vm.hostname = "wgaes-gateway"
    gw.vm.network "private_network", ip: GATEWAY_IP,
                  virtualbox__intnet: "wgaes-internal"
    gw.vm.provision "shell", path: "vagrant/03-gateway.sh",
                    env: { "PEER_IP" => CLIENT_IP }
  end

  # ── CLIENT ───────────────────────────────────────────────────────────────────
  config.vm.define "client" do |cl|
    cl.vm.hostname = "wgaes-client"
    cl.vm.network "private_network", ip: CLIENT_IP,
                  virtualbox__intnet: "wgaes-internal"
    cl.vm.provision "shell", path: "vagrant/03-client.sh",
                    env: { "PEER_IP" => GATEWAY_IP }
    cl.vm.provision "shell", path: "vagrant/04-test.sh"
  end
end
