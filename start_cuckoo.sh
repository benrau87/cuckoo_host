#!/bin/bash
### BEGIN INIT INFO
# Provides:          Cuckoo Stuffs
# Required-Start:    $local_fs $network
# Required-Stop:     
# Default-Start:     100
# Default-Stop:      
# Short-Description: Cuckoo forwarding for client
# Description:       
### END INIT INFO
vboxmanage hostonlyif create
iptables -A FORWARD -o eth0 -i vboxnet0 -s 192.168.56.0/24 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A POSTROUTING -t nat -j MASQUERADE
sysctl -w net.ipv4.ip_forward=1
