# Conditional DNS Configuration for macOS

A comprehensive shell script to configure conditional DNS resolvers and static routes on macOS for site-to-site VPNs, split DNS environments, and network segmentation.

## Overview

This script automates the configuration of domain-specific DNS resolvers on macOS by creating resolver configuration files in `/etc/resolver/`. Additionally, it can configure static routes to bypass VPN default routes, ensuring that specific networks are routed through your local gateway instead of through VPN tunnels.

This is particularly useful when you need different DNS servers for specific domains, or when you want certain networks to bypass VPN routing, such as when connected to a VPN or accessing internal corporate networks.

## Features

- ✅ Configure unlimited domain-specific DNS resolvers
- ✅ Support for multiple nameservers per domain
- ✅ **Static route configuration to bypass VPN default routes**
- ✅ Support for CIDR notation network ranges
- ✅ Automatic DNS resolution testing using macOS system resolver (`dscacheutil`)
- ✅ Optional connectivity verification via ping
- ✅ Color-coded output for easy monitoring
- ✅ Error handling and validation
- ✅ No reboot required - changes take effect immediately

## Requirements

- macOS (tested on macOS 10.12+)
- Root/sudo access
- Bash shell

## Installation

1. Clone this repository:
```bash
git clone https://github.com/bci/Conditional_DNS_macOS.git
cd conditional-dns-macos
```

2. Make the script executable:
```bash
chmod +x Add-Conditional-DNS.sh
```

## Configuration

Edit the `Add-Conditional-DNS.sh` script and modify the **CONFIGURATION SECTION** to add your domains:

```bash
# Local router IP for static routes (bypasses VPN default routes)
LOCAL_ROUTER_IP="192.168.42.1"

# Domain Configuration 1
DOMAINS[0]="example.com"
NAMESERVERS_0=("192.168.1.1" "192.168.1.2")
NETWORKS_0=("192.168.1.0/24" "10.0.0.0/8")  # Networks to route via local gateway
TEST_HOST_0="server.example.com"
PING_HOST_0="gateway.example.com"  # Leave empty "" to skip ping test

# Domain Configuration 2
DOMAINS[1]="internal.local"
NAMESERVERS_1=("10.0.0.1")
NETWORKS_1=()  # Empty array = no static routes for this domain
TEST_HOST_1="dc01.internal.local"
PING_HOST_1=""  # No ping test for this domain
```

### Configuration Parameters

For each domain configuration, you need to specify:

- **DOMAIN**: The domain name for which you want to configure conditional DNS
- **NAMESERVERS**: Array of DNS server IP addresses (one or more)
- **NETWORKS**: Array of network routes in CIDR notation (e.g., "172.16.0.0/12") to route via local gateway instead of VPN
- **TEST_HOST**: A hostname within the domain to verify DNS resolution is working
- **PING_HOST**: (Optional) A hostname to ping for connectivity verification. Set to `""` to skip.

### LOCAL_ROUTER_IP

The `LOCAL_ROUTER_IP` specifies your local network gateway. Static routes for configured networks will be directed through this gateway, bypassing any VPN default routes that might otherwise capture all traffic.

### Adding More Domains

To add additional domains, follow this pattern:

```bash
DOMAINS[N]="your.domain"
NAMESERVERS_N=("dns1" "dns2" "dns3")
TEST_HOST_N="host.your.domain"
PING_HOST_N="ping.your.domain"
```

Where `N` is the next sequential number (0, 1, 2, 3, etc.).

## Usage

Run the script with sudo:

```bash
sudo ./Add-Conditional-DNS.sh
```

### Example Output

```
[INFO] Starting Conditional DNS Configuration

[INFO] Creating /etc/resolver directory...
[SUCCESS] Directory created
[INFO] Found 3 domain configuration(s)

[INFO] Adding static routes for domain: example.com
[INFO] Adding route: 192.168.1.0/24 via 192.168.42.1
[INFO] Adding route: 10.0.0.0/8 via 192.168.42.1
[INFO] Using network service: Ethernet
[SUCCESS] Static routes added successfully

[INFO] Configuring DNS for domain: example.com
[SUCCESS] Created resolver configuration: /etc/resolver/example.com
[INFO] Testing DNS resolution for server.example.com...
[SUCCESS] DNS resolution successful for server.example.com -> 192.168.1.100
[INFO] Testing connectivity to gateway.example.com...
[SUCCESS] Ping successful to gateway.example.com

[SUCCESS] All domain configurations completed!
[INFO] DNS resolver configurations are stored in /etc/resolver/
[INFO] Changes take effect immediately. No reboot required.
```

## How It Works

macOS supports domain-specific DNS resolution through configuration files in `/etc/resolver/`. Each file in this directory corresponds to a domain and can specify nameservers that should be used for that domain.

When you query a hostname:
1. macOS checks if there's a matching resolver configuration in `/etc/resolver/`
2. If found, it uses the specified nameservers for that domain
3. If not found, it falls back to the system-wide DNS settings

This allows you to route DNS queries for specific domains (like `internal.corp`) to internal DNS servers while using your regular DNS for everything else.

## Static Routes and VPN Bypass

When connected to a VPN, all network traffic typically routes through the VPN tunnel by default. However, for site-to-site VPN configurations, you often want specific networks to bypass the VPN and route through your local gateway instead.

The script configures static routes using macOS `networksetup -setadditionalroutes`, which adds persistent routes that take precedence over VPN default routes. This ensures that:

- **Split Tunneling**: Only specific networks route through the VPN, while others use local internet
- **Site-to-Site Access**: Internal networks are accessible without VPN overhead
- **Performance**: Local network traffic doesn't incur VPN latency
- **Security**: Sensitive internal traffic stays on local networks
- **Route Accumulation**: Multiple domain configurations properly accumulate routes without overwriting existing ones

### Route Priority

1. **Static Routes** (highest priority) - Direct traffic for configured networks through local gateway
2. **VPN Routes** - Default route through VPN tunnel for unconfigured traffic
3. **System Routes** - Fallback to system routing table

### Example Scenario

```
Without static routes:
All traffic → VPN → Remote Network

With static routes (172.16.0.0/12 → local gateway):
172.16.0.0/12 traffic → Local Gateway → Site-to-Site VPN
All other traffic → VPN → Remote Network
```

## Verifying Configuration

After running the script, you can verify the configuration:

1. Check the resolver files:
```bash
ls -la /etc/resolver/
cat /etc/resolver/your.domain
```

2. Test DNS resolution:
```bash
scutil --dns
nslookup hostname.your.domain
```

3. Verify which DNS server is being used (note: `dig` uses system default DNS, not conditional resolvers):
```bash
dscacheutil -q host -a name hostname.your.domain
nslookup hostname.your.domain
```

## Removing Configuration

To remove a domain-specific DNS configuration:

```bash
sudo rm /etc/resolver/your.domain
```

To remove all configurations created by this script:

```bash
sudo rm -rf /etc/resolver/*
```

## Common Use Cases

### Site-to-Site VPN with Route Bypass
Configure internal domain resolution and bypass VPN for local networks:
```bash
LOCAL_ROUTER_IP="192.168.42.1"  # Your local gateway

DOMAINS[0]="corp.internal"
NAMESERVERS_0=("10.0.1.10" "10.0.1.11")
NETWORKS_0=("10.0.0.0/8" "172.16.0.0/12")  # Bypass VPN for these networks
TEST_HOST_0="dc01.corp.internal"
PING_HOST_0="gateway.corp.internal"
```

### Development Environment
Route development domain queries to local DNS without VPN interference:
```bash
DOMAINS[0]="dev.local"
NAMESERVERS_0=("192.168.1.100")
NETWORKS_0=("192.168.1.0/24")  # Keep dev network local
TEST_HOST_0="api.dev.local"
PING_HOST_0=""
```

### Multiple Data Centers with Network Segmentation
Configure DNS and routing for different geographic locations:
```bash
DOMAINS[0]="us-east.company.com"
NAMESERVERS_0=("10.1.1.1" "10.1.1.2")
NETWORKS_0=("10.1.0.0/16")  # US East networks bypass VPN
TEST_HOST_0="db.us-east.company.com"
PING_HOST_0="router.us-east.company.com"

DOMAINS[1]="eu-west.company.com"
NAMESERVERS_1=("10.2.1.1" "10.2.1.2")
NETWORKS_1=("10.2.0.0/16")  # EU West networks bypass VPN
TEST_HOST_1="db.eu-west.company.com"
PING_HOST_1="router.eu-west.company.com"
```

## Troubleshooting

### DNS Resolution Not Working

1. Verify the resolver file exists and has correct permissions:
```bash
ls -la /etc/resolver/
```

2. Check the DNS configuration:
```bash
scutil --dns
```

3. Flush DNS cache:
```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

4. Test DNS resolution using the system's conditional resolver:
```bash
dscacheutil -q host -a name hostname.your.domain
```

### Permission Denied

Make sure you're running the script with `sudo`:
```bash
sudo ./Add-Conditional-DNS.sh
```

### Network Unreachable

- Ensure your VPN is connected (if required)
- Verify the DNS server IPs are correct
- Check that the DNS servers are accessible from your network

## Security Considerations

- This script requires root access to modify system DNS settings
- Review the configuration before running to ensure nameserver IPs are correct
- Be cautious when adding DNS servers you don't control
- Consider the security implications of split DNS in your environment

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## References

- [macOS Manual Page for resolver(5)](https://www.manpagez.com/man/5/resolver/)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)

## Author

Kent - kent@bci.com

## Acknowledgments

- Thanks to the macOS community for documentation on the `/etc/resolver/` functionality
- Inspired by the need for better VPN DNS management
