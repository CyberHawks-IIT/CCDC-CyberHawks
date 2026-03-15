#!/bin/vbash

# NOTE: This is for version VyOS 1.4
# Created 2026-03-14 - Lucas

if [ "$(id -g -n)" != "vyattacfg" ]; then
    exec sg vyattacfg -c "/bin/vbash $(readlink -f "$0") $@"
fi

source /opt/vyatta/etc/functions/script-template
set -e

echo "============================================================"
echo "VyOS Firewall Rules Viewer"
echo "============================================================"
echo

echo "[*] VyOS version"
run show version
echo

echo "============================================================"
echo "[*] Firewall-related configuration commands"
echo "============================================================"
run show configuration commands | grep '^set firewall' || echo "[!] No firewall config found"
echo

echo "============================================================"
echo "[*] Base chain summary"
echo "============================================================"

for chain in input output forward; do
    echo "--- ipv4 $chain filter ---"
    run show configuration commands | grep "^set firewall ipv4 $chain filter" || echo "[!] No ipv4 $chain filter config"
    echo
done

echo "============================================================"
echo "[*] Full firewall configuration tree"
echo "============================================================"
run show configuration commands | grep '^set firewall' || true
echo

echo "============================================================"
echo "[*] Listening services on this router"
echo "============================================================"
run ss -lntup || true
echo

echo "============================================================"
echo "[*] Live nftables ruleset"
echo "============================================================"
if command -v nft >/dev/null 2>&1; then
    run nft list ruleset || echo "[!] Could not read nftables ruleset"
else
    echo "[!] nft command not found"
fi
echo

echo "============================================================"
echo "[*] End of firewall view"
echo "============================================================"

exit