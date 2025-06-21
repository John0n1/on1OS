# on1OS Build Guide

This guide provides detailed instructions for building on1OS from source.

## Prerequisites

### System Requirements

- **OS**: Linux (Ubuntu 20.04+, Fedora 35+, Arch Linux, or similar)
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 20GB free space minimum, 50GB recommended
- **CPU**: Multi-core processor (build time scales with cores)

### Hardware Features (Optional but Recommended)

- **TPM 2.0**: For hardware-backed encryption keys
- **UEFI**: With Secure Boot capability
- **x86_64**: Primary supported architecture

## Quick Build

```bash
# Clone the repository
git clone https://github.com/John0n1/on1OS.git
cd on1OS

# One-command build
make all
```

## Step-by-Step Build

### 1. Environment Setup

```bash
# Install build dependencies and download sources
make setup
```

This will:
- Install build tools and dependencies
- Download kernel, Buildroot, GRUB, and other sources
- Create build directory structure

### 2. Configuration

```bash
# Configure build options
make config
```

Edit configuration files in `config/` as needed:
- `config/build.conf` - Main build configuration
- `config/security.conf` - Security hardening options

### 3. Build Components

#### Kernel

```bash
make kernel
```

Builds the hardened Linux kernel with security features:
- KASLR, SMEP, SMAP enabled
- Control Flow Integrity (CFI)
- Stack protection and overflow detection
- TPM2 and LUKS2 support

#### Root Filesystem

```bash
make rootfs
```

Creates minimal userspace with:
- musl libc for reduced attack surface
- systemd as init system
- Essential utilities (bash, coreutils, util-linux)
- Cryptographic tools (cryptsetup, tpm2-tools)

#### Initramfs

```bash
make initramfs
```

Generates dracut-ng based initramfs with:
- LUKS2 unlock support
- TPM2 integration
- systemd in initrd
- Network boot capability

#### Bootloader

```bash
make bootloader
```

Builds GRUB2 with:
- UEFI Secure Boot support
- TPM2 measurements
- Encrypted boot partition support

### 4. Create Installation Media

```bash
make iso
```

Assembles final bootable ISO with all components.

## Build Options

### Development Build

For faster development iterations:

```bash
make config-dev  # Enable development options
make all-dev     # Build with debug symbols and faster options
```

### Custom Configuration

Copy and modify configuration files:

```bash
cp config/build.conf config/local.conf
# Edit config/local.conf with your customizations
make clean && make all
```

## Testing

### Virtual Machine Testing

```bash
# Test basic functionality
make test-vm

# Test with TPM2 and Secure Boot
make test-vm-secure
```

### Hardware Testing

```bash
# Create USB installer
make usb-installer

# Create network boot image
make netboot
```

## Troubleshooting

### Common Issues

#### Build Dependencies Missing

```bash
# Re-run setup to install missing packages
make setup
```

#### Insufficient Disk Space

```bash
# Clean build artifacts
make clean

# Clean everything including downloads
make distclean
```

#### Kernel Build Fails

```bash
# Check kernel configuration
make kernel-config

# Build with verbose output
make kernel VERBOSE=1
```

#### Rootfs Build Fails

```bash
# Check Buildroot configuration
make rootfs-config

# Build with verbose output
make rootfs VERBOSE=1
```

### Build Logs

Build logs are saved in:
- `build/logs/kernel.log` - Kernel build log
- `build/logs/rootfs.log` - Rootfs build log
- `build/logs/iso.log` - ISO creation log

### Getting Help

- **GitHub Issues**: https://github.com/John0n1/on1OS/issues
- **Discussions**: https://github.com/John0n1/on1OS/discussions
- **Wiki**: https://github.com/John0n1/on1OS/wiki

## Advanced Topics

### Cross-Compilation

For building on different architectures:

```bash
export TARGET_ARCH=aarch64
make config-cross
make all
```

### Custom Kernel Configuration

```bash
make kernel-menuconfig  # Interactive kernel configuration
make kernel-saveconfig  # Save configuration
```

### Custom Package Selection

Edit `config/packages.conf` to customize included packages.

### Security Hardening

See [SECURITY.md](SECURITY.md) for detailed security configuration options.

## Performance Optimization

### Parallel Builds

```bash
export BUILD_JOBS=16  # Use 16 parallel jobs
make all
```

### ccache Support

```bash
export BUILD_CCACHE=true
make all
```

### Local Mirror

For faster source downloads:

```bash
export DEV_LOCAL_MIRROR="http://your-local-mirror/"
make setup
```
