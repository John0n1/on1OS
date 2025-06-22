#!/bin/bash
# Create bootable ISO image for on1OS

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

BUILD_DIR="build"
ISO_DIR="$BUILD_DIR/iso"
ROOTFS_DIR="$BUILD_DIR/rootfs"
OUTPUT_ISO="$BUILD_DIR/on1OS.iso"

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_note() {
    echo -e "${BLUE}[NOTE]${NC} $1"
}

log_info "Creating bootable ISO image for on1OS..."

# Check if required components exist
if [ ! -f "$ISO_DIR/vmlinuz" ]; then
    echo "Error: Kernel not found. Run 'make kernel' first."
    exit 1
fi

if [ ! -f "$ISO_DIR/initrd.img" ]; then
    echo "Error: Initramfs not found. Run 'make initramfs' first."
    exit 1
fi

if [ ! -f "$ISO_DIR/boot/grub/grub.cfg" ]; then
    echo "Error: GRUB configuration not found. Run 'make bootloader' first."
    exit 1
fi

# Create ISO working directory
ISO_WORK_DIR="$BUILD_DIR/iso-workdir"
rm -rf "$ISO_WORK_DIR"
mkdir -p "$ISO_WORK_DIR"

# Copy ISO contents
log_info "Copying ISO contents..."
cp -r "$ISO_DIR"/* "$ISO_WORK_DIR/"

# Create EFI boot directory structure
log_info "Setting up EFI boot structure..."
mkdir -p "$ISO_WORK_DIR/EFI/BOOT"
if [ -f "$BUILD_DIR/bootloader/grub-rescue/bootx64.efi" ]; then
    cp "$BUILD_DIR/bootloader/grub-rescue/bootx64.efi" "$ISO_WORK_DIR/EFI/BOOT/"
else
    log_warn "EFI bootloader not found. EFI boot may not work."
fi

# Create BIOS boot structure
log_info "Setting up BIOS boot structure..."
mkdir -p "$ISO_WORK_DIR/boot/grub/i386-pc"
# Copy GRUB BIOS modules from system location
cp /usr/lib/grub/i386-pc/*.mod "$ISO_WORK_DIR/boot/grub/i386-pc/" 2>/dev/null || true
cp /usr/lib/grub/i386-pc/*.lst "$ISO_WORK_DIR/boot/grub/i386-pc/" 2>/dev/null || true

# Copy root filesystem if available
if [ -f "$BUILD_DIR/rootfs/buildroot/output/images/rootfs.tar.gz" ]; then
    log_info "Including root filesystem..."
    cp "$BUILD_DIR/rootfs/buildroot/output/images/rootfs.tar.gz" "$ISO_WORK_DIR/rootfs.tar.gz"
fi

# Create isolinux configuration for fallback boot
log_info "Creating isolinux configuration..."
mkdir -p "$ISO_WORK_DIR/isolinux"

# Copy isolinux files
if [ -f "/usr/lib/ISOLINUX/isolinux.bin" ]; then
    cp /usr/lib/ISOLINUX/isolinux.bin "$ISO_WORK_DIR/isolinux/"
    cp /usr/lib/syslinux/modules/bios/ldlinux.c32 "$ISO_WORK_DIR/isolinux/" 2>/dev/null || true
    cp /usr/lib/syslinux/modules/bios/libcom32.c32 "$ISO_WORK_DIR/isolinux/" 2>/dev/null || true
    cp /usr/lib/syslinux/modules/bios/libutil.c32 "$ISO_WORK_DIR/isolinux/" 2>/dev/null || true
    cp /usr/lib/syslinux/modules/bios/vesamenu.c32 "$ISO_WORK_DIR/isolinux/" 2>/dev/null || true
elif [ -f "/usr/share/syslinux/isolinux.bin" ]; then
    cp /usr/share/syslinux/isolinux.bin "$ISO_WORK_DIR/isolinux/"
    cp /usr/share/syslinux/ldlinux.c32 "$ISO_WORK_DIR/isolinux/" 2>/dev/null || true
    cp /usr/share/syslinux/libcom32.c32 "$ISO_WORK_DIR/isolinux/" 2>/dev/null || true
    cp /usr/share/syslinux/libutil.c32 "$ISO_WORK_DIR/isolinux/" 2>/dev/null || true
    cp /usr/share/syslinux/vesamenu.c32 "$ISO_WORK_DIR/isolinux/" 2>/dev/null || true
else
    log_warn "isolinux not found. BIOS fallback boot may not work."
fi

# Create isolinux configuration
cat > "$ISO_WORK_DIR/isolinux/isolinux.cfg" << 'EOF'
DEFAULT vesamenu.c32
TIMEOUT 100
MENU TITLE on1OS Boot Menu

LABEL on1os
    MENU LABEL on1OS (Default)
    MENU DEFAULT
    KERNEL /vmlinuz
    APPEND initrd=/initrd.img root=live:CDLABEL=ON1OS ro rd.live.image quiet splash

LABEL on1os-recovery
    MENU LABEL on1OS (Recovery Mode)
    KERNEL /vmlinuz
    APPEND initrd=/initrd.img root=live:CDLABEL=ON1OS ro rd.live.image single

LABEL reboot
    MENU LABEL Reboot
    COM32 reboot.c32

LABEL poweroff
    MENU LABEL Power Off
    COM32 poweroff.c32
EOF

# Create documentation
log_info "Creating documentation..."
mkdir -p "$ISO_WORK_DIR/docs"

cat > "$ISO_WORK_DIR/docs/README.txt" << 'EOF'
on1OS - Hardened Linux Distribution
===================================

Welcome to on1OS, a security-focused Linux distribution designed for 
maximum protection and privacy.

Key Features:
- Hardened Linux kernel (6.14.9-hardened1)
- systemd init system (v256.16)
- dracut-ng initramfs (Release 100)
- GRUB2 bootloader with security features
- musl libc for minimal attack surface
- TPM2 and LUKS2 encryption support
- Secure Boot compatibility

Boot Options:
1. on1OS (Default) - Normal boot with full security features
2. on1OS (Recovery) - Recovery mode for troubleshooting

For more information, visit: https://github.com/on1OS/on1OS

Security Notice:
This distribution implements various security hardening measures.
Some applications may behave differently than on standard distributions.

Installation:
Boot from this ISO and follow the installation prompts.
Ensure your system supports UEFI and TPM2 for full security features.

License: Various (see individual component licenses)
EOF

# Create version information
cat > "$ISO_WORK_DIR/docs/VERSION.txt" << EOF
on1OS Build Information
======================
Build Date: $(date)
Kernel: linux-hardened 6.14.9-hardened1
Init: systemd v256.16
Initramfs: dracut-ng Release 100
Bootloader: GRUB2 (latest Git stable)
Root FS: Buildroot 2025.05 with musl libc
Shell: Bash 5.3
Mount tool: util-linux (latest)

Build Host: $(hostname)
Built by: $(whoami)
EOF

# Create hybrid ISO with UEFI and BIOS support
log_info "Creating hybrid ISO image..."

# Generate El Torito boot catalog for BIOS
if command -v xorriso >/dev/null 2>&1; then
    log_info "Using xorriso to create ISO..."
    xorriso -as mkisofs \
        -V "ON1OS" \
        -J -joliet-long \
        -r \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "ON1OS" \
        -eltorito-boot isolinux/isolinux.bin \
        -eltorito-catalog isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e EFI/BOOT/bootx64.efi \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        -isohybrid-apm-hfsplus \
        -output "$OUTPUT_ISO" \
        "$ISO_WORK_DIR"
elif command -v genisoimage >/dev/null 2>&1; then
    log_info "Using genisoimage to create ISO..."
    genisoimage \
        -V "ON1OS" \
        -J -joliet-long \
        -r \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "ON1OS" \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -o "$OUTPUT_ISO" \
        "$ISO_WORK_DIR"
else
    echo "Error: No ISO creation tool found (xorriso or genisoimage required)"
    exit 1
fi

# Make ISO hybrid (bootable from USB)
if command -v isohybrid >/dev/null 2>&1; then
    log_info "Making ISO hybrid for USB boot..."
    
    # Check if EFI bootloader exists to determine if we need --uefi
    if [ -f "$ISO_WORK_DIR/EFI/BOOT/bootx64.efi" ]; then
        isohybrid --uefi "$OUTPUT_ISO"
        
        # Fix partition type issue - isohybrid --uefi sets partition type to 0 (Empty)
        # which causes "iso file has no partition type" boot errors
        log_info "Fixing partition type for proper boot support..."
        if command -v fdisk >/dev/null 2>&1; then
            printf "t\n1\n17\nw\n" | fdisk "$OUTPUT_ISO" >/dev/null 2>&1 || log_warn "Failed to fix partition type"
        fi
    else
        # No EFI bootloader, use standard isohybrid (partition type will be correct)
        isohybrid "$OUTPUT_ISO"
    fi
fi

# Generate checksums
log_info "Generating checksums..."
sha256sum "$OUTPUT_ISO" > "${OUTPUT_ISO}.sha256"
md5sum "$OUTPUT_ISO" > "${OUTPUT_ISO}.md5"

# Clean up
rm -rf "$ISO_WORK_DIR"

# Display results
log_info "ISO creation complete!"
echo
log_note "Output file: $OUTPUT_ISO"
log_note "Size: $(du -h "$OUTPUT_ISO" | cut -f1)"
log_note "SHA256: $(cat "${OUTPUT_ISO}.sha256" | cut -d' ' -f1)"
echo
log_info "To test the ISO:"
log_info "  qemu-system-x86_64 -m 2048 -cdrom $OUTPUT_ISO"
echo
log_info "To write to USB drive (replace /dev/sdX with your device):"
log_info "  sudo dd if=$OUTPUT_ISO of=/dev/sdX bs=4M status=progress"
echo
log_info "To verify checksums:"
log_info "  sha256sum -c ${OUTPUT_ISO}.sha256"
log_info "  md5sum -c ${OUTPUT_ISO}.md5"
