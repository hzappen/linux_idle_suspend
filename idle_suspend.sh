#!/bin/bash

# Configurable variables
IDLE_TIME=60  # in seconds (5 minutes)
CPU_LOAD_THRESHOLD=10  # in percentage

# Monitor CPU usage and suspend the system if it's below the threshold for a certain amount of time
while true
do
    # Get the current CPU usage using mpstat
    CPU_LOAD=$(mpstat | grep -A 5 "%idle" | tail -n 1 | awk '{print 100 - $12}')

    # If CPU usage is below the threshold, increment the idle time counter
    if [ $CPU_LOAD -lt $CPU_LOAD_THRESHOLD ]; then
        if [ -z "$IDLE_START" ]; then
            IDLE_START=$(date +%s)
        fi

        # If the system has been idle for the specified amount of time, suspend it
        if [ $(( $(date +%s) - $IDLE_START )) -ge $IDLE_TIME ]; then
            systemctl suspend
            IDLE_START=
        fi
    else
        # If CPU usage is above the threshold, reset the idle time counter
        IDLE_START=
    fi

    # Wait for a certain amount of time before checking CPU usage again
    sleep 1
done
