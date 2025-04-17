#!/bin/bash
set -x
# ifconfig eth0 172.16.25.125 netmask 255.255.255.224 broadcast 172.16.25.63

cnt=$1
netnsleft="leftns$cnt"
netnsright="rightns$cnt"
leftip=192.$((168 + $cnt + 1)).0.$(($cnt + 1)) #+2 bir sonrakinde
rightip=192.$((168 + $cnt + 1)).0.$(($cnt + 2)) #+2 bir sonrakinde
leftveth=veth$(($cnt)) #+2 bir sonrakinde
rightveth=veth$(($cnt+1)) #+2 bir sonrakinde
#wireguard
#wgcmd=wg
#boringtun
wgcmd=boringtun

pretty() { echo -e "\x1b[32m\x1b[1m[+] ${1:+NS$1: }${2}\x1b[0m" >&3; }
sleep() { read -t "$1" -N 0 || true; }
waitiperf() { while [[ $(ss -N "$1" -tlp "sport = $((5201 + $cnt + 1))") != *iperf3* ]]; do sleep 0.1; done; }

cleanup() {
    ps aux | grep wg${cnt} | awk '{print $2}' | xargs sudo kill -9
    ip netns del $netnsleft
    ip netns del $netnsright
    exit
}

trap cleanup EXIT

ip netns add $netnsleft
ip netns add $netnsright
umask 077
wg genkey > ./out/private_left${cnt}
wg genkey > ./out/private_right${cnt}
wg pubkey <./out/private_left${cnt}> ./out/publeft${cnt}
wg pubkey <./out/private_right${cnt}> ./out/pubright${cnt}
pbl_left=$(cat ./out/publeft${cnt})
pbl_right=$(cat ./out/pubright${cnt})

ip link add $leftveth type veth peer $rightveth
ip link set dev $leftveth netns $netnsleft
ip netns exec $netnsleft ip addr add $leftip/24 dev $leftveth
ip netns exec $netnsleft ip link set up dev $leftveth
#ethtool $leftveth
#ifconfig $leftveth
#cat /sys/class/net/$leftveth/speed


if [[ "$wgcmd" == "wg" ]]; then
  ip netns exec $netnsleft ip link add dev wg${cnt} type wireguard
else
  #if [[ "$wgcmd" == "boringtune" ]]; then
  #--disable-multi-queue --disable-connected-udp   --disable-drop-privileges
  sudo ip netns exec $netnsleft /home/ulak/aes/boringtun/target/release/boringtun-cli   -t 1 -v trace -l ./out/wg1_${cnt}.log wg${cnt}
#  sudo ip netns exec $netnsleft $(pwd)/boringtune/boringtun-cli   -t 1 -v trace -l ./out/wg1_${cnt}.log wg${cnt}
  sleep 5
fi


ip netns exec $netnsleft ip address add dev wg${cnt} 192.168.$((${cnt} + 1)).$((${cnt} + 1))/24
ip netns exec $netnsleft ip link set up dev wg${cnt}
ip netns exec $netnsleft wg set wg${cnt} private-key ./out/private_left${cnt}
ip netns exec $netnsleft ip link add dum0 type dummy
ip netns exec $netnsleft ip addr add 10.10.$((${cnt} + 10)).10/24 dev dum0
ip netns exec $netnsleft ip link set up dev dum0
ip netns exec $netnsleft ip route add default dev wg${cnt}
#$((51820 + $cnt + 1))
ip netns exec $netnsleft wg set wg${cnt} listen-port $((51820 + ${cnt} + 1)) peer "$pbl_right" allowed-ips 0.0.0.0/0 endpoint $rightip:$((51820 + ${cnt} + 1))
# ip netns exec $netnsleft ip a s


ip link set dev $rightveth netns $netnsright
ip netns exec $netnsright ip addr add $rightip/24 dev $rightveth
ip netns exec $netnsright ip link set up dev $rightveth
#ethtool $rightveth
#ifconfig $rightveth
#cat /sys/class/net/$rightveth/speed


if [[ "$wgcmd" == "wg" ]]; then
   ip netns exec $netnsright ip link add dev wg${cnt} type wireguard
else
    #if [[ "$wgcmd" == "boringtune" ]]; then
    #--disable-multi-queue --disable-connected-udp   --disable-drop-privileges
  sudo ip netns exec $netnsright /home/ulak/aes/boringtun/target/release/boringtun-cli   -t 1 -v trace -l ./out/wg2_${cnt}.log wg${cnt}
#  sudo ip netns exec $netnsright $(pwd)/boringtun/boringtun-cli   -t 1 -v trace -l ./out/wg2_${cnt}.log wg${cnt}
  sleep 5
fi




ip netns exec $netnsright ip address add dev wg${cnt} 192.168.$((${cnt} + 1)).$((${cnt} + 2))/24
ip netns exec $netnsright ip link set up dev wg${cnt}
ip netns exec $netnsright wg set wg${cnt} private-key ./out/private_right${cnt}
ip netns exec $netnsright ip link add dum0 type dummy
ip netns exec $netnsright ip addr add 10.20.$((${cnt} + 20)).10/24 dev dum0
ip netns exec $netnsright ip link set up dev dum0
ip netns exec $netnsright ip route add default dev wg${cnt}
ip netns exec $netnsright wg set wg${cnt} listen-port $((51820 + ${cnt} + 1)) peer "$pbl_left" allowed-ips 0.0.0.0/0 endpoint $leftip:$((51820 + ${cnt} + 1))

# ip a s
echo --------------------
ip netns exec $netnsleft ip a s
echo --------------------
ip netns exec $netnsright ip a s
echo --------------------
wg show
echo --------------------
ip netns exec $netnsleft wg show
echo --------------------
ip netns exec $netnsright  wg show
echo --------------------


ip netns exec $netnsright ping -c 1 10.10.$((${cnt} + 10)).10 -I 10.20.$((${cnt} + 20)).10

echo Test $cnt

#-p $((5201 + $cnt + 1))


ip netns exec $netnsleft iperf3 -p $((5201 + $cnt + 1)) -s -B 10.10.$((${cnt} + 10)).10 --forceflush | grep '[SUM]'  &

waitiperf $netnsleft
#-p $((5201 + $cnt + 1))
ip netns exec $netnsright iperf3  -p $((5201 + $cnt + 1)) -c 10.10.$((${cnt} + 10)).10 -B 10.20.$((${cnt} + 20)).10 -t 20 -P 1 -M 1310  --forceflush #| grep '[SUM]'

