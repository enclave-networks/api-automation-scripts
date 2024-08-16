FROM enclavenetworks/enclave

# Install speedtest-cli if it's not included in the base image
RUN apt-get update && apt-get install -y speedtest-cli

# Copy the script into the container
COPY run_speedtest.sh .
RUN chmod +x run_speedtest.sh

# Set the script as the default command
ENTRYPOINT  ["run_speedtest.sh"]