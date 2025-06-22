# on1OS - Hardened Linux Distribution

[![GitHub](https://img.shields.io/badge/GitHub-on1OS-blue?logo=github)](https://github.com/John0n1/on1OS)
[![License](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)
[![on1OS Build CI](https://github.com/John0n1/on1OS/actions/workflows/build.yml/badge.svg)](https://github.com/John0n1/on1OS/actions/workflows/build.yml)

A security-focused, minimalist Linux distribution built with modern hardening techniques and TPM2/LUKS2 support.

**Repository:** https://github.com/John0n1/on1OS

## Architecture Overview

| Component | Choice | Reason |
|-----------|--------|---------|
| Bootloader | GRUB 2 | Secure Boot, TPM2, LUKS, modular, industry standard |
| Kernel | linux-hardened | Extra hardening beyond mainline; upstream compatible |
| Init | systemd | Most secure + modern supervision/init architecture |
| Initramfs | dracut | Modular, TPM2/LUKS2 support, systemd-native |
| Rootfs | Buildroot + musl | Auditable, lightweight, hardened, reproducible |
| Shell | Bash (musl-linked) | Flexible, POSIX-compliant, secure when hardened |
| Mount tool | util-linux mount | Full-featured, stable, systemd-compatible |

## Build Process

1. **Environment Setup** - Prepare build dependencies
2. **Kernel Build** - Compile hardened kernel with security features
3. **Rootfs Creation** - Build minimal userspace with Buildroot
4. **Initramfs Generation** - Create dracut-based initramfs
5. **Bootloader Setup** - Configure GRUB2 with Secure Boot
6. **ISO Assembly** - Create bootable installation media
7. **Security Hardening** - Apply additional security configurations

## Security Features

- **Kernel Hardening**: KASLR, SMEP, SMAP, Control Flow Integrity
- **Memory Protection**: ASLR, DEP, Stack canaries, Fortify Source
- **Disk Encryption**: LUKS2 with TPM2 key sealing
- **Secure Boot**: Full UEFI Secure Boot chain validation
- **Minimal Attack Surface**: Only essential components included
- **Reproducible Builds**: Deterministic build process

## Requirements

- Linux build host (Ubuntu 20.04+ or similar)
- 20GB+ free disk space
- 8GB+ RAM
- TPM2 chip (for full security features)
- UEFI system with Secure Boot capability

## Quick Start

```bash
make  # Build complete system
```

See `docs/` directory for detailed build instructions.

## Installation

### Prerequisites

- Linux build host (Ubuntu 20.04+, Fedora 35+, or Arch Linux)
- 20GB+ free disk space
- 8GB+ RAM (16GB+ recommended)
- TPM2 chip (for full security features)
- UEFI system with Secure Boot capability

### Quick Installation

```bash
# Clone the repository
git clone https://github.com/John0n1/on1OS.git
cd on1OS

# Build complete system
make all

```

### Manual Build Process

For a step-by-step build process:

```bash
make setup      # Install dependencies and download sources
make kernel     # Build hardened Linux kernel
make rootfs     # Create minimal root filesystem
make initramfs  # Generate dracut-based initramfs
make bootloader # Build GRUB2 bootloader
make iso        # Assemble final ISO image
```

## Configuration

### Build Configuration

Edit `config/build.conf` to customize:
- Target architecture
- Security features
- Package selection
- Hardware support

### Security Configuration

The distribution includes several security hardening options:
- Kernel hardening (KASLR, SMEP, SMAP, CFI)
- Memory protection (ASLR, DEP, Stack canaries)
- Disk encryption (LUKS2 with TPM2)
- Secure Boot support
- Minimal attack surface

## Development

### Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Building for Development

For development builds with debug symbols:

```bash
make config-dev  # Enable development options
make all-dev     # Build with debug symbols
```

### Testing

Run the test suite:

```bash
make test        # Run all tests
make test-vm     # Test in virtual machine
make test-hw     # Test on real hardware (requires setup)
```

## Documentation

- [Build Guide](docs/BUILD.md) - Detailed build instructions
- [Security Guide](docs/SECURITY.md) - Security features and configuration
- [Installation Guide](docs/INSTALL.md) - Installation and deployment
- [Developer Guide](docs/DEVELOPER.md) - Development and contribution guide
- [FAQ](docs/FAQ.md) - Frequently asked questions

## License

This project is licensed under the GPL-3.0 License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [linux-hardened](https://github.com/anthraxx/linux-hardened) - Hardened Linux kernel
- [Buildroot](https://buildroot.org/) - Embedded Linux build system
- [systemd](https://systemd.io/) - System and service manager
- [dracut-ng](https://github.com/dracut-ng/dracut-ng) - Next generation initramfs
- [GRUB](https://www.gnu.org/software/grub/) - Grand Unified Bootloader

## Support

- GitHub Issues: https://github.com/John0n1/on1OS/issues
- Discussions: https://github.com/John0n1/on1OS/discussions
- Wiki: https://github.com/John0n1/on1OS/wiki

---

**⚠️ Security Notice:** on1OS is designed for security-conscious users. Always verify the integrity of downloaded sources and keep your system updated.
