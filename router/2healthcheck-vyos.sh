#!/usr/bin/env bash
set -euo pipefail

# NOTE: This is for version VyOS 1.4
# Created 2026-03-14 - Lucas Ferguson

OUT_DIR="./healthcheck"
TS="$(date +%Y%m%d-%H%M%S)"
OUT="$OUT_DIR/$TS"
mkdir -p "$OUT"

# =========================
# CONFIGURATION
# =========================
EXPECTED_INTERFACES=("eth0" "eth1")
PING_TARGETS=("192.168.10.1" "8.8.8.8")
DNS_TEST_NAME="google.com"

# Competition preference
EXPECT_SSH_DISABLED="yes"
EXPECT_TELNET_DISABLED="yes"

# =========================
# OUTPUT HELPERS
# =========================
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() {
    echo "✅ PASS: $*"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo "❌ FAIL: $*"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
    echo "⚠️ WARN: $*"
    WARN_COUNT=$((WARN_COUNT + 1))
}

section() {
    echo "== $* =="
}

run_vyos_cmd() {
    local outfile="$1"
    local cmd="$2"

    vbash -s <<EOF > "$outfile"
source /opt/vyatta/etc/functions/script-template
run $cmd
exit
EOF
}

# =========================
# SNAPSHOT COLLECTION
# =========================
echo "[*] Writing health snapshot to $OUT"

run_vyos_cmd "$OUT/version.txt" "show version"
run_vyos_cmd "$OUT/system-image.txt" "show system image"
run_vyos_cmd "$OUT/interfaces.txt" "show interfaces"
run_vyos_cmd "$OUT/routes-raw.txt" "show ip route"
run_vyos_cmd "$OUT/config-commands.txt" "show configuration commands"

# Strip route age timers to reduce false diffs
sed -E 's/, [0-9]{2}:[0-9]{2}:[0-9]{2}$//' "$OUT/routes-raw.txt" > "$OUT/routes.txt"
rm -f "$OUT/routes-raw.txt"

ip -br link > "$OUT/ip-link.txt"
ip -br addr > "$OUT/ip-addr.txt"
ip route show table all > "$OUT/ip-route.txt"
ss -lntup | sort > "$OUT/listening.txt" || true

{
    ps -ef | head -n 1
    ps -ef | tail -n +2 | sort
} > "$OUT/ps.txt"

systemctl list-unit-files --type=service --state=enabled | sort > "$OUT/enabled-services.txt" || true
systemctl list-units --type=service --state=running | sort > "$OUT/running-services.txt" || true
getent passwd | sort > "$OUT/passwd.txt"

if [ -f /config/config.boot ]; then
    sha256sum /config/config.boot > "$OUT/config.boot.sha256"
fi

if [ -d /config/scripts ]; then
    ls -laR /config/scripts > "$OUT/config-scripts.txt"
fi

# =========================
# LIVE HEALTH CHECKS
# =========================
HEALTH_REPORT="$OUT/health-report.txt"
exec > >(tee "$HEALTH_REPORT") 2>&1

section "VyOS Router Health Check"
echo "Timestamp: $TS"
echo

section "Basic Files"
if [ -f /config/config.boot ]; then
    pass "/config/config.boot exists"
else
    fail "/config/config.boot is missing"
fi

section "Interfaces"
for iface in "${EXPECTED_INTERFACES[@]}"; do
    if ip link show "$iface" >/dev/null 2>&1; then
        state="$(ip -br link show "$iface" | awk '{print $2}')"
        if [[ "$state" == "UP" ]]; then
            pass "Interface $iface is UP"
        else
            fail "Interface $iface is not UP (state: $state)"
        fi
    else
        fail "Interface $iface does not exist"
    fi
done

section "Routing"
if ip route | grep -q '^default '; then
    pass "Default route exists"
else
    fail "Default route is missing"
fi

section "Reachability"
for target in "${PING_TARGETS[@]}"; do
    if ping -c 1 -W 2 "$target" >/dev/null 2>&1; then
        pass "Ping to $target succeeded"
    else
        fail "Ping to $target failed"
    fi
done

section "DNS"
if getent hosts "$DNS_TEST_NAME" >/dev/null 2>&1; then
    resolved_ip="$(getent hosts "$DNS_TEST_NAME" | awk '{print $1}' | head -n 1)"
    pass "DNS resolved $DNS_TEST_NAME -> $resolved_ip"
else
    fail "DNS resolution failed for $DNS_TEST_NAME"
fi

section "SSH"
SSH_CONFIG_PRESENT="no"
if grep -q "^set service ssh " "$OUT/config-commands.txt"; then
    SSH_CONFIG_PRESENT="yes"
fi

SSH_PORT_LISTENING="no"
if ss -lnt | awk '{print $4}' | grep -Eq '(^|:)(22)$'; then
    SSH_PORT_LISTENING="yes"
fi

if [[ "$EXPECT_SSH_DISABLED" == "yes" ]]; then
    if [[ "$SSH_CONFIG_PRESENT" == "no" && "$SSH_PORT_LISTENING" == "no" ]]; then
        pass "SSH appears disabled"
    else
        fail "SSH appears enabled or listening"
    fi
else
    if [[ "$SSH_CONFIG_PRESENT" == "yes" || "$SSH_PORT_LISTENING" == "yes" ]]; then
        pass "SSH appears enabled"
    else
        fail "SSH appears disabled but was expected enabled"
    fi
fi

section "Telnet"
TELNET_LISTENING="no"
if ss -lnt | awk '{print $4}' | grep -Eq '(^|:)(23)$'; then
    TELNET_LISTENING="yes"
fi

if [[ "$EXPECT_TELNET_DISABLED" == "yes" ]]; then
    if [[ "$TELNET_LISTENING" == "no" ]]; then
        pass "Telnet is not listening on TCP 23"
    else
        fail "Telnet appears to be listening on TCP 23"
    fi
else
    if [[ "$TELNET_LISTENING" == "yes" ]]; then
        pass "Telnet is listening"
    else
        fail "Telnet is not listening but was expected enabled"
    fi
fi

section "Optional Safety Checks"
if grep -q "^set service ssh " "$OUT/config-commands.txt"; then
    warn "SSH configuration exists in config"
fi

if grep -Ei 'zabbix|telegraf|openvpn' "$OUT/running-services.txt" >/dev/null 2>&1; then
    warn "Interesting service names found in running services"
else
    pass "No obvious suspicious service names found in running services"
fi

section "Summary"
echo "Passes : $PASS_COUNT"
echo "Fails  : $FAIL_COUNT"
echo "Warns  : $WARN_COUNT"

if [[ "$FAIL_COUNT" -eq 0 ]]; then
    echo
    echo "Overall status: HEALTHY"
else
    echo
    echo "Overall status: ATTENTION NEEDED"
fi

# =========================
# QUIET SUMMARY + HASHES
# =========================
{
    echo "Health Check Snapshot"
    echo "Timestamp: $TS"
    echo
    echo "Generated files:"
    find "$OUT" -maxdepth 1 -type f -printf "%f\n" | sort | sed 's/^/- /'
} > "$OUT/summary.txt"

(
    cd "$OUT"
    HASH_TARGETS=(
        "version.txt"
        "system-image.txt"
        "interfaces.txt"
        "routes.txt"
        "config-commands.txt"
        "ip-link.txt"
        "ip-addr.txt"
        "ip-route.txt"
        "listening.txt"
        "enabled-services.txt"
        "running-services.txt"
        "passwd.txt"
        "config.boot.sha256"
        "config-scripts.txt"
        "health-report.txt"
    )

    : > file-hashes.txt
    for f in "${HASH_TARGETS[@]}"; do
        if [ -f "$f" ]; then
            sha256sum "$f" >> file-hashes.txt
        fi
    done
    sort -o file-hashes.txt file-hashes.txt
)

ln -sfn "$TS" "$OUT_DIR/latest"
echo
echo "[*] Created Health Check at $OUT"