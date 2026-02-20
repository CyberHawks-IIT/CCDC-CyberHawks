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


while true; do
    echo "Suspicious services detected:"
    echo "--------------------------------"
    for i in "${!SUS[@]}"; do
        echo "[$i] ${SUS[$i]}"
    done
    echo "Enter the number of the service to kill (or 'q' to quit):"
    read -r choice

    if [[ "$choice" == "q" ]]; then
        echo "Exiting, thank you!"
        break
    fi

    SERVICE_TO_KILL="${SUS[$choice]}"
    echo "Processing your kill..."
    ./kill_service.sh "$SERVICE_TO_KILL"

    unset 'SUS[choice]'
    SUS=("${SUS[@]}")

    if [[ ${#SUS[@]} -eq 0 ]]; then
        echo "All your services belong to us! (No more sus services)..."
        break
    fi
done

echo "Done. Stay safe!"
