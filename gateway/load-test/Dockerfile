FROM enclavenetworks/enclave

# Install speedtest-cli if it's not included in the base image
RUN apt-get update && apt-get install -y speedtest-cli dnsutils curl

# Copy the script into the container
COPY hosts.txt .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

# Set the script as the default command
ENTRYPOINT  ["entrypoint.sh"]