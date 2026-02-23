#!/bin/bash
set -euo pipefail

# claw-cage — Network Isolation Rules
# Blocks Docker containers on claw-net from reaching the local network (RFC1918).
# Allows internet access and Docker internal DNS.
# Must be run as root: sudo bash iptables-rules.sh

# --- Root check ---
if [[ "$EUID" -ne 0 ]]; then
    echo "Error: This script must be run as root (sudo)."
    echo "Usage: sudo bash iptables-rules.sh"
    exit 1
fi

CLAW_SUBNET="172.30.0.0/24"

# --- Check Docker is running and DOCKER-USER chain exists ---
if ! iptables -L DOCKER-USER -n >/dev/null 2>&1; then
    echo "Error: DOCKER-USER chain not found."
    echo "Make sure Docker is installed and running before applying network rules."
    echo "  sudo systemctl start docker"
    exit 1
fi

echo "=== claw-cage network isolation ==="
echo "Applying rules for subnet $CLAW_SUBNET..."
echo ""

# --- Flush existing claw-cage rules (idempotent) ---
# Delete all rules in DOCKER-USER that reference CLAW_SUBNET
while iptables -D DOCKER-USER -s "$CLAW_SUBNET" -d 192.168.0.0/16 -j DROP 2>/dev/null; do :; done
while iptables -D DOCKER-USER -s "$CLAW_SUBNET" -d 10.0.0.0/8 -j DROP 2>/dev/null; do :; done
while iptables -D DOCKER-USER -s "$CLAW_SUBNET" -d 172.16.0.0/12 -j DROP 2>/dev/null; do :; done
while iptables -D DOCKER-USER -s "$CLAW_SUBNET" -d "$CLAW_SUBNET" -j ACCEPT 2>/dev/null; do :; done
while iptables -D DOCKER-USER -s "$CLAW_SUBNET" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; do :; done
while iptables -D DOCKER-USER -s "$CLAW_SUBNET" -d 127.0.0.11 -p udp --dport 53 -j ACCEPT 2>/dev/null; do :; done

# --- Insert rules ---
# We use -I (insert at position 1) in reverse order so the final chain reads top-to-bottom:
#   1. ACCEPT DNS        (inserted last → lands at position 1)
#   2. ACCEPT ESTABLISHED (inserted 5th)
#   3. ACCEPT internal    (inserted 4th)
#   4. DROP 172.16/12     (inserted 3rd)
#   5. DROP 10/8          (inserted 2nd)
#   6. DROP 192.168/16    (inserted 1st)

# --- Step 1: DROP rules (inserted first, evaluated last) ---
iptables -I DOCKER-USER -s "$CLAW_SUBNET" -d 192.168.0.0/16 -j DROP
iptables -I DOCKER-USER -s "$CLAW_SUBNET" -d 10.0.0.0/8 -j DROP
iptables -I DOCKER-USER -s "$CLAW_SUBNET" -d 172.16.0.0/12 -j DROP

# --- Step 2: ACCEPT rules (inserted at position 1, evaluated first) ---
# Internal traffic: 172.30.0.0/24 is inside 172.16.0.0/12, needs explicit ACCEPT
iptables -I DOCKER-USER 1 -s "$CLAW_SUBNET" -d "$CLAW_SUBNET" -j ACCEPT

# Established/related connections
iptables -I DOCKER-USER 1 -s "$CLAW_SUBNET" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# DNS to Docker's embedded resolver
iptables -I DOCKER-USER 1 -s "$CLAW_SUBNET" -d 127.0.0.11 -p udp --dport 53 -j ACCEPT

# --- Persist rules across reboots ---
echo ""
if dpkg -s iptables-persistent >/dev/null 2>&1; then
    echo "iptables-persistent already installed."
else
    echo "Installing iptables-persistent..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
fi
netfilter-persistent save

# --- Summary ---
echo ""
echo "=== claw-cage rules applied ==="
echo ""
echo "Rule order in DOCKER-USER:"
echo "  1. ACCEPT  DNS to 127.0.0.11 (Docker resolver)"
echo "  2. ACCEPT  ESTABLISHED,RELATED connections"
echo "  3. ACCEPT  $CLAW_SUBNET -> $CLAW_SUBNET (internal)"
echo "  4. DROP    $CLAW_SUBNET -> 172.16.0.0/12"
echo "  5. DROP    $CLAW_SUBNET -> 10.0.0.0/8"
echo "  6. DROP    $CLAW_SUBNET -> 192.168.0.0/16"
echo ""
echo "Containers on claw-net can reach the internet but NOT your local network."
echo "Rules saved — they will persist across reboots."
