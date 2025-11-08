#!/bin/bash

################################################################################
# Conditional DNS Configuration Script for macOS
#
# This script configures conditional DNS resolvers for specific domains on macOS
# by creating resolver configuration files in /etc/resolver/
#
# Additionally, it configures static routes to bypass VPN default routes, ensuring
# that specified networks are routed through the local gateway instead of through
# VPN tunnels. This is essential for site-to-site VPN configurations.
#
# Usage: sudo ./Add-Conditional-DNS.sh
#
# Author: kent@bci.com
# License: MIT
# Repository: https://github.com/bci/Conditional_DNS_macOS
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

################################################################################
# CONFIGURATION SECTION
#
# Define your domains below. Each domain configuration should include:
#   - DOMAIN: The domain name to configure conditional DNS for
#   - NAMESERVERS: Array of DNS server IP addresses (one or more)
#   - NETWORKS: Array of network routes in CIDR notation (e.g., "172.16.0.0/12")
#               These networks will be routed via LOCAL_ROUTER_IP to bypass VPN
#   - TEST_HOST: A hostname within the domain to test DNS resolution
#   - PING_HOST: (Optional) A hostname to ping for connectivity verification
#
# Static routes are added BEFORE conditional DNS to ensure proper network routing.
################################################################################

# Local router IP for static routes
LOCAL_ROUTER_IP="192.168.42.1"

# Domain Configuration 1
DOMAINS[0]="example.com"
NAMESERVERS_0=("192.168.1.1" "192.168.1.2") # shellcheck disable=SC2034
NETWORKS_0=("192.168.1.0/24") # shellcheck disable=SC2034
TEST_HOST_0="server.example.com" # shellcheck disable=SC2034
PING_HOST_0="gateway.example.com"  # Leave empty "" to skip ping test # shellcheck disable=SC2034

# Domain Configuration 2
DOMAINS[1]="internal.local"
NAMESERVERS_1=("10.0.0.1") # shellcheck disable=SC2034
NETWORKS_1=("10.0.0.0/8") # shellcheck disable=SC2034
TEST_HOST_1="dc01.internal.local" # shellcheck disable=SC2034
PING_HOST_1=""  # No ping test for this domain # shellcheck disable=SC2034

# Domain Configuration 3
DOMAINS[2]="vpn.corp"
NAMESERVERS_2=("172.16.0.10" "172.16.0.11" "172.16.0.12") # shellcheck disable=SC2034
NETWORKS_2=("172.16.0.0/12") # shellcheck disable=SC2034
TEST_HOST_2="fileserver.vpn.corp" # shellcheck disable=SC2034
PING_HOST_2="router.vpn.corp" # shellcheck disable=SC2034

################################################################################
# END OF CONFIGURATION SECTION
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Create /etc/resolver directory if it doesn't exist
create_resolver_directory() {
    if [[ ! -d /etc/resolver ]]; then
        print_info "Creating /etc/resolver directory..."
        mkdir -p /etc/resolver
        print_success "Directory created"
    else
        print_info "/etc/resolver directory already exists"
    fi
}

# Add static routes for a domain
add_static_routes() {
    local domain=$1
    local networks_var=$2

    # Get networks array using indirect expansion
    # shellcheck disable=SC2154
    eval "local networks=(); networks=(\"\${${networks_var}[@]}\")"

    if [[ ${#networks[@]} -eq 0 ]]; then
        print_info "No static routes configured for domain: ${domain}"
        return
    fi

    print_info "Adding static routes for domain: ${domain}"

    # Get the primary network service (usually "Ethernet" or "Wi-Fi")
    local network_service
    network_service=$(networksetup -listallnetworkservices | grep -E "(Ethernet|Wi-Fi)" | head -1)

    if [[ -z "$network_service" ]]; then
        print_warning "Could not determine network service for static routes"
        return
    fi

    print_info "Using network service: ${network_service}"

    # Get existing routes to preserve them
    local existing_routes
    existing_routes=$(networksetup -getadditionalroutes "${network_service}" 2>/dev/null | grep -v "There are no additional IPv4 routes" || true)
    
    # Build complete route arguments (existing + new, deduplicated)
    local all_route_args=""
    
    # First, add all existing routes (convert multiline to space-separated)
    if [[ -n "$existing_routes" ]]; then
        all_route_args=$(echo "$existing_routes" | tr '\n' ' ' | sed 's/ $//')
    fi
    
    # Then add new routes only if they don't already exist
    for network in "${networks[@]}"; do
        # Parse CIDR notation (e.g., "172.16.0.0/12")
        local network_part
        network_part=$(echo "$network" | cut -d'/' -f1)
        local cidr
        cidr=$(echo "$network" | cut -d'/' -f2)

        # Convert CIDR to netmask
        local netmask
        netmask=$(cidr_to_netmask "$cidr")

        # Check if this route already exists
        local route_signature="${network_part} ${netmask} ${LOCAL_ROUTER_IP}"
        if [[ "$all_route_args" == *"$route_signature"* ]]; then
            print_info "Route already exists: ${network_part}/${cidr} via ${LOCAL_ROUTER_IP} (skipping)"
        else
            all_route_args="${all_route_args} ${route_signature}"
            print_info "Adding route: ${network_part}/${cidr} via ${LOCAL_ROUTER_IP}"
        fi
    done

    # Set all routes (existing + new, deduplicated)
    # Build command as an array to avoid eval issues with IP addresses
    local cmd=(networksetup -setadditionalroutes "${network_service}")
    if [[ -n "$all_route_args" ]]; then
        # Split all_route_args into array elements
        read -r -a route_array <<< "$all_route_args"
        cmd+=("${route_array[@]}")
    fi
    
    if "${cmd[@]}"; then
        print_success "Static routes added successfully"
    else
        print_warning "Failed to add some static routes"
    fi
}

# Convert CIDR notation to netmask
cidr_to_netmask() {
    local cidr=$1
    local mask=$((0xFFFFFFFF << (32 - cidr)))
    printf "%d.%d.%d.%d\n" \
        $(( (mask >> 24) & 0xFF )) \
        $(( (mask >> 16) & 0xFF )) \
        $(( (mask >> 8) & 0xFF )) \
        $(( mask & 0xFF ))
}

# Configure DNS for a single domain
configure_domain() {
    local domain=$1
    local nameservers_var=$2
    local test_host=$3
    local ping_host=$4

    print_info "Configuring DNS for domain: ${domain}"

    # Create resolver configuration file
    local resolver_file="/etc/resolver/${domain}"

    # Get nameservers array using indirect expansion
    # shellcheck disable=SC2154
    eval "local nameservers=(); nameservers=(\"\${${nameservers_var}[@]}\")"

    # Write nameservers
    {
        for ns in "${nameservers[@]}"; do
            echo "nameserver ${ns}"
        done
        echo "domain ${domain}"
    } > "${resolver_file}"

    print_success "Created resolver configuration: ${resolver_file}"

    # Test DNS resolution
    print_info "Testing DNS resolution for ${test_host}..."
    dns_output=$(dscacheutil -q host -a name "${test_host}" 2>/dev/null)
    if [[ $? -eq 0 ]] && echo "$dns_output" | grep -q "ip_address:"; then
        # Extract IP addresses from dscacheutil output
        ip_addresses=$(echo "$dns_output" | grep "ip_address:" | cut -d: -f2 | tr -d ' ' | tr '\n' ' ' | sed 's/ $//')
        if [[ -n "$ip_addresses" ]]; then
            print_success "DNS resolution successful for ${test_host} -> ${ip_addresses}"
        else
            print_warning "DNS resolution failed for ${test_host} (no IP addresses found)"
        fi
    else
        print_warning "DNS resolution failed for ${test_host} (this may be expected if the host doesn't exist yet)"
    fi

    # Ping test (if specified)
    if [[ -n "${ping_host}" ]]; then
        print_info "Testing connectivity to ${ping_host}..."
        if timeout 10 ping -c 2 "${ping_host}" > /dev/null 2>&1; then
            print_success "Ping successful to ${ping_host}"
        else
            print_warning "Ping failed to ${ping_host} (host may be down or unreachable)"
        fi
    fi

    echo ""
}

# Show all static routes on the system
show_static_routes() {
    print_info "Current static routes on the system:"
    netstat -nr | grep "UGS" | while read -r line; do
        echo "  $line"
    done
    
    echo ""
    print_info "Additional routes configured via networksetup:"
    # Get the primary network service
    local network_service
    network_service=$(networksetup -listallnetworkservices | grep -E "(Ethernet|Wi-Fi)" | head -1)
    if [[ -n "$network_service" ]]; then
        networksetup -getadditionalroutes "${network_service}" 2>/dev/null | while read -r line; do
            echo "  $line"
        done
    else
        echo "  Unable to determine network service"
    fi
}

# Main function
main() {
    print_info "Starting Conditional DNS Configuration"
    echo ""

    check_root
    create_resolver_directory

    # Process each domain configuration
    local domain_count=${#DOMAINS[@]}
    print_info "Found ${domain_count} domain configuration(s)"
    echo ""

    for i in "${!DOMAINS[@]}"; do
        local domain="${DOMAINS[$i]}"
        local nameservers_var="NAMESERVERS_${i}"
        local networks_var="NETWORKS_${i}"
        local test_host_var="TEST_HOST_${i}"
        local ping_host_var="PING_HOST_${i}"

        # Add static routes first
        add_static_routes "${domain}" "${networks_var}"

        # Then configure DNS
        configure_domain \
            "${domain}" \
            "${nameservers_var}" \
            "${!test_host_var}" \
            "${!ping_host_var}"
    done

    print_success "All domain configurations completed!"
    print_info "DNS resolver configurations are stored in /etc/resolver/"
    print_info "Changes take effect immediately. No reboot required."
    
    # Show current static routes
    echo ""
    show_static_routes
}

# Run main function
main