#!/bin/bash

################################################################################
# Conditional DNS Configuration Script for macOS
#
# This script configures conditional DNS resolvers for specific domains on macOS
# by creating resolver configuration files in /etc/resolver/
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
#   - TEST_HOST: A hostname within the domain to test DNS resolution
#   - PING_HOST: (Optional) A hostname to ping for connectivity verification
#
# Add as many domain configurations as needed following the pattern below.
################################################################################

# Domain Configuration 1
DOMAINS[0]="example.com"
NAMESERVERS_0=("192.168.1.1" "192.168.1.2")
TEST_HOST_0="server.example.com"
PING_HOST_0="gateway.example.com"  # Leave empty "" to skip ping test

# Domain Configuration 2
DOMAINS[1]="internal.local"
NAMESERVERS_1=("10.0.0.1")
TEST_HOST_1="dc01.internal.local"
PING_HOST_1=""  # No ping test for this domain

# Domain Configuration 3
DOMAINS[2]="vpn.corp"
NAMESERVERS_2=("172.16.0.10" "172.16.0.11" "172.16.0.12")
TEST_HOST_2="fileserver.vpn.corp"
PING_HOST_2="router.vpn.corp"

# Add more domain configurations as needed following the same pattern:
# DOMAINS[N]="your.domain"
# NAMESERVERS_N=("dns1" "dns2" "dns3")
# TEST_HOST_N="host.your.domain"
# PING_HOST_N="ping.your.domain"

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

# Configure DNS for a single domain
configure_domain() {
    local domain=$1
    local -n nameservers=$2
    local test_host=$3
    local ping_host=$4
    
    print_info "Configuring DNS for domain: ${domain}"
    
    # Create resolver configuration file
    local resolver_file="/etc/resolver/${domain}"
    
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
    if host "${test_host}" > /dev/null 2>&1; then
        print_success "DNS resolution successful for ${test_host}"
    else
        print_warning "DNS resolution failed for ${test_host} (this may be expected if the host doesn't exist yet)"
    fi
    
    # Ping test (if specified)
    if [[ -n "${ping_host}" ]]; then
        print_info "Testing connectivity to ${ping_host}..."
        if ping -c 2 -t 5 "${ping_host}" > /dev/null 2>&1; then
            print_success "Ping successful to ${ping_host}"
        else
            print_warning "Ping failed to ${ping_host} (host may be down or unreachable)"
        fi
    fi
    
    echo ""
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
        local nameservers_var="NAMESERVERS_${i}[@]"
        local test_host_var="TEST_HOST_${i}"
        local ping_host_var="PING_HOST_${i}"
        
        configure_domain \
            "${domain}" \
            "NAMESERVERS_${i}" \
            "${!test_host_var}" \
            "${!ping_host_var}"
    done
    
    print_success "All domain configurations completed!"
    print_info "DNS resolver configurations are stored in /etc/resolver/"
    print_info "Changes take effect immediately. No reboot required."
}

# Run main function
main