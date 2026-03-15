#!/bin/vbash

# NOTE: This is for version VyOS 1.4
# Created 2026-03-14 - Lucas

if [ "$(id -g -n)" != "vyattacfg" ]; then
    exec sg vyattacfg -c "/bin/vbash $(readlink -f "$0") $@"
fi

source /opt/vyatta/etc/functions/script-template
set -e

echo "============================================================"
echo "VyOS Router Hardening Script"
echo "============================================================"
echo

echo "[*] Checking current VyOS version"
run show version
echo

echo "[*] Entering configuration mode"
configure

echo "[*] Checking for configured services"

SERVICES=("ssh" "snmp" "lldp" "config-sync" "console-server")

for svc in "${SERVICES[@]}"; do
    if run show configuration commands | grep -q "set service $svc"; then
        echo "[+] Service '$svc' is configured — removing it"
        delete service $svc
    else
        echo "[✓] Service '$svc' not configured"
    fi
done

echo
echo "[*] Configuration changes to be applied:"
show | compare
echo

echo "[*] Committing configuration with rollback safety (5 minutes)"
commit-confirm 5

echo "[*] Saving configuration"
save

echo
echo "[*] Checking listening network services on router"
run ss -lntup || true
echo

echo "[*] Checking SSH port (22)"
if run ss -lnt | grep -Eq '(^|[[:space:]])LISTEN.*:22([[:space:]]|$)'; then
    echo "[!] WARNING: Something is listening on TCP 22"
else
    echo "[✓] No service listening on TCP 22"
fi

echo
echo "[*] Checking Telnet port (23)"
if run ss -lnt | grep -Eq '(^|[[:space:]])LISTEN.*:23([[:space:]]|$)'; then
    echo "[!] WARNING: Something is listening on TCP 23"
else
    echo "[✓] No service listening on TCP 23"
fi

echo
echo "[*] Checking SNMP port (161)"
if run ss -lun | grep -Eq '(:161)'; then
    echo "[!] WARNING: Something is listening on UDP 161 (SNMP)"
else
    echo "[✓] No SNMP listener detected"
fi

echo
echo "============================================================"
echo "Hardening script completed."
echo "If the router becomes unreachable, the config will auto-rollback"
echo "in 5 minutes due to commit-confirm."
echo "============================================================"

exit