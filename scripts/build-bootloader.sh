#!/bin/bash
# Build and configure GRUB2 bootloader for on1OS

set -e

GRUB_SRC="build/downloads/grub-git"
BUILD_DIR="build/bootloader"
ISO_DIR="build/iso"

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

log_info "Building GRUB2 bootloader for on1OS..."

# Check if GRUB source exists
if [ ! -d "$GRUB_SRC" ]; then
    echo "Error: GRUB source not found. Run 'make setup' first."
    exit 1
fi

# Create build directory
mkdir -p "$BUILD_DIR"
mkdir -p "$ISO_DIR/boot/grub"

# Build GRUB2 from source
log_info "Building GRUB2 from source..."
cd "$GRUB_SRC"

# Generate build files
if [ ! -f "configure" ]; then
    log_info "Generating GRUB build files..."
    ./bootstrap
fi

# Configure GRUB with security features
if [ ! -f "Makefile" ]; then
    log_info "Configuring GRUB with security features..."
    ./configure \
        --prefix=/usr/local \
        --enable-grub-emu \
        --enable-grub-mount \
        --enable-device-mapper \
        --enable-liblzma \
        --enable-libzfs \
        --enable-grub-mkfont \
        --enable-grub-themes \
        --with-platform=pc \
        --target=x86_64 \
        --disable-werror
fi

# Build GRUB
log_info "Compiling GRUB2..."
make -j$(nproc)

# Install GRUB to temporary location
log_info "Installing GRUB2..."
sudo make install

cd ../../..

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
    linux /vmlinuz root=UUID=__ROOT_UUID__ ro \
        init=/sbin/init \
        security=apparmor \
        apparmor=1 \
        systemd.machine_id= \
        rd.luks.uuid=__LUKS_UUID__ \
        rd.luks.options=discard \
        intel_iommu=on \
        amd_iommu=on \
        iommu=force \
        slub_debug=FZP \
        mce=0 \
        page_alloc.shuffle=1 \
        pti=on \
        vsyscall=none \
        debugfs=off \
        oops=panic \
        module.sig_enforce=1 \
        lockdown=confidentiality \
        mds=full,nosmt \
        tsx=off \
        tsx_async_abort=full,nosmt \
        kvm.nx_huge_pages=force \
        nosmt=force \
        l1tf=full,force \
        spec_store_bypass_disable=on \
        spectre_v2=on \
        spectre_v2_user=on \
        rd.emergency=reboot \
        rd.shell=0 \
        selinux=0 \
        audit=1
    
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
    linux /vmlinuz root=UUID=__ROOT_UUID__ ro single \
        init=/sbin/init \
        systemd.unit=rescue.target \
        rd.luks.uuid=__LUKS_UUID__
    
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
    echo "Press any key to return to menu..."
    read
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

# Create a simple background (placeholder)
log_info "Creating theme graphics..."
# This would typically include actual PNG files, but for now we'll create placeholders
echo "Theme graphics would be generated here (background.png, select_*.png, etc.)"

# Generate GRUB fonts
log_info "Generating GRUB fonts..."
if command -v grub-mkfont >/dev/null 2>&1; then
    mkdir -p "$ISO_DIR/boot/grub/fonts"
    grub-mkfont -o "$ISO_DIR/boot/grub/fonts/unicode.pf2" /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf 2>/dev/null || \
    grub-mkfont -o "$ISO_DIR/boot/grub/fonts/unicode.pf2" /usr/share/fonts/TTF/DejaVuSans.ttf 2>/dev/null || \
    log_warn "Could not generate GRUB fonts. Install DejaVu fonts."
fi

# Create GRUB rescue image for ISO
log_info "Creating GRUB rescue image..."
mkdir -p "$BUILD_DIR/grub-rescue"

# Generate GRUB core image for BIOS boot
grub-mkimage -O i386-pc \
    -o "$BUILD_DIR/grub-rescue/core.img" \
    -p /boot/grub \
    biosdisk part_msdos part_gpt fat ext2 normal boot linux multiboot configfile \
    search search_fs_uuid search_fs_file gzio

# Copy GRUB boot image
cp /usr/local/lib/grub/i386-pc/boot.img "$BUILD_DIR/grub-rescue/"

# Generate GRUB EFI image for UEFI boot
grub-mkimage -O x86_64-efi \
    -o "$BUILD_DIR/grub-rescue/bootx64.efi" \
    -p /boot/grub \
    part_gpt part_msdos fat ext2 normal boot linux multiboot2 configfile \
    search search_fs_uuid search_fs_file gzio efi_gop efi_uga

log_info "GRUB2 bootloader build complete!"
log_info "GRUB configuration: ${ISO_DIR}/boot/grub/grub.cfg"
log_info "GRUB rescue images: ${BUILD_DIR}/grub-rescue/"
log_info "Theme: ${ISO_DIR}/boot/grub/themes/on1os/"
