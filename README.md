# Server Setup & Hardening

Bulletproof server hardening scripts for Linux distributions. Interactive, step-by-step configuration with beautiful CLI interface.

## Supported Distributions

- **Ubuntu** 20.04, 22.04, 24.04
- **Debian** 11, 12
- **RHEL/Rocky/Alma** 8, 9
- **CentOS Stream** 8, 9

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/packalyst/BootShield/main/setup.sh | sudo bash
```

Or download and run manually:

```bash
wget -O setup.sh https://raw.githubusercontent.com/packalyst/BootShield/main/setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

The bootstrap script automatically detects your distribution and downloads the appropriate hardening script.

## Features

### Security Hardening
- SSH hardening with key-only authentication (modern ciphers, forwarding off)
- **nftables firewall** — default-drop, with optional VPN-only SSH and
  Cloudflare-only web (auto-refreshed IP set); Docker-aware via `DOCKER-USER`
- **VPN** — WireGuard *server* (admins dial in), WireGuard *client* (this box
  dials out to a server you run, from a supplied config or a generated keypair),
  or *Tailscale* (join a tailnet — Tailscale SaaS or a self-hosted Headscale via
  `TS_LOGIN_SERVER`); any mode can back VPN-only SSH
- Fail2ban intrusion prevention
- SELinux configuration (RHEL-based)
- Kernel hardening via sysctl
- Automatic security updates
- **Unattended mode** — drive the whole run from a `KEY=VALUE` config file

### System Management
- User management with sudo/wheel access
- Custom MOTD with system stats
- System cleanup (bloatware removal)
- Disk management (swap, tmp mounting)
- Security auditing tools (lynis, rkhunter)

### Software Installation
- Essential development tools
- System utilities (htop, tmux, etc.)
- Docker CE
- Node.js LTS
- Go language

## Modules

| # | Module | Description |
|---|--------|-------------|
| 1 | Pre-flight Checks | System detection and validation |
| 2 | User Management | Create admin user, configure sudo |
| 3 | SSH Hardening | Secure SSH configuration |
| 4 | Firewall | nftables: default-drop, VPN/Cloudflare source restrictions, Docker-aware |
| — | VPN (WireGuard / Tailscale) | Optional; WG server, WG client, or Tailscale — backs VPN-only SSH |
| 5 | Fail2ban | Brute-force protection |
| 6 | SELinux | Security policy (RHEL only) |
| 7 | System Cleanup | Remove bloatware and telemetry |
| 8 | Software | Install common tools |
| 9 | Kernel Hardening | Secure sysctl settings |
| 10 | Auto Updates | Automatic security updates |
| 11 | Additional Security | Optional security tools |
| 12 | Disk Management | Swap and mount options |
| 13 | System Update | Update all packages |
| 14 | Post Setup | Summary and recommendations |

## Usage Modes

### Interactive Mode (Recommended)
Run the script and follow the prompts. Each module asks for confirmation before making changes.

### Quick Setup
Select option `[1]` from the main menu to run all modules interactively in sequence.

### Individual Modules
Select specific modules from the main menu to run only what you need.

### Unattended Mode
Drive the entire run from a config file — no prompts, reproducible across
servers, and safe to run over SSH (no TTY needed):

```bash
cp config.example.conf server.conf   # edit answers (user, SSH key, firewall, VPN…)
sudo ./distros/ubuntu.sh --config server.conf
```

Every menu answer maps to a `KEY=VALUE` in the file; see `config.example.conf`
for the full list and defaults. Omitted keys fall back to built-in defaults.
`--unattended` alone runs with defaults and no config file.

**Firewall model.** The nftables ruleset is default-drop on input. SSH is open
to all or restricted to the WireGuard subnet (`SSH_ACCESS=vpn-only`, with a
guard that refuses to lock SSH until `wg0` is up). Web (80/443) is open to all
or to Cloudflare ranges only (`WEB_ALLOW_FROM=cloudflare`), kept current by a
weekly `cf-refresh` timer. Docker publishes ports through its own `DOCKER-USER`
chain, so container-published 80/443 is restricted there in parallel.

## Directory Structure

```
server-setup/
├── setup.sh          # Bootstrap script (detects distro)
├── distros/
│   ├── ubuntu.sh     # Ubuntu hardening script
│   ├── debian.sh     # Debian hardening script
│   └── rhel.sh       # RHEL/Rocky/Alma hardening script
└── README.md
```

## Safety Features

- All changes require confirmation
- Backups created before modifications
- SSH lockout protection
- Detailed logging to `/var/log/server-setup/`
- Dry-run awareness

## Post-Installation

After running the script:

1. Test SSH access in a new terminal before disconnecting
2. Review firewall rules
3. Run security audit: `lynis audit system`
4. Check fail2ban status: `fail2ban-client status`

## License

MIT
