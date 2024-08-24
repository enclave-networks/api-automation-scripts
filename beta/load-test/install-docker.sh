#!/bin/bash

# Update package list and install prerequisites
sudo apt update

# Install packages to allow apt to use a repository over HTTPS
sudo apt-get install -y ca-certificates curl gnupg dnstop

# Add Docker’s official GPG key
sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update the package list again
sudo apt update

# Install Docker Engine, Docker CLI, containerd, Docker Compose plugin, and Docker Buildx plugin
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable Docker to start on boot
sudo systemctl enable docker

# Start Docker service
sudo systemctl start docker

# Verify installation
docker --version
docker compose version

# Install netdata
wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh && sh /tmp/netdata-kickstart.sh

# Install encalve
curl -fsSL https://packages.enclave.io/apt/enclave.stable.gpg  | sudo gpg --dearmor -o /usr/share/keyrings/enclave.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/enclave.gpg] https://packages.enclave.io/apt stable main" | \
  sudo tee /etc/apt/sources.list.d/enclave.stable.list

sudo apt update && sudo apt install enclave