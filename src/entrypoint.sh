#!/bin/sh

# Function to handle SIGTERM
cleanup() {
    echo "INFO:SeplosBMS:Container stopped, cleaning up and exiting..."
    pkill socat
    kill -s SIGTERM $!
    wait $!
}

# Trap SIGTERM and call cleanup function
trap cleanup SIGTERM

start_socat() {
    local ip=$1
    local port=$2
    local device=$3
    echo "Starting socat for device $device at ${ip}:${port}"
    socat pty,link=$device,raw tcp:$ip:$port,retry,interval=.2,forever &
    socat_pid=$!
    sleep 2  # Give socat time to establish the connection
    if ! kill -0 $socat_pid 2>/dev/null; then
        echo "ERROR: Failed to start socat for device $device"
        return 1
    fi
    echo "socat started successfully for device $device"
}

# Start socat for master and slaves
if [ -n "$RS485_MASTER_REMOTE_IP" ] && [ -n "$RS485_MASTER_REMOTE_PORT" ]; then
    start_socat "$RS485_MASTER_REMOTE_IP" "$RS485_MASTER_REMOTE_PORT" "/tmp/vcom0" || {
        echo "Failed to start socat for master"
        exit 1
    }
fi

if [ -n "$RS485_SLAVES_REMOTE_IP" ] && [ -n "$RS485_SLAVES_REMOTE_PORT" ]; then
    start_socat "$RS485_SLAVES_REMOTE_IP" "$RS485_SLAVES_REMOTE_PORT" "/tmp/vcom1" || {
        echo "Failed to start socat for slaves"
        exit 1
    }
fi

echo "Starting the script"

# Run the Python script in the background
python fetch_bms_data.py > /proc/1/fd/1 2> /proc/1/fd/2 &

# Wait for any process to exit
wait $!
