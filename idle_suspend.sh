#!/bin/bash

# Configurable variables
IDLE_TIME=60    # in seconds (1 minute)
CPU_LOAD_THRESHOLD=5  # in percentage
TRAFFIC_THRESHOLD=125  # in KB/s (equals 1 Mbit/s)
NETWORK_INTERFACE="enp6s0"  # Your network interface

# Function to check for active user sessions
check_active_sessions() {
    # Use 'who' to list all current users. If the output contains any entries, return success.
    who | grep -q .
}

# Function to check network traffic
check_network_traffic() {
    # Use /proc/net/dev to get current network statistics
    local line=$(grep $NETWORK_INTERFACE /proc/net/dev)
    local initial_rx_bytes=$(echo $line | awk '{print $2}')
    local initial_tx_bytes=$(echo $line | awk '{print $10}')
    
    # Wait 1 second to measure traffic rate
    sleep 1
    
    line=$(grep $NETWORK_INTERFACE /proc/net/dev)
    local final_rx_bytes=$(echo $line | awk '{print $2}')
    local final_tx_bytes=$(echo $line | awk '{print $10}')
    
    # Calculate bytes per second
    local rx_rate=$(( (final_rx_bytes - initial_rx_bytes) / 1 ))
    local tx_rate=$(( (final_tx_bytes - initial_tx_bytes) / 1 ))
    
    # Convert to KB/s
    local rx_kbps=$(( rx_rate / 1024 ))
    local tx_kbps=$(( tx_rate / 1024 ))
    
    echo "Current network traffic: RX: ${rx_kbps} KB/s, TX: ${tx_kbps} KB/s"
    
    # Check if either rx or tx exceeds threshold
    if [ "$rx_kbps" -gt "$TRAFFIC_THRESHOLD" ] || [ "$tx_kbps" -gt "$TRAFFIC_THRESHOLD" ]; then
        return 0  # Traffic exceeds threshold
    else
        return 1  # Traffic is within threshold
    fi
}

# Monitor CPU usage and suspend the system if it's below the threshold for a certain amount of time
while true
do
    # Get the current CPU usage using mpstat
    CPU_LOAD=$(mpstat 1 1 | grep  -A 5 "%idle" | tail -n 1 | awk '{print 100 - $12}')

    # If CPU usage is below the threshold, check for active sessions and manage idle time
    if [ "$CPU_LOAD" -lt "$CPU_LOAD_THRESHOLD" ]; then
        if ! check_active_sessions && ! check_network_traffic; then
            # No active user sessions and network traffic within threshold
            if [ -z "$IDLE_START" ]; then
                IDLE_START=$(date +%s)
                echo "Starting idle timer. CPU load: ${CPU_LOAD}%, Traffic: below threshold, No active sessions."
            fi

            # Calculate the elapsed idle time
            ELAPSED=$(( $(date +%s) - $IDLE_START ))
            echo "System idle for ${ELAPSED} seconds."

            # If the system has been idle for the specified amount of time, suspend it
            if [ "$ELAPSED" -ge "$IDLE_TIME" ]; then
                echo "Suspending system now."
                systemctl suspend
                IDLE_START=
            fi
        else
            # Active user session or network traffic exceeds threshold; reset the idle timer
            echo "Active user session or network traffic detected. Preventing suspension."
            IDLE_START=
        fi
    else
        # CPU usage is above the threshold; reset the idle timer
        echo "CPU load above threshold (${CPU_LOAD}%). Preventing suspension."
        IDLE_START=
    fi

    # Wait before checking again
    sleep 60
done