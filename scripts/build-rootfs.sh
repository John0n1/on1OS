#!/bin/bash
# Build minimal root filesystem using Buildroot with musl libc

set -euo pipefail

# Ensure non-interactive mode
export DEBIAN_FRONTEND=noninteractive

# Source shared libraries using absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/log.sh"

# Set clean PATH to avoid buildroot issues - Buildroot is very strict about this
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
# Remove any problematic environment variables
unset HOSTCC HOSTCXX CC CXX
# Clear any buildroot-specific variables
unset BR2_EXTERNAL BR2_CONFIG

BUILDROOT_SRC="build/buildroot-2025.05"
BUILD_DIR="build/rootfs"
ROOTFS_OUTPUT="build/rootfs/rootfs.tar.gz"

log_info "Building minimal root filesystem with Buildroot..."

# Check if Buildroot source exists
if [ ! -d "$BUILDROOT_SRC" ]; then
    echo "Error: Buildroot source not found. Run 'make setup' first."
    exit 1
fi

# Create build directory
mkdir -p "$BUILD_DIR"

# Copy Buildroot source to build directory
if [ ! -d "$BUILD_DIR/buildroot" ]; then
    log_info "Copying Buildroot source..."
    cp -r "$BUILDROOT_SRC" "$BUILD_DIR/buildroot"
fi

cd "$BUILD_DIR/buildroot"

# Create custom Buildroot configuration for on1OS
log_info "Creating Buildroot configuration..."
cat > configs/on1os_defconfig << 'EOF'
# on1OS Buildroot Configuration
# Minimal, hardened root filesystem with musl libc

# Target architecture
BR2_x86_64=y
BR2_x86_corei7=y

# Toolchain configuration
BR2_TOOLCHAIN_BUILDROOT=y
BR2_TOOLCHAIN_BUILDROOT_MUSL=y
BR2_TOOLCHAIN_BUILDROOT_CXX=y

# System configuration
BR2_TARGET_GENERIC_HOSTNAME="on1os"
BR2_TARGET_GENERIC_ISSUE="Welcome to on1OS - Hardened Linux Distribution"
BR2_TARGET_GENERIC_PASSWD_SHA512=y
BR2_INIT_SYSTEMD=y
BR2_SYSTEM_DHCP="eth0"

# Root password (change in production!)
BR2_TARGET_GENERIC_ROOT_PASSWD="on1os"

# Essential packages
BR2_PACKAGE_BUSYBOX=y
BR2_PACKAGE_BASH=y
BR2_PACKAGE_COREUTILS=y
BR2_PACKAGE_UTIL_LINUX=y
BR2_PACKAGE_KMOD=y

# Systemd and dependencies
BR2_PACKAGE_SYSTEMD=y
BR2_PACKAGE_SYSTEMD_NETWORKD=y
BR2_PACKAGE_SYSTEMD_RESOLVED=y
BR2_PACKAGE_SYSTEMD_TIMESYNCD=y

# Network tools
BR2_PACKAGE_IPROUTE2=y
BR2_PACKAGE_OPENSSH=y

# File systems
BR2_PACKAGE_E2FSPROGS=y

# Target options
BR2_TARGET_ROOTFS_TAR=y
BR2_TARGET_ROOTFS_TAR_GZIP=y
BR2_ROOTFS_OVERLAY="../overlay"

# Kernel modules directory
BR2_ROOTFS_POST_BUILD_SCRIPT="../post-build.sh"
EOF

# Create overlay directory for custom files
log_info "Creating rootfs overlay..."
mkdir -p ../overlay/etc/systemd/system
mkdir -p ../overlay/etc/dracut.conf.d
mkdir -p ../overlay/etc/crypttab
mkdir -p ../overlay/etc/fstab
mkdir -p ../overlay/usr/local/bin

# Create custom systemd service for TPM2 setup
cat > ../overlay/etc/systemd/system/tpm2-setup.service << 'EOF'
[Unit]
Description=TPM2 Setup for LUKS
Before=cryptsetup.target
ConditionPathExists=/dev/tpm0

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup-tpm2-luks.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Create TPM2 setup script
cat > ../overlay/usr/local/bin/setup-tpm2-luks.sh << 'EOF'
#!/bin/bash
# Setup TPM2 for LUKS key sealing

set -e

# Check if TPM2 is available
if [ ! -c /dev/tpm0 ]; then
    echo "TPM2 device not found"
    exit 1
fi

# Initialize TPM2 if needed
if ! tpm2_getcap properties-fixed > /dev/null 2>&1; then
    echo "Initializing TPM2..."
    tpm2_startup -c
    tpm2_clear
fi

echo "TPM2 setup complete"
EOF

chmod +x ../overlay/usr/local/bin/setup-tpm2-luks.sh

# Create post-build script
cat > ../post-build.sh << 'EOF'
#!/bin/bash
# Post-build script for on1OS rootfs

TARGET_DIR=$1

# Install kernel modules from kernel build
if [ -d "../../rootfs/modules" ]; then
    echo "Installing kernel modules..."
    cp -r ../../rootfs/modules/* "${TARGET_DIR}/"
fi

# Set up systemd services
echo "Enabling systemd services..."
# Create systemd service symlinks manually instead of using chroot
mkdir -p "${TARGET_DIR}/etc/systemd/system/multi-user.target.wants"
mkdir -p "${TARGET_DIR}/etc/systemd/system/sysinit.target.wants"

# Enable networkd
if [ -f "${TARGET_DIR}/lib/systemd/system/systemd-networkd.service" ]; then
    ln -sf /lib/systemd/system/systemd-networkd.service "${TARGET_DIR}/etc/systemd/system/multi-user.target.wants/"
fi

# Enable resolved
if [ -f "${TARGET_DIR}/lib/systemd/system/systemd-resolved.service" ]; then
    ln -sf /lib/systemd/system/systemd-resolved.service "${TARGET_DIR}/etc/systemd/system/multi-user.target.wants/"
fi

# Enable timesyncd
if [ -f "${TARGET_DIR}/lib/systemd/system/systemd-timesyncd.service" ]; then
    ln -sf /lib/systemd/system/systemd-timesyncd.service "${TARGET_DIR}/etc/systemd/system/sysinit.target.wants/"
fi

# Enable tpm2-setup if service exists
if [ -f "${TARGET_DIR}/lib/systemd/system/tpm2-setup.service" ]; then
    ln -sf /lib/systemd/system/tpm2-setup.service "${TARGET_DIR}/etc/systemd/system/multi-user.target.wants/"
fi

# Secure file permissions
echo "Setting secure permissions..."
# Ensure directories exist before setting permissions
mkdir -p "${TARGET_DIR}/root"
mkdir -p "${TARGET_DIR}/home"
chmod 700 "${TARGET_DIR}/root"
chmod 755 "${TARGET_DIR}/home"

# Create necessary directories
mkdir -p "${TARGET_DIR}/boot"
mkdir -p "${TARGET_DIR}/proc"
mkdir -p "${TARGET_DIR}/sys"
mkdir -p "${TARGET_DIR}/dev"
mkdir -p "${TARGET_DIR}/tmp"
mkdir -p "${TARGET_DIR}/var/log"

# Set secure tmp permissions
chmod 1777 "${TARGET_DIR}/tmp"

echo "Post-build script completed"
EOF

chmod +x ../post-build.sh

# Load configuration and build
log_info "Loading on1OS configuration..."
make on1os_defconfig

log_info "Building root filesystem (this may take a while)..."
make -j$(nproc)

# Extract rootfs for ISO creation
log_info "Extracting rootfs for ISO..."
cd ../..
mkdir -p iso/rootfs
cd iso/rootfs
tar -xzf ../../rootfs/buildroot/output/images/rootfs.tar.gz

cd ../..

log_info "Root filesystem build complete!"
log_info "Rootfs archive: $ROOTFS_OUTPUT"
log_info "Extracted rootfs: build/iso/rootfs/"
