#!/bin/bash

RULE_URL="https://raw.githubusercontent.com/Neo23x0/auditd/master/audit.rules"
RULE_PATH="/etc/audit/rules.d/audit.rules"

if [[ $EUID -ne 0 ]]; then
    echo "Run this script as root!"
    exit 1
fi

echo "Checking package manager..."
if command -v apt &> /dev/null; then
    PMAN="apt"
elif command -v dnf &> /dev/null; then
    PMAN="dnf"
else
    echo "Unsupported package manager: $PMAN"
    exit 1
fi

echo "Installing auditd..."
if [[ $PMAN == "apt" ]]; then
    sudo apt update && sudo apt install -y auditd audispd-plugins
elif [[ $PMAN == "dnf" ]]; then
    sudo dnf install -y audit
fi

echo "Installing audit rules..."
sudo mkdir -p /etc/audit/rules.d
sudo curl -L "$RULE_URL" -o "$RULE_PATH"
sudo chmod 640 "$RULE_PATH"

echo "Loading rules..."
if command -v augenrules >/dev/null 2>&1; then
    sudo augenrules --load
else
    sudo auditctl -R "$RULE_PATH"
fi

echo "Enabling auditd..."
sudo systemctl enable auditd
# sudo systemctl restart auditd - idk why its tweaking

echo "Verifying..."
sudo auditctl -s

echo "Loaded audit file:"
sudo auditctl -l | head -20

echo "Auditd finished, enjoy!"
