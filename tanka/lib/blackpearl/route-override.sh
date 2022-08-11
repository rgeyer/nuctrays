#!/bin/sh
VPN_GATEWAY=$(route -n | grep '^0.0.0.0' | grep 'eth0' | awk '{ print $2 }')
ip route del 0.0.0.0/0 via "${VPN_GATEWAY}"
ip route add 10.43.0.0/24 via 169.254.1.1
ip route add 192.168.0.0/16 via 169.254.1.1
echo "Default Route via ${VPN_GATEWAY} deleted."
# Give some indication to the init script that we're all set.
touch /var/run/openvpn.complete