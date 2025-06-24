#!/bin/bash
# Build and configure GRUB2 bootloader for on1OS

set -e

# Ensure non-interactive mode
export DEBIAN_FRONTEND=noninteractive

# Source shared libraries
source "scripts/lib/config.sh"
source "scripts/lib/log.sh"
source "scripts/lib/graphics.sh"

GRUB_SRC="build/downloads/grub-git"
BUILD_DIR="build/bootloader"
ISO_DIR="build/iso"

log_info "Building GRUB2 bootloader for on1OS..."

# Check if GRUB source exists
if [ ! -d "$GRUB_SRC" ]; then
    echo "Error: GRUB source not found. Run 'make setup' first."
    exit 1
fi

# Create build directory
mkdir -p "$BUILD_DIR"
mkdir -p "$ISO_DIR/boot/grub"

# Use system GRUB tools instead of building from source
log_info "Using system GRUB tools..."

# Check if system GRUB tools are available
if ! command -v grub-mkimage >/dev/null 2>&1; then
    log_error "System GRUB tools not found. Installing GRUB..."
    sudo apt-get update
    sudo apt-get install -y grub2-common grub-pc-bin grub-efi-amd64-bin
fi

# Ensure GRUB directories exist
sudo mkdir -p /usr/lib/grub/i386-pc
sudo mkdir -p /usr/lib/grub/x86_64-efi

log_info "System GRUB tools are ready."

# Create GRUB configuration
log_info "Creating GRUB configuration..."
cat > "$ISO_DIR/boot/grub/grub.cfg" << 'EOF'
# GRUB Configuration for on1OS
# Security-focused bootloader configuration

# Set default boot option
set default=0
set timeout=10

# Enable security features
set superusers="root"
password_pbkdf2 root grub.pbkdf2.sha512.100000.8A7F8B5C3D2E1F0A9B8C7D6E5F4A3B2C1D0E9F8A7B6C5D4E3F2A1B0C9D8E7F6A5B4C3D2E1F0A9B8C7D6E5F4A3B2C

# Load modules
insmod part_gpt
insmod part_msdos
insmod fat
insmod ext2
insmod normal
insmod boot
insmod linux
insmod multiboot2
insmod chain
insmod configfile
insmod search
insmod search_fs_uuid
insmod search_fs_file
insmod gfxterm
insmod gfxterm_background
insmod gfxterm_menu
insmod test
insmod cat
insmod png
insmod font

# Set graphics mode
if loadfont /boot/grub/fonts/unicode.pf2 ; then
    set gfxmode=auto
    insmod gfxterm
    set locale_dir=$prefix/locale
    set lang=en_US
    insmod gettext
fi
terminal_output gfxterm

# Set theme
set theme=/boot/grub/themes/on1os/theme.txt

# Security settings
set check_signatures=enforce

menuentry 'on1OS (Default)' --class on1os --class gnu-linux --class gnu --class os {
    recordfail
    load_video
    gfxmode $gfxmode
    insmod gzio
    insmod part_gpt
    insmod ext2
    
    # Load kernel
    echo 'Loading on1OS kernel...'
    linux /vmlinuz root=live:CDLABEL=ON1OS init=/sbin/init ro rd.live.image quiet splash
    
    # Load initramfs
    echo 'Loading initial ramdisk...'
    initrd /initrd.img
}

menuentry 'on1OS (Recovery Mode)' --class on1os --class gnu-linux --class gnu --class os --users "" {
    recordfail
    load_video
    gfxmode $gfxmode
    insmod gzio
    insmod part_gpt
    insmod ext2
    
    echo 'Loading on1OS kernel (recovery)...'
    linux /vmlinuz root=live:CDLABEL=ON1OS init=/sbin/init ro rd.live.image single
    
    echo 'Loading initial ramdisk...'
    initrd /initrd.img
}

menuentry 'on1OS (Debug Mode)' --class on1os --class gnu-linux --class gnu --class os --users "" {
    recordfail
    load_video
    gfxmode "$gfxmode"
    insmod gzio
    insmod part_gpt
    insmod ext2
    
    echo 'Loading on1OS kernel (debug)...'
    linux /vmlinuz root=live:CDLABEL=ON1OS init=/sbin/init ro rd.live.image rd.debug rd.shell console=tty0 console=ttyS0,115200 debug earlyprintk=ttyS0,115200
    
    echo 'Loading initial ramdisk...'
    initrd /initrd.img
}

menuentry 'Memory Test (memtest86+)' --users "" {
    linux16 /boot/memtest86+.bin
}

menuentry 'System Information' --users "" {
    echo "on1OS - Hardened Linux Distribution"
    echo "Kernel: 6.14.9-hardened1"
    echo "Init: systemd v256.16"
    echo "Bootloader: GRUB 2 (latest)"
    echo ""
    echo "Security Features:"
    echo "- TPM2 support"
    echo "- LUKS2 encryption"
    echo "- Secure Boot ready"
    echo "- Kernel hardening"
    echo "- Control Flow Integrity"
    echo ""
    # Removed interactive read for automated builds
}

menuentry 'Reboot' --users "" {
    reboot
}

menuentry 'Shutdown' --users "" {
    halt
}
EOF

# Create GRUB theme
log_info "Creating GRUB theme..."
mkdir -p "$ISO_DIR/boot/grub/themes/on1os"

cat > "$ISO_DIR/boot/grub/themes/on1os/theme.txt" << 'EOF'
# on1OS GRUB Theme
desktop-image: "background.png"
desktop-color: "#000000"
title-color: "#ffffff"
title-font: "DejaVu Sans Bold 16"
title-text: "on1OS Security Distribution"

terminal-box: "terminal_box_*.png"
terminal-font: "DejaVu Sans Mono 12"

+ boot_menu {
    left = 25%
    top = 30%
    width = 50%
    height = 40%
    item_font = "DejaVu Sans 14"
    item_color = "#ffffff"
    selected_item_color = "#000000"
    selected_item_pixmap_style = "select_*.png"
    item_height = 32
    item_spacing = 16
    icon_width = 32
    icon_height = 32
    item_icon_space = 8
}

+ label {
    top = 80%
    left = 0
    width = 100%
    height = 20
    text = "Press 'e' to edit commands, 'c' for command-line"
    align = "center"
    color = "#888888"
    font = "DejaVu Sans 12"
}
EOF

# Copy custom graphics if available
log_info "Creating theme graphics..."
setup_grub_theme_graphics "$ISO_DIR/boot/grub/themes/on1os"

# Generate GRUB fonts
log_info "Generating GRUB fonts..."
mkdir -p "$ISO_DIR/boot/grub/fonts"
if command -v grub-mkfont >/dev/null 2>&1; then
    grub-mkfont -o "$ISO_DIR/boot/grub/fonts/unicode.pf2" /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf 2>/dev/null || \
    grub-mkfont -o "$ISO_DIR/boot/grub/fonts/unicode.pf2" /usr/share/fonts/TTF/DejaVuSans.ttf 2>/dev/null || \
    log_warn "Could not generate GRUB fonts. Install DejaVu fonts."
else
    log_warn "grub-mkfont not available. Install GRUB development tools."
fi

# Create GRUB rescue image for ISO
log_info "Creating GRUB rescue image..."
mkdir -p "$BUILD_DIR/grub-rescue"

# Generate GRUB core image for BIOS boot
log_info "Generating GRUB BIOS core image..."
grub-mkimage -O i386-pc \
    -o "$BUILD_DIR/grub-rescue/core.img" \
    -p /boot/grub \
    -d /usr/lib/grub/i386-pc \
    biosdisk part_msdos part_gpt fat ext2 normal boot linux multiboot configfile \
    search search_fs_uuid search_fs_file gzio

# Copy GRUB boot image
if [ -f "/usr/lib/grub/i386-pc/boot.img" ]; then
    cp /usr/lib/grub/i386-pc/boot.img "$BUILD_DIR/grub-rescue/"
elif [ -f "/usr/local/lib/grub/i386-pc/boot.img" ]; then
    cp /usr/local/lib/grub/i386-pc/boot.img "$BUILD_DIR/grub-rescue/"
else
    log_warn "GRUB boot.img not found, but continuing..."
fi

# Generate GRUB EFI image for UEFI boot (skip if EFI modules not available)
log_info "Checking for GRUB EFI support..."
if [ -d "/usr/lib/grub/x86_64-efi" ]; then
    log_info "Generating GRUB EFI image..."
    grub-mkimage -O x86_64-efi \
        -o "$BUILD_DIR/grub-rescue/bootx64.efi" \
        -p /boot/grub \
        -d /usr/lib/grub/x86_64-efi \
        part_gpt part_msdos fat ext2 normal boot linux multiboot2 configfile \
        search search_fs_uuid search_fs_file gzio efi_gop efi_uga
else
    log_warn "GRUB EFI modules not available, skipping EFI image generation."
fi

log_info "GRUB2 bootloader build complete!"
log_info "GRUB configuration: ${ISO_DIR}/boot/grub/grub.cfg"
log_info "GRUB rescue images: ${BUILD_DIR}/grub-rescue/"
log_info "Theme: ${ISO_DIR}/boot/grub/themes/on1os/"
