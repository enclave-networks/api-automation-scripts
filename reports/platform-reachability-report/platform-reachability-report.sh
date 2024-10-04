#!/bin/bash

# Define the list of domains with their respective checks
declare -A domains

domains=(
  ["api.enclave.io"]="tcp/443"
  ["install.enclave.io"]="tcp/443"
  ["discover.enclave.io"]="tcp/443"
  ["relays.enclave.io"]="tcp/443 icmp"
  ["google.com"]="tcp/443 icmp"
  ["management.azure.com"]="tcp/443 icmp"
  ["go.microsoft.com"]="tcp/443 icmp"
)

# Check if required commands are installed
for cmd in dig ping timeout; do
  if ! command -v $cmd &> /dev/null; then
    echo "Error: $cmd command not found. Please install it to proceed."
    exit 1
  fi
done

# Function to resolve DNS for both IPv4 and IPv6, including full CNAME resolution to IP addresses
resolve_dns() {
  local domain=$1
  local addresses=""
  local cname=$domain
  
  # Keep resolving CNAMEs until we reach the final A or AAAA records
  while :; do
    local new_cname=$(dig +short CNAME $cname)
    if [[ -z "$new_cname" ]]; then
      break
    fi
    cname=$new_cname
  done

  # Resolve A and AAAA records for the final resolved domain
  local ipv4_addresses=$(dig +short A $cname)
  local ipv6_addresses=$(dig +short AAAA $cname)
  addresses+="$ipv4_addresses $ipv6_addresses"

  if [[ -z "$addresses" || "$addresses" == " " ]]; then
    echo "No addresses found for $domain"
  else
    echo "$addresses"
  fi
}

# Function to test ICMP ping
test_icmp_ping() {
  local address=$1
  local start_time=$(date +%s%3N)
  ping -c 1 -W 1 $address &> /dev/null
  local end_time=$(date +%s%3N)
  local elapsed_time=$((end_time - start_time))
  if [ $? -eq 0 ]; then
    echo "ok ${elapsed_time}ms"
  else
    echo "failure (timeout waiting for a response)"
  fi
}

# Function to test TCP port
test_tcp_port() {
  local address=$1
  local port=$2
  local start_time=$(date +%s%3N)
  timeout 1 bash -c "</dev/tcp/$address/$port" &> /dev/null
  local end_time=$(date +%s%3N)
  local elapsed_time=$((end_time - start_time))
  if [ $? -eq 0 ]; then
    echo "ok ${elapsed_time}ms"
  else
    echo "failure (no response)"
  fi
}

# Function to format output
format_output() {
  local protocol=$1
  local address=$2
  local status=$3
  local total_length=50
  local line="$protocol/$address"
  local dots=$(printf '.%.0s' $(seq 1 $((total_length - ${#line} - 4))))
  echo " $line $dots [$status]"
}

# Function to display nameserver information
show_nameservers() {
  echo -e "\nNameservers\n"
  echo -e "AddressFamily	Nameserver"
  echo -e "-------------	----------"

  if command -v nmcli &> /dev/null; then
    if nmcli dev show &> /dev/null; then
      nmcli dev show | awk '/DNS/ {print $2}' | while read -r ns; do
        echo -e "IPv4	$ns"
      done
      return
    fi
  fi

  if command -v resolvectl &> /dev/null; then
    if resolvectl status &> /dev/null; then
      resolvectl status | awk '/DNS Servers/ {print $3}' | while read -r ns; do
        echo -e "IPv4	$ns"
      done
      return
    fi
  fi

  if [ -f /etc/resolv.conf ]; then
    if grep "^nameserver" /etc/resolv.conf &> /dev/null; then
      grep "^nameserver" /etc/resolv.conf | awk '{print $2}' | while read -r ns; do
        echo -e "IPv4	$ns\n"
      done
      return
    fi
  fi

  echo "Nameserver information not available (requires nmcli, resolvectl, or /etc/resolv.conf)\n"
}

# Main script logic
show_nameservers

for domain in "${!domains[@]}"; do
  echo "$domain"
  addresses=$(resolve_dns $domain)
  if [[ "$addresses" == "No addresses found for $domain" ]]; then
    format_output "dns" "$domain" "failure (could not resolve)"
    continue
  fi
  for address in $addresses; do
    for check in ${domains[$domain]}; do
      if [[ $check == "icmp" ]]; then
        status=$(test_icmp_ping $address)
        format_output "icmp" "$address" "$status"
      elif [[ $check == tcp/* ]]; then
        port=$(echo $check | cut -d'/' -f2)
        status=$(test_tcp_port $address $port)
        format_output "tcp" "$address:$port" "$status"
      fi
    done
  done
done