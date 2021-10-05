#!/bin/sh
VPN_GATEWAY=$(route -n | awk 'NR==3' | awk '{ print $2 }')
ip route del 0.0.0.0/1 via $VPN_GATEWAY
ip route add 192.168.1.0/24 via 169.254.1.1
echo "Route Updated