<p align="center">
  <img src="img/logo.png" alt="kalitorify logo" width="360">
</p>

<h3 align="center">
  Transparent Proxy through Tor for Kali Linux & Debian Distributions
</h3>

<p align="center">
  <a href="https://github.com/Tagbirulmohoshin781/kalitorify/commits/main"><img src="https://img.shields.io/badge/version-1.30.0-blue.svg?style=flat-square" alt="Version 1.30.0"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPLv3-green.svg?style=flat-square" alt="License"></a>
  <a href="https://www.kali.org/"><img src="https://img.shields.io/badge/platform-Kali%20Linux%20%7C%20Debian-blueviolet.svg?style=flat-square" alt="Platform"></a>
  <a href="https://www.torproject.org/"><img src="https://img.shields.io/badge/tor-0.4.x%2B-orange.svg?style=flat-square" alt="Tor"></a>
</p>

---

## About kalitorify

**kalitorify** is a security and privacy shell toolkit for [Kali Linux](https://www.kali.org/) and Debian-based systems that configures **iptables** to create a transparent proxy routing all system-wide TCP and DNS traffic through the **Tor Network**.

The program also provides built-in mechanisms to verify Tor status, check active Tor exit nodes (public IP discovery across privacy mirrors), and rotate circuits on-demand.

### Key Capabilities & Enhancements in v1.30.0

- **Dynamic Tor UID Detection**: Automatically discovers `debian-tor`, `tor`, or `_tor` system users without emitting startup errors or breaking non-Debian environments.
- **Fail-Safe Startup Rollback**: Uses signal trapping to atomically revert iptables and restore clearnet DNS if interrupted or if Tor connection fails.
- **Resilient Clearnet Recovery (`--clearnet`)**: Always resets iptables and restores DNS/IPv6 even if the Tor daemon has crashed or was unexpectedly stopped.
- **Localhost Hardening (`data/torrc`)**: Explicitly binds transparent proxy and DNS listeners to `127.0.0.1` preventing LAN-side exposure.
- **Timeout-Protected IP Discovery**: Multi-provider queries with strict connection timeouts preventing hanging on slow circuits.
- **Automated Directory Provisioning**: Self-creates backup directories in `/var/lib/kalitorify/backups`.

---

## Installation

### Prerequisites

Update your system and install the required dependencies:

```bash
sudo apt-get update && sudo apt-get dist-upgrade -y
sudo apt-get install -y tor curl iptables
```

### Clone and Install

```bash
git clone https://github.com/Tagbirulmohoshin781/kalitorify.git
cd kalitorify
sudo make install
```

---

## Usage

> [!IMPORTANT]
> Always run network configuration commands with `sudo`. Disable conflicting third-party VPNs or custom DNS proxies before starting.

### Start Transparent Proxy

Route all system traffic through Tor:

```bash
sudo kalitorify --tor
# or short flag
sudo kalitorify -t
```

### Return to Clearnet

Flush proxy rules and restore default DNS and IPv6:

```bash
sudo kalitorify --clearnet
# or short flag
sudo kalitorify -c
```

### Check Status & Network

Verify if the Tor daemon is running and traffic is routing properly:

```bash
sudo kalitorify --status
# or short flag
sudo kalitorify -s
```

### Display Public IP

Check current public IP address via multi-mirror fallback:

```bash
kalitorify --ipinfo
# or short flag
kalitorify -i
```

### Request New Tor Circuit (Rotate IP)

Request a new Tor exit node circuit:

```bash
sudo kalitorify --restart
# or short flag
sudo kalitorify -r
```

### Commands Reference

| Option | Long Option | Description |
|---|---|---|
| `-h` | `--help` | Show usage information and options menu |
| `-t` | `--tor` | Start transparent proxy routing through Tor |
| `-c` | `--clearnet` | Flush iptables rules and return to clearnet navigation |
| `-s` | `--status` | Check status of Tor service and network connectivity |
| `-i` | `--ipinfo` | Display current public IP address |
| `-r` | `--restart` | Renew Tor circuit and obtain a new exit node IP |
| `-v` | `--version` | Display program version and license information |

---

## Uninstallation

To remove kalitorify from your system:

```bash
cd kalitorify
sudo make uninstall
```

Or manually:

```bash
sudo rm -f /usr/bin/kalitorify
sudo rm -rf /usr/share/kalitorify
sudo rm -rf /usr/share/doc/kalitorify
sudo rm -rf /var/lib/kalitorify
```

---

## Security Considerations

1. **Tor Browser Caution**: Do not run the Tor Browser bundle while transparent proxy is active to avoid [Tor over Tor scenarios](https://gitlab.torproject.org/legacy/trac/-/wikis/doc/TorifyHOWTO#tor-over-tor).
2. **UDP Traffic**: Tor natively routes TCP and handles DNS UDP via DNSPort. Non-DNS UDP traffic is dropped by iptables to prevent leaks.
3. **Hardware Identifiers**: Transparent proxying protects your IP address; it does not change your hardware MAC address or hostname. Change those separately if required for your threat model.
4. **Verifying Leaks**: You can audit traffic with `tcpdump`:
   ```bash
   sudo tcpdump -i eth0 not arp
   ```

---

## Credits & Upstream

- kalitorify is inspired by the KISS philosophy and the Parrot AnonSurf Module of [Parrot OS](https://www.parrotsec.org/).
- Originally created by brainf+ck (2015-2022).
- Maintained and modernized by [Tagbirulmohoshin781](https://github.com/Tagbirulmohoshin781) and contributors.
- "KALI LINUX" is a trademark of Offensive Security.
- "Tor" is a registered trademark of The Tor Project, Inc.

---

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
