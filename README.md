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
- SSH hardening with key-only authentication
- Firewall configuration (UFW/firewalld)
- Fail2ban intrusion prevention
- SELinux configuration (RHEL-based)
- Kernel hardening via sysctl
- Automatic security updates

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
| 4 | Firewall | UFW (Debian) / firewalld (RHEL) |
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
