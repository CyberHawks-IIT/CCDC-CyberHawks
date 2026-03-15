#!/bin/vbash

# NOTE: This is for version VyOS 1.4
# Created 2026-03-14 - Lucas

if [ "$(id -g -n)" != "vyattacfg" ]; then
    exec sg vyattacfg -c "/bin/vbash $(readlink -f "$0") $@"
fi

source /opt/vyatta/etc/functions/script-template
set -e

echo "[*] Applying transit outbound block"

configure

set firewall ipv4 forward filter default-action 'drop'

set firewall ipv4 forward filter rule 10 action 'accept'
set firewall ipv4 forward filter rule 10 state established
set firewall ipv4 forward filter rule 10 state related
set firewall ipv4 forward filter rule 10 description 'Allow established/related transit traffic'

set firewall ipv4 forward filter rule 999 action 'drop'
set firewall ipv4 forward filter rule 999 log
set firewall ipv4 forward filter rule 999 description 'Log and drop all other transit IPv4 traffic'

commit-confirm 5
save

echo "[*] Done"
exit