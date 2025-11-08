#!/bin/bash
# Add static routes
# This gets around the VPN system on the mac is sending these networks through it's VPN 
# Networks:
#  172.16.0.0/12 --> MX VPN to Gardena
#  192.168.142.0/24 --> MX local IoT network
#
# Bypass local VPN for Site-to-Site VPN in firewall
#
route add 172.16.0.0 192.168.42.1 255.252.0.0 # CoG VPN in router
route add 192.168.142.0 192.168.42.1 255.255.255.0 # IoT DMZ in router
route add 10.0.0.0 192.168.42.1 255.255.255.255.0 # MD Engineering
#
# Code42 / Crashplan to bypass any VPN running on glinda
# /21 = 255.255.248.0
# /23 = 255.255.254.0
#
route add 68.65.192.0 192.168.42.1 255.255.248.0
route add 162.222.40.0 192.168.42.1 255.255.248.0
route add 67.222.248.0 192.168.42.1 255.255.248.0
route add 103.8.239.0 192.168.42.1 255.255.255.0
route add 216.223.38.0 192.168.42.1 255.255.255.0
route add 149.5.7.0 192.168.42.1 255.255.255.0
route add 216.17.8.0 192.168.42.1 255.255.255.0
route add 50.93.246.0 192.168.42.1 255.255.254.0
route add 50.93.255.0 192.168.42.1 255.255.255.0
route add 18.202.8.169 192.168.42.1 255.255.255.255
route add 34.252.107.93 192.168.42.1 255.255.255.255
route add 64.207.196.0 192.168.42.1 255.255.252.0
route add 64.207.204.0 192.168.42.1 255.255.254.0
route add 64.207.222.0 192.168.42.1 255.255.254.0

echo "*** List All Network Services ***"
networksetup -listallnetworkservices

echo "*** Set Additional Routes (all in one line) ***"
networksetup -setadditionalroutes "Ethernet" \
172.16.0.0 255.252.0.0 192.168.42.1 \
192.168.142.0 255.255.255.0 192.168.42.1 \
10.0.0.0 255.255.255.0 192.168.42.1 \
68.65.192.0 255.255.248.0 192.168.42.1 \
162.222.40.0 255.255.248.0 192.168.42.1 \
67.222.248.0 255.255.248.0 192.168.42.1 \
103.8.239.0 255.255.255.0 192.168.42.1 \
216.223.38.0 255.255.255.0 192.168.42.1 \
149.5.7.0 255.255.255.0 192.168.42.1 \
216.17.8.0 255.255.255.0 192.168.42.1 \
50.93.246.0 255.255.254.0 192.168.42.1 \
50.93.255.0 255.255.255.0 192.168.42.1 \
18.202.8.169 255.255.255.255 192.168.42.1 \
34.252.107.93 255.255.255.255 192.168.42.1 \
64.207.222.0 255.255.252.0 192.168.42.1 \
64.207.204.0 255.255.254.0 192.168.42.1 \
64.207.222.0 255.255.254.0 192.168.42.1

echo "*** Get Additional Routes ***"
networksetup -getadditionalroutes "Ethernet"
echo "*** Route testing ***"
route get 172.17.1.254
route get 192.168.142.1
route get 10.0.0.10
ping -c 1 172.17.1.254
ping -c 1 192.168.142.1
ping -c 1 10.0.0.10
