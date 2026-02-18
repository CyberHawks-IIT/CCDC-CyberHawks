#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "Run this script as root!"
    exit 1
fi

echo "Checking package manager..."
if command -v apt &> /dev/null; then
    PMAN="apt"
elif command -v yum &> /dev/null; then
    PMAN="yum"
elif command -v dnf &> /dev/null; then
    PMAN="dnf"
else
    echo "Unsupported package manager: $PMAN"
    exit 1
fi

echo "Installing ClamAV..."
if [[ $PMAN == "apt" ]]; then
    sudo apt update && sudo apt install -y clamav clamav-daemon
elif [[ $PMAN == "yum" || $PMAN == "dnf" ]]; then
    sudo $PMAN install -y clamav clamav-freshclam clamd
fi

echo "Getting virus database..."
sudo systemctl stop clamav-freshclam 2>/dev/null || true # incase it is running already to avoid conflicts
sudo freshclam || true

echo "Configuring clamd..."
if [[ $PMAN == "yum" || $PMAN == "dnf" ]]; then
    sudo cp /etc/clamd.d/scan.conf /etc/clamd.d/scan.conf.bak 2>/dev/null || true
    sudo tee /etc/clamd.d/scan.conf > /dev/null <<EOF
LocalSocket /run/clamd.scan/clamd.sock
LocalSocketMode 660
User clamscan
EOF

    sudo mkdir -p /run/clamd.scan
    sudo chown clamscan:clamscan /run/clamd.scan
fi

if [[ $PMAN == "apt" ]]; then
    sudo systemctl enable --now clamav-daemon
    sudo systemctl enable --now clamav-freshclam
elif [[ $PMAN == "yum" || $PMAN == "dnf" ]]; then
    sudo systemctl enable --now clamd@scan
    sudo systemctl enable --now clamav-freshclam
fi

if ! sudo systemctl is-active --quiet clamd@scan 2>/dev/null && ! sudo systemctl is-active --quiet clamav-daemon 2>/dev/null; then
    echo "WARNING: ClamAV daemon failed to start. On-demand scanning is still available with clamscan!"
fi

echo "Verifying ClamAV installation..."
clamscan --version

echo "ClamAV installation complete!"

echo "Running initial scan..."
SCAN_LOG="/var/log/clamav/initial_scan.log"

sudo mkdir -p /var/log/clamav
sudo touch "$SCAN_LOG"
sudo chown clamscan:clamscan /var/log/clamav
sudo chmod 755 /var/log/clamav

SCAN_DIRS=(
    /home
    /root
    /etc
    /var/lib
    /tmp
    /var/tmp
    /usr/local/bin
)

echo "Scanning the following directories:"
for DIR in "${SCAN_DIRS[@]}"; do
    if [[ -d "$DIR" ]]; then
        echo "  - $DIR"
    fi
done

sudo clamscan -r --infected --log="$SCAN_LOG" \
    --exclude-dir="^/proc" \
    --exclude-dir="^/sys" \
    --exclude-dir="^/dev" \
    "${SCAN_DIRS[@]}"
SCAN_EXIT=$?

if [[ $SCAN_EXIT -eq 0 ]]; then
    echo "Scan complete. No threats found."
    echo "Log saved to $SCAN_LOG"
elif [[ $SCAN_EXIT -eq 1 ]]; then
    echo "Scan complete. Infected files found! Check $SCAN_LOG for details."
    exit 1
else
    echo "Scan encountered an error. Check $SCAN_LOG for details."
    exit 2
fi
