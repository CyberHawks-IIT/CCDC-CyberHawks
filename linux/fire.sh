#!/bin/bash

# Clear current rules
iptables -F

# Log
iptables -A INPUT -j LOG --log-prefix '[IPTABLES] Inbound: ' --log-tcp-options --log-ip-options --log-uid
iptables -A OUTPUT -j LOG --log-prefix '[IPTABLES] Outbound: ' --log-tcp-options --log-ip-options --log-uid
iptables -A FORWARD -j LOG --log-prefix '[IPTABLES] ROUTING??? Suss.... ' --log-tcp-options --log-ip-options --log-uid

# Set default policy as drop
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# Allow loopback
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established connections
iptables -A INPUT  -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# For every TCP/UDP port we want open on our machine:
iptables -A INPUT -p <tcp/udp> --dport <port> -j ACCEPT

# Allow ping echo request in:
iptables -A INPUT -p icmp --icmp-type 8 -j ACCEPT

# Allow DNS out
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow outbound HTTP/HTTPS if needed
iptables -A OUTPUT -p tcp --dport 80  -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT