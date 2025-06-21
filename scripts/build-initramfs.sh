#!/bin/bash
# Build initramfs using dracut-ng for on1OS

set -e

DRACUT_SRC="build/dracut-ng-100"
BUILD_DIR="build/initramfs"
KERNEL_VERSION="6.14.9-hardened1"
ROOTFS_DIR="build/rootfs"

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_info "Building initramfs with dracut-ng..."

# Check if dracut-ng source exists
if [ ! -d "$DRACUT_SRC" ]; then
    echo "Error: dracut-ng source not found. Run 'make setup' first."
    exit 1
fi

# Create build directory
mkdir -p "$BUILD_DIR"

# Install dracut-ng if not already installed
if [ ! -f "/usr/local/bin/dracut" ]; then
    log_info "Installing dracut-ng..."
    cd "$DRACUT_SRC"
    
    # Configure and build dracut-ng
    ./configure --prefix=/usr/local \
                --sysconfdir=/etc \
                --enable-documentation=no
    make -j$(nproc)
    sudo make install
    cd ../../..
fi

# Create dracut configuration for on1OS
log_info "Creating dracut configuration..."
sudo mkdir -p /etc/dracut.conf.d

cat | sudo tee /etc/dracut.conf.d/on1os.conf > /dev/null << 'EOF'
# on1OS dracut configuration
# Security-focused initramfs with TPM2 and LUKS2 support

# Basic configuration
hostonly="no"
hostonly_cmdline="no"
use_fstab="no"
install_optional_items+=" /sbin/fsck.ext4 /sbin/fsck.vfat "

# Required modules for secure boot
add_dracutmodules+=" base systemd systemd-initrd dracut-systemd "
add_dracutmodules+=" fs-lib kernel-modules rootfs-block udev-rules "
add_dracutmodules+=" usrmount shutdown "

# Encryption support
add_dracutmodules+=" crypt dm crypt-gpg tpm2-tss "
add_dracutmodules+=" systemd-cryptsetup "

# TPM2 support
add_dracutmodules+=" tpm2-tss "
install_items+=" /usr/bin/tpm2_* /usr/lib*/libtss2-* "

# Filesystem support
add_dracutmodules+=" fs-lib "
filesystems+=" ext4 vfat "

# Network support (minimal)
add_dracutmodules+=" network-legacy "

# Compression
compress="xz"
compress_args="-9 --check=crc32"

# Security
kernel_cmdline="rd.shell=0 rd.emergency=reboot rd.debug=0"

# Drivers
add_drivers+=" ahci libahci sd_mod ext4 vfat "
add_drivers+=" xhci_hcd ehci_hcd uhci_hcd "
add_drivers+=" usb_storage uas "

# Host-only mode disabled for generic image
hostonly="no"
hostonly_mode="sloppy"
EOF

# Create kernel modules directory structure
log_info "Preparing kernel modules..."
MODULES_DIR="/lib/modules/${KERNEL_VERSION}"
sudo mkdir -p "$MODULES_DIR"

# Copy kernel modules from our build
if [ -d "${ROOTFS_DIR}/modules/lib/modules/${KERNEL_VERSION}" ]; then
    sudo cp -r "${ROOTFS_DIR}/modules/lib/modules/${KERNEL_VERSION}"/* "$MODULES_DIR/"
else
    log_warn "Kernel modules not found. Build kernel first with 'make kernel'"
fi

# Generate initramfs
log_info "Generating initramfs..."
OUTPUT_DIR="build/iso"
mkdir -p "$OUTPUT_DIR"

sudo /usr/local/bin/dracut \
    --conf /etc/dracut.conf.d/on1os.conf \
    --kver "$KERNEL_VERSION" \
    --force \
    --verbose \
    "$OUTPUT_DIR/initrd.img" \
    "$KERNEL_VERSION"

# Set proper permissions
sudo chown $(whoami):$(whoami) "$OUTPUT_DIR/initrd.img"

log_info "Initramfs build complete!"
log_info "Initramfs image: ${OUTPUT_DIR}/initrd.img"
log_info "Size: $(du -h ${OUTPUT_DIR}/initrd.img | cut -f1)"

# Display modules included
log_info "Modules included in initramfs:"
sudo /usr/local/bin/lsinitrd "$OUTPUT_DIR/initrd.img" | head -20
