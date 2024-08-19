#!/bin/bash

# URL of the file containing the list of hostnames
HOSTNAMES_URL="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"

# Path where the hostname file will be downloaded
HOSTNAMES_FILE="./hosts.txt"

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

# Function to download and load hostnames from a URL
load_hostnames() {
    echo "Downloading hostnames file from $HOSTNAMES_URL..."
    if curl -s -o "$HOSTNAMES_FILE" "$HOSTNAMES_URL"; then
        if [[ -f "$HOSTNAMES_FILE" ]]; then
            # Extract hostnames from the file, ignoring comment lines and extracting only the domain names
            HOSTNAMES=($(awk '/^[0-9]/ {print $2}' "$HOSTNAMES_FILE"))
            echo "Loaded ${#HOSTNAMES[@]} hostnames from $HOSTNAMES_FILE."
        else
            echo "Error: Hostnames file not found after download."
            exit 1
        fi
    else
        echo "Error: Failed to download hostnames file from $HOSTNAMES_URL"
        exit 1
    fi
}

# Function to run DNS queries
run_dns_queries() {
    while true; do
        # Pick a random hostname from the list
        hostname=${HOSTNAMES[$RANDOM % ${#HOSTNAMES[@]}]}
        
        # Perform a DNS query using dig
        dig $hostname @8.8.8.8  # > /dev/null 2>&1

        # Small random delay between queries to avoid flooding
        sleep $((RANDOM % 2 + 1))
        
        echo "Queried DNS for $hostname."
    done
}

load_hostnames

run_dns_queries &

# Initial delay before the first run
initial_delay=$((RANDOM % MAX_DELAY + 1))
echo "Initial wait time: $initial_delay seconds."
sleep $initial_delay

# Start the speedtest loop
run_speedtest