#!/bin/bash
# Configure build options for on1OS

set -e

# Ensure non-interactive mode
export DEBIAN_FRONTEND=noninteractive

CONFIG_DIR="config"
CONFIG_FILE="$CONFIG_DIR/build.conf"

# Source shared libraries
source "scripts/lib/log.sh"



# Create config directory
mkdir -p "$CONFIG_DIR"

log_info "on1OS Build Configuration"
echo "=========================="
echo

# Architecture selection
echo "Select target architecture:"
echo "1) x86_64 (default)"
echo "2) i386"
echo "3) aarch64"

# Use default for automated builds
if [ -n "$CI" ] || [ "$DEBIAN_FRONTEND" = "noninteractive" ]; then
    arch_choice=1
    log_info "Using default architecture: x86_64"
else
    read -p "Choice [1]: " arch_choice
fi

case $arch_choice in
    2) ARCH="i386" ;;
    3) ARCH="aarch64" ;;
    *) ARCH="x86_64" ;;
esac

# Security level
echo
echo "Select security level:"
echo "1) Maximum (recommended for production)"
echo "2) High (good balance)"
echo "3) Medium (development/testing)"

# Use default for automated builds
if [ -n "$CI" ] || [ "$DEBIAN_FRONTEND" = "noninteractive" ]; then
    security_choice=1
    log_info "Using default security level: Maximum"
else
    read -p "Choice [1]: " security_choice
fi

case $security_choice in
    2) SECURITY_LEVEL="high" ;;
    3) SECURITY_LEVEL="medium" ;;
    *) SECURITY_LEVEL="maximum" ;;
esac

# TPM support
echo
# Use default for automated builds
if [ -n "$CI" ] || [ "$DEBIAN_FRONTEND" = "noninteractive" ]; then
    tpm_choice="Y"
    log_info "Using default TPM2 support: Yes"
else
    read -p "Enable TPM2 support? [Y/n]: " tpm_choice
fi
case $tpm_choice in
    n|N) ENABLE_TPM="no" ;;
    *) ENABLE_TPM="yes" ;;
esac

# Secure Boot
echo
# Use default for automated builds
if [ -n "$CI" ] || [ "$DEBIAN_FRONTEND" = "noninteractive" ]; then
    secboot_choice="Y"
    log_info "Using default Secure Boot support: Yes"
else
    read -p "Enable Secure Boot support? [Y/n]: " secboot_choice
fi
case $secboot_choice in
    n|N) ENABLE_SECUREBOOT="no" ;;
    *) ENABLE_SECUREBOOT="yes" ;;
esac

# Encryption
echo
# Use default for automated builds
if [ -n "$CI" ] || [ "$DEBIAN_FRONTEND" = "noninteractive" ]; then
    encryption_choice="Y"
    log_info "Using default full disk encryption: Yes"
else
    read -p "Enable full disk encryption (LUKS2)? [Y/n]: " encryption_choice
fi
case $encryption_choice in
    n|N) ENABLE_ENCRYPTION="no" ;;
    *) ENABLE_ENCRYPTION="yes" ;;
esac

# Networking
echo
echo "Select networking configuration:"
echo "1) Minimal (loopback only)"
echo "2) Basic (ethernet + wifi)"
echo "3) Full (all network drivers)"

# Use default for automated builds
if [ -n "$CI" ] || [ "$DEBIAN_FRONTEND" = "noninteractive" ]; then
    network_choice=2
    log_info "Using default networking configuration: Basic"
else
    read -p "Choice [2]: " network_choice
fi

case $network_choice in
    1) NETWORK_CONFIG="minimal" ;;
    3) NETWORK_CONFIG="full" ;;
    *) NETWORK_CONFIG="basic" ;;
esac

# Development tools
echo
# Use default for automated builds
if [ -n "$CI" ] || [ "$DEBIAN_FRONTEND" = "noninteractive" ]; then
    devtools_choice="N"
    log_info "Using default development tools: No"
else
    read -p "Include development tools in rootfs? [y/N]: " devtools_choice
fi
case $devtools_choice in
    y|Y) INCLUDE_DEVTOOLS="yes" ;;
    *) INCLUDE_DEVTOOLS="no" ;;
esac

# Build jobs
echo
CPU_CORES=$(nproc)
# Use default for automated builds
if [ -n "$CI" ] || [ "$DEBIAN_FRONTEND" = "noninteractive" ]; then
    jobs_choice=$CPU_CORES
    log_info "Using default build jobs: $CPU_CORES"
else
    read -p "Number of parallel build jobs [$CPU_CORES]: " jobs_choice
fi
MAKE_JOBS=${jobs_choice:-$CPU_CORES}

# Save configuration
log_info "Saving configuration to $CONFIG_FILE"

cat > "$CONFIG_FILE" << EOF
# on1OS Build Configuration
# Generated on $(date)

# Target architecture
ARCH="$ARCH"

# Security configuration
SECURITY_LEVEL="$SECURITY_LEVEL"
ENABLE_TPM="$ENABLE_TPM"
ENABLE_SECUREBOOT="$ENABLE_SECUREBOOT"
ENABLE_ENCRYPTION="$ENABLE_ENCRYPTION"

# Network configuration
NETWORK_CONFIG="$NETWORK_CONFIG"

# Development tools
INCLUDE_DEVTOOLS="$INCLUDE_DEVTOOLS"

# Build settings
MAKE_JOBS="$MAKE_JOBS"

# Version overrides (leave empty for defaults)
KERNEL_VERSION_OVERRIDE=""
BUILDROOT_VERSION_OVERRIDE=""
SYSTEMD_VERSION_OVERRIDE=""
EOF

# Create kernel configuration template based on security level
log_info "Creating kernel configuration template..."

KERNEL_CONFIG="$CONFIG_DIR/kernel.conf"
cat > "$KERNEL_CONFIG" << EOF
# on1OS Kernel Configuration Template
# Security Level: $SECURITY_LEVEL
# Architecture: $ARCH

EOF

case $SECURITY_LEVEL in
    "maximum")
        cat >> "$KERNEL_CONFIG" << 'EOF'
# Maximum security settings
CONFIG_SECURITY_DMESG_RESTRICT=y
CONFIG_SECURITY_PERF_EVENTS_RESTRICT=y
CONFIG_KEXEC_FILE=y
CONFIG_KEXEC_SIG=y
CONFIG_KEXEC_SIG_FORCE=y
CONFIG_MODULE_SIG=y
CONFIG_MODULE_SIG_FORCE=y
CONFIG_MODULE_SIG_ALL=y
CONFIG_MODULE_SIG_SHA512=y
CONFIG_SECURITY_LOCKDOWN_LSM=y
CONFIG_SECURITY_LOCKDOWN_LSM_EARLY=y
CONFIG_LOCK_DOWN_KERNEL_FORCE_CONFIDENTIALITY=y
EOF
        ;;
    "high")
        cat >> "$KERNEL_CONFIG" << 'EOF'
# High security settings
CONFIG_SECURITY_DMESG_RESTRICT=y
CONFIG_KEXEC_FILE=y
CONFIG_MODULE_SIG=y
CONFIG_MODULE_SIG_ALL=y
CONFIG_MODULE_SIG_SHA256=y
CONFIG_SECURITY_LOCKDOWN_LSM=y
EOF
        ;;
    "medium")
        cat >> "$KERNEL_CONFIG" << 'EOF'
# Medium security settings
CONFIG_MODULE_SIG=y
CONFIG_MODULE_SIG_SHA256=y
EOF
        ;;
esac

# Add TPM configuration if enabled
if [ "$ENABLE_TPM" = "yes" ]; then
    cat >> "$KERNEL_CONFIG" << 'EOF'

# TPM2 support
CONFIG_TCG_TPM=y
CONFIG_TCG_TIS_CORE=y
CONFIG_TCG_TIS=y
CONFIG_TCG_CRB=y
CONFIG_TCG_TIS_SPI=y
CONFIG_TCG_TIS_I2C_ATMEL=y
CONFIG_TCG_TIS_I2C_INFINEON=y
CONFIG_TCG_TIS_I2C_NUVOTON=y
CONFIG_HW_RANDOM_TPM=y
EOF
fi

# Add encryption support if enabled
if [ "$ENABLE_ENCRYPTION" = "yes" ]; then
    cat >> "$KERNEL_CONFIG" << 'EOF'

# LUKS2/encryption support
CONFIG_DM_CRYPT=y
CONFIG_CRYPTO_XTS=y
CONFIG_CRYPTO_AES=y
CONFIG_CRYPTO_AES_NI_INTEL=y
CONFIG_CRYPTO_SHA256=y
CONFIG_CRYPTO_SHA512=y
CONFIG_CRYPTO_USER_API_HASH=y
CONFIG_CRYPTO_USER_API_SKCIPHER=y
EOF
fi

# Create Buildroot configuration template
log_info "Creating Buildroot configuration template..."

BUILDROOT_CONFIG="$CONFIG_DIR/buildroot.conf"
cat > "$BUILDROOT_CONFIG" << EOF
# on1OS Buildroot Configuration Template
# Architecture: $ARCH
# Security Level: $SECURITY_LEVEL

# Target options
BR2_${ARCH//-/_}=y

# Toolchain
BR2_TOOLCHAIN_BUILDROOT_MUSL=y

# System configuration
BR2_TARGET_GENERIC_HOSTNAME="on1os"
BR2_TARGET_GENERIC_ISSUE="on1OS Security Distribution"
BR2_ROOTFS_DEVICE_CREATION_DYNAMIC_SYSTEMD=y

# Init system
BR2_INIT_SYSTEMD=y

# Security packages
BR2_PACKAGE_SYSTEMD=y
BR2_PACKAGE_CRYPTSETUP=y

EOF

if [ "$ENABLE_TPM" = "yes" ]; then
    cat >> "$BUILDROOT_CONFIG" << 'EOF'
# TPM2 packages
BR2_PACKAGE_TPM2_TOOLS=y
BR2_PACKAGE_TPM2_TSS=y
BR2_PACKAGE_TPM2_ABRMD=y

EOF
fi

if [ "$INCLUDE_DEVTOOLS" = "yes" ]; then
    cat >> "$BUILDROOT_CONFIG" << 'EOF'
# Development tools
BR2_PACKAGE_GCC=y
BR2_PACKAGE_MAKE=y
BR2_PACKAGE_GDB=y
BR2_PACKAGE_STRACE=y
BR2_PACKAGE_LTRACE=y
BR2_PACKAGE_VIM=y

EOF
fi

case $NETWORK_CONFIG in
    "minimal")
        cat >> "$BUILDROOT_CONFIG" << 'EOF'
# Minimal networking
BR2_PACKAGE_BUSYBOX_SHOW_OTHERS=y

EOF
        ;;
    "basic")
        cat >> "$BUILDROOT_CONFIG" << 'EOF'
# Basic networking
BR2_PACKAGE_DHCPCD=y
BR2_PACKAGE_OPENSSH=y
BR2_PACKAGE_WPA_SUPPLICANT=y
BR2_PACKAGE_WIRELESS_TOOLS=y

EOF
        ;;
    "full")
        cat >> "$BUILDROOT_CONFIG" << 'EOF'
# Full networking
BR2_PACKAGE_DHCPCD=y
BR2_PACKAGE_OPENSSH=y
BR2_PACKAGE_WPA_SUPPLICANT=y
BR2_PACKAGE_WIRELESS_TOOLS=y
BR2_PACKAGE_IPTABLES=y
BR2_PACKAGE_NFTABLES=y
BR2_PACKAGE_TCPDUMP=y
BR2_PACKAGE_WGET=y
BR2_PACKAGE_CURL=y

EOF
        ;;
esac

echo
log_info "Configuration complete!"
echo
log_note "Configuration saved to: $CONFIG_FILE"
log_note "Kernel config template: $KERNEL_CONFIG"
log_note "Buildroot config template: $BUILDROOT_CONFIG"
echo
log_info "Next steps:"
log_info "  1. Review configuration files in config/ directory"
log_info "  2. Run 'make setup' to prepare build environment"
log_info "  3. Run 'make all' to build the complete system"
echo
log_warn "Note: Some settings may require root privileges during build"
