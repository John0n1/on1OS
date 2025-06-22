#!/bin/bash
# Build initramfs using dracut-ng for on1OS

set -e

# Ensure non-interactive mode
export DEBIAN_FRONTEND=noninteractive

# Source build configuration
if [ -f "config/defaults.conf" ]; then
    source "config/defaults.conf"
fi
if [ -f "config/build.conf" ]; then
    source "config/build.conf"
fi

# Set defaults if not configured
KERNEL_VERSION=${KERNEL_VERSION:-"v6.14.11-hardened1"}
# Remove 'v' prefix for directory names
KERNEL_VERSION_CLEAN=${KERNEL_VERSION#v}

DRACUT_SRC="build/dracut-ng-100"
BUILD_DIR="build/initramfs"
ROOTFS_DIR="build/rootfs"

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
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
if [ ! -f "/usr/local/bin/dracut" ] || [ ! -f "/usr/local/bin/lsinitrd" ]; then
    log_info "Installing dracut-ng..."
    cd "$DRACUT_SRC"
    
    # Configure and build dracut-ng (skip documentation)
    ./configure --prefix=/usr/local \
                --sysconfdir=/etc \
                --disable-documentation
    make -j$(nproc) dracut-install src/skipcpio/skipcpio
    sudo cp src/install/dracut-install /usr/local/bin/
    sudo cp src/skipcpio/skipcpio /usr/local/bin/
    sudo cp dracut.sh /usr/local/bin/dracut
    sudo cp lsinitrd.sh /usr/local/bin/lsinitrd
    sudo chmod +x /usr/local/bin/dracut
    sudo chmod +x /usr/local/bin/lsinitrd
    sudo mkdir -p /usr/local/lib/dracut
    sudo cp -r modules.d /usr/local/lib/dracut/
    sudo cp -r modules /usr/local/lib/dracut/ 2>/dev/null || true
    
    # Verify installation
    if [ ! -f "/usr/local/bin/lsinitrd" ]; then
        log_warn "Failed to install lsinitrd, copying again..."
        sudo cp lsinitrd.sh /usr/local/bin/lsinitrd
        sudo chmod +x /usr/local/bin/lsinitrd
    fi
    
    cd ../../..
fi

# Create dracut configuration for on1OS
log_info "Creating dracut configuration..."

# Install custom Plymouth theme if available
if [ -d "build/branding/plymouth/on1os" ]; then
    log_info "Installing custom Plymouth theme..."
    sudo mkdir -p /usr/share/plymouth/themes/on1os
    sudo cp -r build/branding/plymouth/on1os/* /usr/share/plymouth/themes/on1os/
    sudo chown -R root:root /usr/share/plymouth/themes/on1os
    # Set as default theme
    sudo plymouth-set-default-theme on1os 2>/dev/null || log_warn "Could not set Plymouth theme"
fi

# Ensure lsinitrd is available
if [ ! -f "/usr/local/bin/lsinitrd" ] && [ -f "$DRACUT_SRC/lsinitrd.sh" ]; then
    log_info "Installing missing lsinitrd..."
    sudo cp "$DRACUT_SRC/lsinitrd.sh" /usr/local/bin/lsinitrd
    sudo chmod +x /usr/local/bin/lsinitrd
fi

sudo mkdir -p /etc/dracut.conf.d

sudo tee /etc/dracut.conf.d/on1os.conf > /dev/null << 'EOF'
# on1OS dracut configuration
# Minimal initramfs configuration

# Basic configuration
hostonly="no"
hostonly_cmdline="no"
use_fstab="no"

# Essential modules only
add_dracutmodules+=" base kernel-modules rootfs-block "
add_dracutmodules+=" fs-lib shutdown "

# Filesystem support
filesystems+=" ext4 vfat "

# Basic storage drivers
add_drivers+=" ahci libahci sd_mod ext4 vfat "
add_drivers+=" xhci_hcd ehci_hcd uhci_hcd "
add_drivers+=" usb_storage uas "

# Explicitly omit problematic modules
omit_dracutmodules+=" nvmf iscsi nfs "
omit_dracutmodules+=" systemd-cryptsetup systemd-coredump systemd-portabled "
omit_dracutmodules+=" systemd-resolved dbus-broker rngd bluetooth btrfs "
omit_dracutmodules+=" multipath pcsc biosdevname memstrack modsign "
omit_dracutmodules+=" tpm2-tss crypt-gpg mksh "

# Explicitly omit network storage modules that cause dependency issues
omit_drivers+=" nvme-fabrics nvme-rdma nvme-tcp "

# Compression
compress="xz"
compress_args="-9 --check=crc32"

# Security
kernel_cmdline="rd.shell=0 rd.emergency=reboot rd.debug=0"

# Host-only mode disabled for generic image
hostonly_mode="sloppy"
EOF

# Create kernel modules directory structure
log_info "Preparing kernel modules..."
MODULES_DIR="/lib/modules/${KERNEL_VERSION_CLEAN}"
sudo mkdir -p "$MODULES_DIR"

# Copy kernel modules from our build
if [ -d "${ROOTFS_DIR}/modules/lib/modules/${KERNEL_VERSION_CLEAN}" ]; then
    sudo cp -r "${ROOTFS_DIR}/modules/lib/modules/${KERNEL_VERSION_CLEAN}"/* "$MODULES_DIR/"
    # Generate modules.dep
    sudo depmod -a "${KERNEL_VERSION_CLEAN}"
else
    log_warn "Kernel modules not found. Build kernel first with 'make kernel'"
fi

# Generate initramfs
log_info "Generating initramfs..."
OUTPUT_DIR="build/iso"
mkdir -p "$OUTPUT_DIR"

log_info "Running dracut to create initramfs..."
timeout 300 sudo /usr/local/bin/dracut \
    --conf /etc/dracut.conf.d/on1os.conf \
    --kver "$KERNEL_VERSION_CLEAN" \
    --force \
    --verbose \
    --no-hostonly \
    --no-early-microcode \
    "$OUTPUT_DIR/initrd.img" \
    "$KERNEL_VERSION_CLEAN" || {
    log_error "Dracut failed or timed out after 5 minutes"
    exit 1
}

# Set proper permissions
sudo chown $(whoami):$(whoami) "$OUTPUT_DIR/initrd.img"

log_info "Initramfs build complete!"
log_info "Initramfs image: ${OUTPUT_DIR}/initrd.img"
log_info "Size: $(du -h ${OUTPUT_DIR}/initrd.img | cut -f1)"

# Display modules included
log_info "Modules included in initramfs:"
if [ -f "/usr/local/bin/lsinitrd" ]; then
    sudo /usr/local/bin/lsinitrd "$OUTPUT_DIR/initrd.img" | head -20
else
    log_warn "lsinitrd not available, skipping module listing"
fi
