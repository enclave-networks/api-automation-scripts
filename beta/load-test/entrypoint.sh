#!/bin/bash
set -euo pipefail

# Set the maximum delay in seconds between speedtests (e.g., 3600 seconds for 1 hour)
SPEEDTEST_MAX_INTERVAL=-1

# Set the maximum delay in seconds between dns queries (e.g. 600 seconds for 10 minutes)
DNSQUERY_MAX_INTERVAL=-1

# Set the maximum delay in seconds between the script exiting with an error code (e.g. 1800 seconds for 30 minutes)
EXIT_INTERVAL=-1

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Define the path to the hosts.txt file taken from https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
HOSTNAMES_FILE="./hosts.txt"

# Path to the Enclave executable
ENCLAVE_PATH="./enclave"

# Check if the Enclave executable exists
if [[ -x "$ENCLAVE_PATH" ]]; then
    echo "Starting Enclave..."
    $ENCLAVE_PATH run &
else
    echo "Enclave not found at $ENCLAVE_PATH"
fi

# Function to randomly exit with an error code after a delay
run_random_exit() {
    if [ "$EXIT_INTERVAL" -eq -1 ]; then
        echo "EXIT_INTERVAL is set to -1, will not exit the container."
        return 0
    fi

    exit_delay=$((RANDOM % EXIT_INTERVAL + 1))
    echo "Non-zero exit code wait time: $exit_delay seconds."
    sleep $exit_delay
    echo "Exiting with an non-zero code to trigger a container restart."
    exit 1
}

# Function to run the speedtest and then sleep for a random duration
run_speedtest() {
    if [ "$SPEEDTEST_MAX_INTERVAL" -eq -1 ]; then
        echo "SPEEDTEST_MAX_INTERVAL is set to -1, will not run speedtests."
        return 0
    fi

    while true; do
        delay=$((RANDOM % SPEEDTEST_MAX_INTERVAL + 1))
        echo "SpeedTest wait time: $delay seconds."

        sleep $delay # Small random delay between queries to avoid flooding

        #speedtest-cli > /var/log/enclave/speedtest_$(date +%s).log
        speedtest-cli
    done
}

# Function to download and load hostnames from a URL
load_hostnames() {
    echo "Loading hostnames..."

    if [[ -f "$HOSTNAMES_FILE" ]]; then
        # Extract hostnames from the hosts.txt file, ignoring comment lines and extracting only the domain names
        HOSTNAMES=($(awk '/^[0-9]/ {print $2}' "$HOSTNAMES_FILE" | head -n 1000))

        if [[ ${#HOSTNAMES[@]} -gt 0 ]]; then
            echo "Loaded ${#HOSTNAMES[@]} hostnames from $HOSTNAMES_FILE."
        else
            echo "Error: No hostnames found in $HOSTNAMES_FILE."
            exit 1
        fi
    else
        echo "Error: $HOSTNAMES_FILE file not found."
        exit 1
    fi
}

# Function to run DNS queries
run_dns_queries() {
    if [ "$DNSQUERY_MAX_INTERVAL" -eq -1 ]; then
        echo "DNSQUERY_MAX_INTERVAL is set to -1, will not ask dns questions."
        return 0
    fi

    while true; do
        delay=$((RANDOM % DNSQUERY_MAX_INTERVAL + 1))
        echo "DNS query wait time: $delay seconds."

        sleep $delay # Small random delay between queries to avoid flooding

        # Pick a random hostname from the list
        hostname=${HOSTNAMES[$RANDOM % ${#HOSTNAMES[@]}]}

        # Perform a DNS query using dig
        dig $hostname # > /dev/null 2>&1
    done
}

#load_hostnames

run_dns_queries &
run_speedtest &
run_random_exit &

wait