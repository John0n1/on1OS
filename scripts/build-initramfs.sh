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
    
    # Copy essential dracut-ng files for proper operation
    sudo cp dracut-version.sh /usr/local/lib/dracut/
    sudo cp dracut-init.sh /usr/local/lib/dracut/
    sudo cp dracut-functions.sh /usr/local/lib/dracut/
    sudo cp dracut-logger.sh /usr/local/lib/dracut/
    
    # Copy additional binaries to dracut lib directory for fallback
    sudo cp src/install/dracut-install /usr/local/lib/dracut/
    sudo cp src/skipcpio/skipcpio /usr/local/lib/dracut/
    
    # Fix dracut paths to point to /usr/local/lib/dracut
    sudo sed -i 's|/usr/lib/dracut|/usr/local/lib/dracut|g' /usr/local/bin/dracut
    
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
    if sudo mkdir -p /usr/share/plymouth/themes/on1os 2>/dev/null; then
        sudo cp -r build/branding/plymouth/on1os/* /usr/share/plymouth/themes/on1os/ 2>/dev/null || true
        sudo chown -R root:root /usr/share/plymouth/themes/on1os 2>/dev/null || true
        # Set as default theme - handle gracefully if plymouth-set-default-theme is not available
        if command -v plymouth-set-default-theme >/dev/null 2>&1; then
            sudo plymouth-set-default-theme on1os 2>/dev/null || log_warn "Could not set Plymouth theme"
        else
            log_warn "plymouth-set-default-theme command not found, skipping theme setup"
            # Create a symlink to make on1os the default theme manually if possible
            if [ -d "/usr/share/plymouth/themes/on1os" ] && [ -L "/etc/alternatives/default.plymouth" ]; then
                sudo ln -sf "/usr/share/plymouth/themes/on1os/on1os.plymouth" "/etc/alternatives/default.plymouth" 2>/dev/null || true
            fi
        fi
    else
        log_warn "Failed to create Plymouth theme directory, insufficient permissions"
    fi
else
    log_info "No custom Plymouth theme found, using system default"
fi

# Ensure lsinitrd is available
if [ ! -f "/usr/local/bin/lsinitrd" ] && [ -f "$DRACUT_SRC/lsinitrd.sh" ]; then
    log_info "Installing missing lsinitrd..."
    sudo cp "$DRACUT_SRC/lsinitrd.sh" /usr/local/bin/lsinitrd
    sudo chmod +x /usr/local/bin/lsinitrd
fi

sudo mkdir -p /etc/dracut.conf.d

sudo tee /etc/dracut.conf.d/on1os.conf > /dev/null << EOF
# on1OS dracut configuration
# Minimal initramfs configuration

# Basic configuration
hostonly="no"
hostonly_cmdline="no"
use_fstab="no"

# Essential modules only
add_dracutmodules+=" base kernel-modules rootfs-block "
add_dracutmodules+=" fs-lib shutdown "

# Live CD support modules - conditionally added
add_dracutmodules+=" $LIVE_MODULES "

# Filesystem support
filesystems+=" ext4 vfat iso9660 squashfs "

# Consolidated driver additions
add_drivers+=" ahci libahci sd_mod ext4 vfat "  # Basic storage drivers
add_drivers+=" xhci_hcd ehci_hcd uhci_hcd usb_storage "  # USB storage drivers
add_drivers+=" iso9660 sr_mod cdrom loop squashfs "  # ISO and CD-ROM drivers
add_drivers+=" uart_16550 serial_core "  # Console and debugging drivers

# Add uas driver only if available (USB Attached SCSI)
# This driver may not be available in all kernel configurations
# Add uas driver only if available (USB Attached SCSI)
if modinfo uas >/dev/null 2>&1; then
    add_drivers+=" uas "
fi

# Explicitly omit problematic modules
omit_dracutmodules+=" nvmf iscsi nfs "
omit_dracutmodules+=" systemd-cryptsetup systemd-coredump systemd-portabled "
omit_dracutmodules+=" dbus-broker rngd bluetooth btrfs "
omit_dracutmodules+=" multipath pcsc biosdevname memstrack modsign "
omit_dracutmodules+=" tpm2-tss crypt-gpg mksh lvm "

# Conditionally omit systemd modules that may not be available
if [ -d "/usr/lib/dracut/modules.d/35systemd-resolved" ] || [ -d "/usr/local/lib/dracut/modules.d/35systemd-resolved" ]; then
    omit_dracutmodules+=" systemd-resolved "
fi

# Conditionally omit systemd-pcrphase if not available (TPM PCR measurement module)
if [ ! -x /usr/lib/systemd/systemd-pcrphase ]; then
    omit_dracutmodules+=" systemd-pcrphase "
fi

# Explicitly omit network storage modules that cause dependency issues
omit_drivers+=" nvme-fabrics nvme-rdma nvme-tcp "

# Compression
compress="xz"
compress_args="-9 --check=crc32"

# Security
kernel_cmdline="rd.shell=0 rd.emergency=reboot rd.debug=0"

# Host-only mode disabled for generic image
hostonly_mode="sloppy"

# Enable debug capabilities when rd.debug is passed
# This allows emergency shell in debug mode
install_optional_items+=" /sbin/sulogin /bin/sh /usr/bin/systemctl "
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
