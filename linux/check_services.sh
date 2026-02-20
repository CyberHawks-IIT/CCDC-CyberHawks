#!/bin/bash

SERVICE_FILE="systemctl-safe-services.txt"

if [[ ! -f "$SERVICE_FILE" ]]; then
    echo "Good systemctl service file not found :("
    exit 1
fi

echo "Getting active services..."
mapfile -t ACTIVE_SERVICES < <(systemctl list-units --type=service --state=running --no-legend | awk '{print $1}')

echo "Comparing against good services list..."
echo

SUS=()

for SERVICE in "${ACTIVE_SERVICES[@]}"; do
    if ! grep -qx "$SERVICE" "$SERVICE_FILE"; then
        SUS+=("$SERVICE")
    fi
done

if [[ ${#SUS[@]} -eq 0 ]]; then
    echo "No sussy services found."
    exit 0
fi

echo "Suspicious services detected:"
echo "--------------------------------"
for i in "${!SUS[@]}"; do
    echo "[$i] ${SUS[$i]}"
done

echo "Done. Stay safe!"
