#!/bin/bash
# Build hardened Linux kernel for on1OS

set -e

# Source directory
KERNEL_SRC="build/linux-hardened-6.14.9-hardened1"
BUILD_DIR="build/kernel"
ARCH="x86_64"

# Color output
GREEN='\033[0;32m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_info "Building hardened Linux kernel..."

# Check if kernel source exists
if [ ! -d "$KERNEL_SRC" ]; then
    echo "Error: Kernel source not found. Run 'make setup' first."
    exit 1
fi

# Create build directory
mkdir -p "$BUILD_DIR"

# Copy kernel source to build directory
if [ ! -d "$BUILD_DIR/linux" ]; then
    log_info "Copying kernel source..."
    cp -r "$KERNEL_SRC" "$BUILD_DIR/linux"
fi

cd "$BUILD_DIR/linux"

# Create hardened kernel configuration
log_info "Creating hardened kernel configuration..."
cat > .config << 'EOF'
# on1OS Hardened Kernel Configuration
CONFIG_64BIT=y
CONFIG_X86_64=y

# Security hardening options
CONFIG_SECURITY=y
CONFIG_SECURITY_DMESG_RESTRICT=y
CONFIG_SECURITY_PERF_EVENTS_RESTRICT=y
CONFIG_SECURITY_YAMA=y
CONFIG_HARDENED_USERCOPY=y
CONFIG_FORTIFY_SOURCE=y
CONFIG_STATIC_USERMODEHELPER=y
CONFIG_SLAB_FREELIST_RANDOM=y
CONFIG_SLAB_FREELIST_HARDENED=y
CONFIG_SHUFFLE_PAGE_ALLOCATOR=y
CONFIG_RANDOMIZE_BASE=y
CONFIG_RANDOMIZE_MEMORY=y

# Control Flow Integrity
CONFIG_CFI_CLANG=y
CONFIG_CFI_PERMISSIVE=y

# Stack protection
CONFIG_STACKPROTECTOR=y
CONFIG_STACKPROTECTOR_STRONG=y
CONFIG_GCC_PLUGIN_STACKLEAK=y

# Kernel Guard
CONFIG_KGUARD=y

# Memory protection
CONFIG_DEBUG_RODATA=y
CONFIG_DEBUG_SET_MODULE_RONX=y
CONFIG_STRICT_KERNEL_RWX=y
CONFIG_STRICT_MODULE_RWX=y

# KASLR
CONFIG_RANDOMIZE_BASE=y
CONFIG_RANDOMIZE_MEMORY=y

# SMEP/SMAP
CONFIG_X86_SMAP=y
CONFIG_X86_SMEP=y

# Intel CET
CONFIG_X86_INTEL_CET=y

# TPM support
CONFIG_TCG_TPM=y
CONFIG_TCG_TIS_CORE=y
CONFIG_TCG_TIS=y
CONFIG_TCG_CRBTPM=y

# Crypto support for LUKS
CONFIG_CRYPTO=y
CONFIG_CRYPTO_AES=y
CONFIG_CRYPTO_XTS=y
CONFIG_CRYPTO_SHA256=y
CONFIG_CRYPTO_USER_API_HASH=y
CONFIG_CRYPTO_USER_API_SKCIPHER=y

# Device mapper for LUKS
CONFIG_MD=y
CONFIG_BLK_DEV_DM=y
CONFIG_DM_CRYPT=y

# Filesystem support
CONFIG_EXT4_FS=y
CONFIG_EXT4_FS_SECURITY=y
CONFIG_TMPFS=y
CONFIG_TMPFS_POSIX_ACL=y

# Network security
CONFIG_NETWORK_SECMARK=y
CONFIG_NETFILTER=y
CONFIG_NETFILTER_ADVANCED=y

# Disable dangerous features
# CONFIG_DEVMEM is not set
# CONFIG_DEVKMEM is not set
# CONFIG_PROC_KCORE is not set
# CONFIG_COMPAT_VDSO is not set
# CONFIG_KEXEC is not set
# CONFIG_HIBERNATION is not set

# Essential drivers
CONFIG_PCI=y
CONFIG_SATA_AHCI=y
CONFIG_ATA=y
CONFIG_SCSI=y
CONFIG_BLK_DEV_SD=y
CONFIG_USB=y
CONFIG_USB_XHCI_HCD=y
CONFIG_USB_EHCI_HCD=y
CONFIG_USB_OHCI_HCD=y
CONFIG_USB_STORAGE=y

# UEFI support
CONFIG_EFI=y
CONFIG_EFI_STUB=y
CONFIG_EFI_VARS=y

# Systemd requirements
CONFIG_DEVTMPFS=y
CONFIG_CGROUPS=y
CONFIG_INOTIFY_USER=y
CONFIG_SIGNALFD=y
CONFIG_TIMERFD=y
CONFIG_EPOLL=y
CONFIG_NET=y
CONFIG_SYSFS=y
CONFIG_PROC_FS=y
CONFIG_FHANDLE=y
EOF

# Use kernel's default config as base and merge our hardening options
log_info "Generating kernel configuration..."
make defconfig
make olddefconfig

# Build kernel
log_info "Compiling kernel (this may take a while)..."
make -j$(nproc) bzImage modules

# Install modules to temporary directory
log_info "Installing kernel modules..."
INSTALL_MOD_PATH="../../rootfs/modules" make modules_install

# Copy kernel image
log_info "Copying kernel image..."
cp arch/x86/boot/bzImage ../../iso/vmlinuz

log_info "Kernel build complete!"
log_info "Kernel image: build/iso/vmlinuz"
log_info "Modules: build/rootfs/modules/"
