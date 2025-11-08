# Conditional DNS Configuration for macOS

A simple shell script to configure conditional DNS resolvers on macOS for site-to-site VPNs and split DNS environments.

## Overview

This script automates the configuration of domain-specific DNS resolvers on macOS by creating resolver configuration files in `/etc/resolver/`. This is particularly useful when you need different DNS servers for specific domains, such as when connected to a VPN or accessing internal corporate networks.

## Features

- ✅ Configure unlimited domain-specific DNS resolvers
- ✅ Support for multiple nameservers per domain
- ✅ Automatic DNS resolution testing
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
git clone https://github.com/yourusername/conditional-dns-macos.git
cd conditional-dns-macos
```

2. Make the script executable:
```bash
chmod +x Add-Conditional-DNS.sh
```

## Configuration

Edit the `Add-Conditional-DNS.sh` script and modify the **CONFIGURATION SECTION** to add your domains:

```bash
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
```

### Configuration Parameters

For each domain configuration, you need to specify:

- **DOMAIN**: The domain name for which you want to configure conditional DNS
- **NAMESERVERS**: Array of DNS server IP addresses (one or more)
- **TEST_HOST**: A hostname within the domain to verify DNS resolution is working
- **PING_HOST**: (Optional) A hostname to ping for connectivity verification. Set to `""` to skip.

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

[INFO] Configuring DNS for domain: example.com
[SUCCESS] Created resolver configuration: /etc/resolver/example.com
[INFO] Testing DNS resolution for server.example.com...
[SUCCESS] DNS resolution successful for server.example.com
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

3. Verify which DNS server is being used:
```bash
dig hostname.your.domain
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

### Site-to-Site VPN
Configure internal domain resolution for corporate networks accessed via VPN:
```bash
DOMAINS[0]="corp.internal"
NAMESERVERS_0=("10.0.1.10" "10.0.1.11")
TEST_HOST_0="dc01.corp.internal"
PING_HOST_0="gateway.corp.internal"
```

### Development Environment
Route development domain queries to local DNS:
```bash
DOMAINS[0]="dev.local"
NAMESERVERS_0=("192.168.1.100")
TEST_HOST_0="api.dev.local"
PING_HOST_0=""
```

### Multiple Data Centers
Configure DNS for different geographic locations:
```bash
DOMAINS[0]="us-east.company.com"
NAMESERVERS_0=("10.1.1.1" "10.1.1.2")
TEST_HOST_0="db.us-east.company.com"
PING_HOST_0="router.us-east.company.com"

DOMAINS[1]="eu-west.company.com"
NAMESERVERS_1=("10.2.1.1" "10.2.1.2")
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
