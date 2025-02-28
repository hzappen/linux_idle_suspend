#!/bin/bash

# Configurable variables
IDLE_TIME=10    # in seconds (5 minutes)
CPU_LOAD_THRESHOLD=50  # in percentage

# Function to check for active user sessions
check_active_sessions() {
    # Use 'who' to list all current users. If the output contains any entries, return success.
    who | grep -q .
}

# Monitor CPU usage and suspend the system if it's below the threshold for a certain amount of time
while true
do
    # Get the current CPU usage using mpstat
    CPU_LOAD=$(mpstat 1 1 | grep  -A 5 "%idle" | tail -n 1 | awk '{print 100 - $12}')

    # If CPU usage is below the threshold, check for active sessions and manage idle time
    if [ "$CPU_LOAD" -lt "$CPU_LOAD_THRESHOLD" ]; then
        if ! check_active_sessions; then
            # No active user sessions detected
            if [ -z "$IDLE_START" ]; then
                IDLE_START=$(date +%s)
            fi

            # Calculate the elapsed idle time
            ELAPSED=$(( $(date +%s) - $IDLE_START ))

            # If the system has been idle for the specified amount of time, suspend it
            if [ "$ELAPSED" -ge "$IDLE_TIME" ]; then
                systemctl suspend
                IDLE_START=
            fi
        else
            # Active user session detected; reset the idle timer
            echo "Active user session detected. Preventing suspension."
            IDLE_START=
        fi
    else
        # CPU usage is above the threshold; reset the idle timer
        IDLE_START=
    fi

    # Wait before checking again
    sleep 1
done
