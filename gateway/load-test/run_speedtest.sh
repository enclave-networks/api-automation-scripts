#!/bin/bash

# Path to the Enclave executable
ENCLAVE_PATH="./enclave"

# Check if the Enclave executable exists
if [[ -x "$ENCLAVE_PATH" ]]; then
    echo "Starting Enclave..."
    $ENCLAVE_PATH run &
else
    echo "Error: Enclave not found at $ENCLAVE_PATH"
fi

# Set the maximum delay in seconds (e.g., 3600 seconds for 1 hour)
MAX_DELAY=3600

# Function to run the speedtest and then sleep for a random duration
run_speedtest() {
    while true; do
        #speedtest-cli > /var/log/enclave/speedtest_$(date +%s).log
        speedtest-cli

        # Generate a random delay between 1 and MAX_DELAY seconds
        next_delay=$((RANDOM % MAX_DELAY + 1))
        echo "Waiting for $next_delay seconds before running the next speed test."
        sleep $next_delay
    done
}

# Initial delay before the first run
initial_delay=$((RANDOM % MAX_DELAY + 1))
echo "Initial wait time: $initial_delay seconds."
sleep $initial_delay

# Start the speedtest loop
run_speedtest