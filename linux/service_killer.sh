#!/bin/bash
# >:) full version lets you kill directly
# Took this list from Cedarville's repo, shout out them!

echo "
              !___!               ^___^
           |(   ⭑⏘⭑)  {{  {{{   ( - < -)|
           | |____|-oc[_]_\̅_̅/̷̚ʾo-|   o- \|
           [______]      _||_    [______]

           \"I could be killing services
            AND drinking coffee right now...\"
           service killer - cc00ffee

=====================================================

"

SERVICE_FILE="systemctl-safe-services.txt"

BAD_SERVICES=(
    ssh sshd sshfs sssd
    cockpit.service cockpit.socket
    tailscale tailscaled
    cups
    nfs-kernel-server nfs-common
    docker git
    crond cron atd anacrond chrond chronyd
)

if [[ ! -f "$SERVICE_FILE" ]]; then
    echo "Good systemctl service file not found :("
    exit 1
fi

echo "Getting active services..."
mapfile -t ACTIVE_SERVICES < <(systemctl list-units --type=service --state=running --no-legend | awk '{print $1}')

echo "Comparing against service lists..."
echo

BAD=()
EXAMINE=()

for SERVICE in "${ACTIVE_SERVICES[@]}"; do
    is_bad=false
    for BAD_SVC in "${BAD_SERVICES[@]}"; do
        if [[ "$SERVICE" == "$BAD_SVC" ]]; then
            is_bad=true
            break
        fi
    done

    if $is_bad; then
        BAD+=("$SERVICE")
        continue
    fi

    if grep -qx "$SERVICE" "$SERVICE_FILE"; then
        continue
    fi

    EXAMINE+=("$SERVICE")
done

# Bad services
if [[ ${#BAD[@]} -gt 0 ]]; then
    echo "=== BAD SERVICES (known threats) — auto-killing ==="
    echo "--------------------------------"
    for SERVICE in "${BAD[@]}"; do
        echo "Eliminating known bad service: $SERVICE"
        ./kill_service.sh "$SERVICE"
        echo "$SERVICE has been eliminated."
    done
    echo "All bad services eliminated!"
    echo
fi

# Unknown services
if [[ ${#EXAMINE[@]} -gt 0 ]]; then
    echo "=== UNKNOWN SERVICES (needs examination) ==="
    while true; do
        echo "--------------------------------"
        for i in "${!EXAMINE[@]}"; do
            echo "[$i] ${EXAMINE[$i]}"
        done
        echo "Enter number to examine a service, 'k <num>' to kill one, or 'q' to quit:"
        read -r choice

        if [[ "$choice" == "q" ]]; then
            echo "Exiting examination."
            break
        fi

        if [[ "$choice" =~ ^k[[:space:]]+([0-9]+)$ ]]; then
            idx="${BASH_REMATCH[1]}"
            if [[ -z "${EXAMINE[$idx]+x}" ]]; then
                echo "Invalid index."
                continue
            fi
            SERVICE_TO_KILL="${EXAMINE[$idx]}"
            echo "Eliminating known bad service: $SERVICE_TO_KILL"
            ./kill_service.sh "$SERVICE_TO_KILL"
            echo "$SERVICE_TO_KILL has been eliminated."
            unset 'EXAMINE[idx]'
            EXAMINE=("${EXAMINE[@]}")
            if [[ ${#EXAMINE[@]} -eq 0 ]]; then
                echo "All unknown services handled!"
                break
            fi
            continue
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            if [[ -z "${EXAMINE[$choice]+x}" ]]; then
                echo "Invalid index."
                continue
            fi
            SVC="${EXAMINE[$choice]}"
            echo ""
            echo "--- $SVC ---"
            systemctl status "$SVC" --no-pager -l 2>/dev/null || echo "Could not get status."
            echo ""
            continue
        fi

        echo "Unknown command. Use a number to examine, 'k <num>' to kill, or 'q' to quit."
    done
else
    echo "No unknown services to examine."
fi

if [[ ${#BAD[@]} -eq 0 && ${#EXAMINE[@]} -eq 0 ]]; then
    echo ""
    echo "All clear! Stay safe!"
fi

echo "Done. Stay safe!"
