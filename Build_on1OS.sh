#!/bin/bash
#
# Build_on1OS.sh - A Clean and Robust Build Script for on1OS
#
# This script builds the on1OS hardened Linux distribution:
# - Sets up the build environment and dependencies
# - Creates a minimal Debian-based live root filesystem
# - Downloads and compiles a hardened Linux kernel
# - Generates branding assets (Plymouth, GRUB) with live animation
# - Builds initramfs with dracut
# - Creates a bootable hybrid ISO image
# - Includes a comprehensive GUI installer
#
# Usage:
#   ./Build_on1OS.sh <command>
#
# Commands:
#   all         - Run the entire build process from setup to ISO creation
#   setup       - Install dependencies and download/extract sources
#   rootfs      - Build the Debian-based live root filesystem
#   branding    - Generate branding assets (boot splash, themes)
#   kernel      - Build the hardened Linux kernel
#   initramfs   - Build the initramfs
#   iso         - Create the final bootable ISO image
#   clean       - Remove intermediate build artifacts
#   distclean   - Remove all build, dist, and source files
#   help        - Display this help message
#

set -euo pipefail

# --- CONFIGURABLE VARIABLES ---

# Project Info
readonly PROJECT_NAME="on1OS"
readonly PROJECT_VERSION="0.1.0-alpha"

# Component Versions
readonly KERNEL_TAG="v6.14.11-hardened1"
readonly KERNEL_VERSION="${KERNEL_TAG#v}"

# Build Configuration
readonly TARGET_ARCH="x86_64"
readonly MAKE_JOBS=$(nproc)

# Directory Structure
readonly WORK_DIR="$PWD"
readonly SOURCES_DIR="$WORK_DIR/sources"
readonly BUILD_DIR="$WORK_DIR/build"
readonly DIST_DIR="$WORK_DIR/dist"
readonly CONFIG_DIR="$WORK_DIR/config"
readonly DOWNLOADS_DIR="$SOURCES_DIR/downloads"
readonly KERNEL_SRC_DIR="$SOURCES_DIR/linux-kernel"
readonly ISO_STAGING_DIR="$BUILD_DIR/iso-staging"
readonly ROOTFS_DIR="$BUILD_DIR/rootfs"
readonly BRANDING_ASSETS_DIR="$WORK_DIR/assets/branding"

# --- GLOBAL VARIABLES & HELPERS ---

readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "\n${BLUE}>>> $1${NC}"; }

export DEBIAN_FRONTEND=noninteractive
trap 'cleanup' EXIT
cleanup() {
    if mountpoint -q /mnt/iso 2>/dev/null; then
        log_warn "Unmounting stale ISO mount point..."
        sudo umount /mnt/iso
    fi
}

# --- CORE FUNCTIONS ---

check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root. It will use 'sudo' when needed."
        exit 1
    fi
}

install_dependencies() {
    log_step "Checking and installing dependencies..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update
        sudo apt-get install -y \
            build-essential gcc-multilib g++-multilib make libncurses-dev libssl-dev bc \
            flex bison libelf-dev rsync wget curl git cpio unzip device-tree-compiler \
            dosfstools mtools parted squashfs-tools xorriso fakeroot \
            dracut-core tpm2-tools cryptsetup \
            python3-dev python3-setuptools pkg-config libkmod-dev autoconf automake \
            libtool gettext autopoint fonts-dejavu-core grub-pc-bin grub-efi-amd64-bin \
            grub2-common libfuse3-dev imagemagick ffmpeg debootstrap
    elif command -v dnf &>/dev/null; then
        sudo dnf groupinstall -y "Development Tools"
        sudo dnf install -y \
            gcc-c++ glibc-devel make ncurses-devel openssl-devel bc flex bison \
            elfutils-libelf-devel rsync wget curl git cpio unzip dtc \
            dosfstools mtools parted squashfs-tools xorriso fakeroot dracut \
            tpm2-tools cryptsetup python3-devel python3-setuptools pkgconf-pkg-config \
            autoconf automake libtool gettext-devel grub2-tools grub2-efi-x64-modules \
            fuse3-devel ImageMagick ffmpeg debootstrap
    elif command -v pacman &>/dev/null; then
        sudo pacman -Syu --needed --noconfirm \
            base-devel ncurses openssl bc flex bison libelf rsync wget curl git cpio \
            unzip dtc dosfstools mtools parted squashfs-tools libisoburn fakeroot \
            dracut tpm2-tools cryptsetup python python-setuptools \
            pkg-config autoconf automake libtool gettext grub fuse3 imagemagick ffmpeg debootstrap
    else
        log_error "Unsupported Linux distribution. Please install dependencies manually."
        exit 1
    fi
    log_info "Dependencies are satisfied."
}

setup_environment() {
    log_step "Setting up build environment and sources..."
    mkdir -p "$SOURCES_DIR" "$DOWNLOADS_DIR" "$BUILD_DIR" "$ISO_STAGING_DIR" "$ROOTFS_DIR" "$DIST_DIR" "$CONFIG_DIR"

    if [ ! -f "$CONFIG_DIR/kernel.config" ]; then
        log_warn "Kernel config not found at '$CONFIG_DIR/kernel.config'. Creating a known-good default."
        cat > "$CONFIG_DIR/kernel.config" <<'EOF'
# on1OS Kernel Configuration with Desktop Support
CONFIG_64BIT=y
CONFIG_X86_64=y
CONFIG_KERNEL_LZO=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_CGROUPS=y
CONFIG_INOTIFY_USER=y
CONFIG_SIGNALFD=y
CONFIG_TIMERFD=y
CONFIG_EPOLL=y
CONFIG_NET=y
CONFIG_SYSFS=y
CONFIG_PROC_FS=y
CONFIG_FHANDLE=y

# Security features
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
CONFIG_STACKPROTECTOR_STRONG=y
CONFIG_STRICT_KERNEL_RWX=y
CONFIG_STRICT_MODULE_RWX=y
CONFIG_X86_SMAP=y
CONFIG_X86_SMEP=y
CONFIG_X86_UMIP=y

# Crypto support
CONFIG_CRYPTO=y
CONFIG_CRYPTO_AES=y
CONFIG_CRYPTO_XTS=y
CONFIG_CRYPTO_SHA256=y

# Block devices and filesystems
CONFIG_MD=m
CONFIG_BLK_DEV_DM=m
CONFIG_DM_CRYPT=m
CONFIG_EXT4_FS=m
CONFIG_ISO9660_FS=m
CONFIG_SQUASHFS=m
CONFIG_SQUASHFS_XZ=m
CONFIG_VFAT_FS=m
CONFIG_TMPFS=y
CONFIG_DEVPTS_FS=y

# Hardware support
CONFIG_PCI=y
CONFIG_SATA_AHCI=m
CONFIG_ATA=m
CONFIG_SCSI=m
CONFIG_BLK_DEV_SD=m
CONFIG_BLK_DEV_SR=m
CONFIG_BLK_DEV_LOOP=m

# USB support
CONFIG_USB=m
CONFIG_USB_XHCI_HCD=m
CONFIG_USB_EHCI_HCD=m
CONFIG_USB_OHCI_HCD=m
CONFIG_USB_STORAGE=m
CONFIG_USB_UAS=m

# Graphics support for desktop
CONFIG_FB=m
CONFIG_FB_VESA=m
CONFIG_DRM=m
CONFIG_DRM_I915=m
CONFIG_DRM_RADEON=m
CONFIG_DRM_AMDGPU=m
CONFIG_DRM_NOUVEAU=m
CONFIG_VGA_CONSOLE=y
CONFIG_FRAMEBUFFER_CONSOLE=m

# Input devices
CONFIG_INPUT=m
CONFIG_INPUT_KEYBOARD=m
CONFIG_INPUT_MOUSE=m
CONFIG_KEYBOARD_ATKBD=m
CONFIG_MOUSE_PS2=m
CONFIG_INPUT_TOUCHSCREEN=m

# Sound support
CONFIG_SOUND=m
CONFIG_SND=m
CONFIG_SND_HDA_INTEL=m
CONFIG_SND_HDA_CODEC_REALTEK=m
CONFIG_SND_HDA_CODEC_ANALOG=m
CONFIG_SND_HDA_CODEC_SIGMATEL=m
CONFIG_SND_HDA_CODEC_VIA=m
CONFIG_SND_HDA_CODEC_HDMI=m
CONFIG_SND_USB_AUDIO=m

# Network support
CONFIG_ETHERNET=m
CONFIG_NET_VENDOR_INTEL=m
CONFIG_E1000=m
CONFIG_E1000E=m
CONFIG_IGB=m
CONFIG_NET_VENDOR_REALTEK=m
CONFIG_8139TOO=m
CONFIG_R8169=m
CONFIG_NET_VENDOR_BROADCOM=m
CONFIG_B44=m
CONFIG_BNX2=m
CONFIG_TIGON3=m

# Wireless support
CONFIG_WLAN=m
CONFIG_CFG80211=m
CONFIG_MAC80211=m
CONFIG_IWLWIFI=m
CONFIG_RT2X00=m
CONFIG_ATH9K=m
CONFIG_B43=m

# EFI support
CONFIG_EFI=y
CONFIG_EFI_STUB=y
CONFIG_EFI_VARS=y

# Live boot support
CONFIG_OVERLAY_FS=y
EOF
    fi

    cd "$DOWNLOADS_DIR"
    local KERNEL_TARBALL="linux-hardened-${KERNEL_TAG}.tar.gz"
    if [[ ! -f "$KERNEL_TARBALL" ]]; then
        log_info "Downloading linux-hardened kernel ${KERNEL_TAG}..."
        wget "https://github.com/anthraxx/linux-hardened/archive/refs/tags/${KERNEL_TAG}.tar.gz" -O "$KERNEL_TARBALL"
    fi

    if [[ ! -f "$KERNEL_SRC_DIR/.extracted" ]]; then
        log_info "Extracting kernel source to '$KERNEL_SRC_DIR'..."
        mkdir -p "$KERNEL_SRC_DIR"
        tar --strip-components=1 -xzf "$DOWNLOADS_DIR/$KERNEL_TARBALL" -C "$KERNEL_SRC_DIR"
        touch "$KERNEL_SRC_DIR/.extracted"
    fi

    cd "$WORK_DIR"
    log_info "Build environment setup is complete."
}

build_rootfs() {
    log_step "Building minimal Debian-based live root filesystem..."
    
    if ! command -v debootstrap &>/dev/null && [ ! -x /usr/sbin/debootstrap ]; then
        log_error "debootstrap is not installed. Please install it first."
        exit 1
    fi
    
    if [[ -d "$ROOTFS_DIR" ]]; then
        log_info "Removing existing rootfs..."
        sudo rm -rf "$ROOTFS_DIR"
    fi
    mkdir -p "$ROOTFS_DIR"
    
    log_info "Running debootstrap to create minimal Debian base system..."
    sudo /usr/sbin/debootstrap --arch=amd64 --variant=minbase bookworm "$ROOTFS_DIR" http://deb.debian.org/debian/
    
    # Prepare single chroot setup script
    cat > "$BUILD_DIR/chroot-setup.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Update package database
apt-get update

# Configure locales early to avoid warnings
echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
apt-get install -y --no-install-recommends locales
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Install essential packages for live system
apt-get install -y --no-install-recommends \
    systemd systemd-sysv systemd-resolved \
    keyboard-configuration console-setup sudo network-manager \
    openssh-client curl wget vim nano less man-db bash-completion ca-certificates \
    dbus udev kmod firmware-linux-free \
    xorg openbox lxterminal pcmanfm \
    lightdm lightdm-gtk-greeter \
    pulseaudio alsa-utils \
    fonts-dejavu fonts-liberation \
    python3 python3-tk python3-pil python3-pil.imagetk \
    libnotify-bin notification-daemon zenity \
    policykit-1 policykit-1-gnome

# Enable essential services (ignore failures in chroot)
systemctl enable systemd-networkd || true
systemctl enable systemd-resolved || true
systemctl enable lightdm || true

# Create live user
useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev live
echo 'live:live' | chpasswd
echo 'live ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/live

# Configure autologin for live user
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/12-autologin.conf <<EOL
[Seat:*]
autologin-user=live
autologin-user-timeout=0
EOL

# Set hostname
echo "on1os" > /etc/hostname

# Configure hosts
cat > /etc/hosts <<EOL
127.0.0.1   localhost
127.0.1.1   on1os
EOL

# Clean up
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF

    chmod +x "$BUILD_DIR/chroot-setup.sh"
    
    # Mount chroot filesystems with proper cleanup
    trap 'cleanup_chroot_mounts' EXIT
    sudo mount --bind /dev "$ROOTFS_DIR/dev"
    sudo mount --bind /proc "$ROOTFS_DIR/proc"
    sudo mount --bind /sys "$ROOTFS_DIR/sys"
    
    # Copy and run setup script in chroot
    sudo cp "$BUILD_DIR/chroot-setup.sh" "$ROOTFS_DIR/tmp/"
    sudo chroot "$ROOTFS_DIR" /bin/bash /tmp/chroot-setup.sh
    sudo rm "$ROOTFS_DIR/tmp/chroot-setup.sh"
    
    # Copy installer files from on1os-installer directory
    if [[ -d "$WORK_DIR/on1os-installer" ]]; then
        log_info "Installing on1OS installer..."
        sudo mkdir -p "$ROOTFS_DIR/usr/local/share/on1os-installer"
        sudo cp -r "$WORK_DIR/on1os-installer/." "$ROOTFS_DIR/usr/local/share/on1os-installer/"
        
        # Make scripts executable
        sudo chmod +x "$ROOTFS_DIR/usr/local/share/on1os-installer/gui.py"
        sudo chmod +x "$ROOTFS_DIR/usr/local/share/on1os-installer/backend.sh"
        
        # Copy GUI as main installer executable
        sudo cp "$ROOTFS_DIR/usr/local/share/on1os-installer/gui.py" "$ROOTFS_DIR/usr/local/bin/on1os-installer"
        sudo chmod +x "$ROOTFS_DIR/usr/local/bin/on1os-installer"
        
        # Copy backend script
        sudo cp "$ROOTFS_DIR/usr/local/share/on1os-installer/backend.sh" "$ROOTFS_DIR/usr/local/bin/on1os-installer-backend"
        sudo chmod +x "$ROOTFS_DIR/usr/local/bin/on1os-installer-backend"
        
        # Create desktop entry
        sudo cp "$ROOTFS_DIR/usr/local/share/on1os-installer/on1os-installer.desktop" "$ROOTFS_DIR/usr/share/applications/"
        
        # Create desktop shortcut for live user
        sudo mkdir -p "$ROOTFS_DIR/home/live/Desktop"
        sudo cp "$ROOTFS_DIR/usr/share/applications/on1os-installer.desktop" "$ROOTFS_DIR/home/live/Desktop/"
        sudo chmod +x "$ROOTFS_DIR/home/live/Desktop/on1os-installer.desktop"
        
        # Set up Openbox autostart with welcome notification
        sudo mkdir -p "$ROOTFS_DIR/home/live/.config/openbox"
        sudo tee "$ROOTFS_DIR/home/live/.config/openbox/autostart" > /dev/null <<'EON'
#!/bin/bash
# Start PCManFM desktop manager
pcmanfm --desktop &

# Show welcome notification
sleep 5 && notify-send "Welcome to on1OS" "Double-click the 'Install on1OS' icon on the desktop to install the system to your hard drive." &
EON
        sudo chmod +x "$ROOTFS_DIR/home/live/.config/openbox/autostart"
    else
        log_warn "on1os-installer directory not found. Installer will not be included."
    fi
    
    # Set proper ownership for live user home directory
    sudo chroot "$ROOTFS_DIR" chown -R live:live /home/live
    
    cleanup_chroot_mounts
    trap - EXIT
    
    log_info "Debian-based live rootfs build complete."
}

cleanup_chroot_mounts() {
    log_info "Cleaning up chroot mount points..."
    sudo umount "$ROOTFS_DIR/dev" 2>/dev/null || true
    sudo umount "$ROOTFS_DIR/proc" 2>/dev/null || true
    sudo umount "$ROOTFS_DIR/sys" 2>/dev/null || true
}

generate_branding() {
    log_step "Generating branding assets..."
    local THEME_NAME="${PROJECT_NAME,,}"
    local BRANDING_BUILD_DIR="$BUILD_DIR/branding"
    mkdir -p "$BRANDING_BUILD_DIR/plymouth/$THEME_NAME" "$BRANDING_BUILD_DIR/grub"

    if [[ ! -d "$BRANDING_ASSETS_DIR/boot-animation" ]]; then
        log_warn "Branding source directory not found. Skipping custom branding."
        return
    fi
    
    local ANIMATION_DIR="$BRANDING_ASSETS_DIR/boot-animation"
    local FRAME_COUNT
    FRAME_COUNT=$(find "$ANIMATION_DIR" -name 'frame-*.png' 2>/dev/null | wc -l)
    
    if [[ "$FRAME_COUNT" -eq 0 ]]; then
        log_warn "No animation frames found. Skipping branding generation."
        return
    fi
    
    log_info "Found $FRAME_COUNT animation frames. Verifying sequence..."
    for i in $(seq 0 $((FRAME_COUNT - 1))); do
        FRAME_NUM=$(printf "%04d" "$i")
        if [ ! -f "$ANIMATION_DIR/frame-$FRAME_NUM.png" ]; then
            log_error "Animation frame sequence is broken. Missing frame-$FRAME_NUM.png. Aborting."
            exit 1
        fi
    done
    log_info "Animation frame sequence is valid."

    # Generate GRUB background
    convert "$ANIMATION_DIR/frame-0000.png" -resize 1024x768^ -gravity center -extent 1024x768 \
        "$BRANDING_BUILD_DIR/grub/background.png"
    
    # Copy animation frames for Plymouth
    cp "$ANIMATION_DIR"/frame-*.png "$BRANDING_BUILD_DIR/plymouth/$THEME_NAME/"
    
    # Create Plymouth theme configuration
    cat > "$BRANDING_BUILD_DIR/plymouth/$THEME_NAME/$THEME_NAME.plymouth" << EOF
[Plymouth Theme]
Name=${PROJECT_NAME}
Description=${PROJECT_NAME} Boot Animation
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/${THEME_NAME}
ScriptFile=/usr/share/plymouth/themes/${THEME_NAME}/${THEME_NAME}.script
EOF

    # Create Plymouth script
    cat > "$BRANDING_BUILD_DIR/plymouth/$THEME_NAME/$THEME_NAME.script" << EOF
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();
frame_count = ${FRAME_COUNT};
frame_images = [];

for (i = 0; i < frame_count; i++) {
    frame_images[i] = Image("frame-" + i.ToPaddedString(4) + ".png");
}

animation_sprite = Sprite(frame_images[0]);
animation_sprite.SetX((screen_width - frame_images[0].GetWidth()) / 2);
animation_sprite.SetY((screen_height - frame_images[0].GetHeight()) / 2);

current_frame = 0;

fun refresh_callback() {
    current_frame = (current_frame + 1) % frame_count;
    animation_sprite.SetImage(frame_images[current_frame]);
}

Plymouth.SetRefreshFunction(refresh_callback);
EOF
    
    log_info "Branding assets generated successfully."
}

build_kernel() {
    log_step "Building hardened Linux kernel ${KERNEL_TAG}..."
    if [[ -f "$ISO_STAGING_DIR/boot/vmlinuz" ]]; then
        log_info "Kernel image already exists. Skipping build."
        return
    fi

    cd "$KERNEL_SRC_DIR"
    log_info "Cleaning kernel source tree..."
    make mrproper
    
    log_info "Using kernel configuration from '$CONFIG_DIR/kernel.config'..."
    cp "$CONFIG_DIR/kernel.config" .config
    make olddefconfig

    log_info "Compiling kernel (this may take a while)..."
    make -j"$MAKE_JOBS" bzImage modules

    log_info "Installing kernel modules to rootfs..."
    sudo make INSTALL_MOD_PATH="$ROOTFS_DIR" modules_install
    
    log_info "Generating module dependency files..."
    sudo depmod -a -b "$ROOTFS_DIR" "$KERNEL_VERSION"
    
    # Create modules.order if it doesn't exist (for kernels with only built-in modules)
    if [[ ! -f "$ROOTFS_DIR/lib/modules/$KERNEL_VERSION/modules.order" ]]; then
        sudo touch "$ROOTFS_DIR/lib/modules/$KERNEL_VERSION/modules.order"
    fi

    log_info "Copying kernel image to ISO staging area..."
    mkdir -p "$ISO_STAGING_DIR/boot"
    cp arch/x86/boot/bzImage "$ISO_STAGING_DIR/boot/vmlinuz"

    cd "$WORK_DIR"
    log_info "Kernel build complete."
}

build_initramfs() {
    log_step "Building initramfs with dracut..."
    if [[ -f "$ISO_STAGING_DIR/boot/initrd.img" ]]; then
        log_info "Initramfs image already exists. Skipping build."
        return
    fi
    
    if [ ! -d "$ROOTFS_DIR/lib/modules/${KERNEL_VERSION}" ]; then
        log_error "Kernel modules not found. Build kernel first."
        exit 1
    fi
    
    local THEME_NAME="${PROJECT_NAME,,}"
    local DRACUT_MODULE_DIR="$BUILD_DIR/dracut_modules"
    local THEME_MODULE_DIR="$DRACUT_MODULE_DIR/99${THEME_NAME}-theme"
    rm -rf "$THEME_MODULE_DIR"

    # Create Plymouth theme module for dracut if branding exists
    if [[ -d "$BUILD_DIR/branding/plymouth/$THEME_NAME" ]]; then
        log_info "Creating Plymouth theme module for dracut..."
        mkdir -p "$THEME_MODULE_DIR"
        
        cat > "$THEME_MODULE_DIR/module-setup.sh" <<-EOF
#!/bin/bash
check() {
    [ -f "\$moddir/${THEME_NAME}.plymouth" ] || return 255
    return 0
}

install() {
    inst_dir "/usr/share/plymouth/themes/${THEME_NAME}"
    inst_simple "\$moddir/${THEME_NAME}.plymouth" "/usr/share/plymouth/themes/${THEME_NAME}/${THEME_NAME}.plymouth"
    inst_simple "\$moddir/${THEME_NAME}.script" "/usr/share/plymouth/themes/${THEME_NAME}/${THEME_NAME}.script"
    
    for i in \$moddir/frame-*.png; do
        inst_simple "\$i" "/usr/share/plymouth/themes/${THEME_NAME}/\$(basename \$i)"
    done
    
    mkdir -p "\$dracutsysrootdir/etc/plymouth"
    echo "Theme=${THEME_NAME}" > "\$dracutsysrootdir/etc/plymouth/plymouthd.conf"
}
EOF
        
        cp -r "$BUILD_DIR/branding/plymouth/$THEME_NAME"/* "$THEME_MODULE_DIR/"
    fi

    log_info "Running dracut to create initramfs..."
    sudo dracut \
        --kver "$KERNEL_VERSION" \
        --force --no-hostonly \
        --add "plymouth" \
        "$ISO_STAGING_DIR/boot/initrd.img"

    sudo chown "$(whoami)":"$(whoami)" "$ISO_STAGING_DIR/boot/initrd.img"
    log_info "Initramfs build complete."
}

create_iso() {
    log_step "Creating bootable ISO image..."
    local OUTPUT_ISO="$DIST_DIR/${PROJECT_NAME}-${PROJECT_VERSION}-${TARGET_ARCH}.iso"
    local GRUB_DIR="$ISO_STAGING_DIR/boot/grub"
    local THEME_NAME="${PROJECT_NAME,,}"
    local KERNEL_PATH="/boot/vmlinuz"
    local INITRD_PATH="/boot/initrd.img"

    # Verify required components exist
    for f in "$ISO_STAGING_DIR$KERNEL_PATH" "$ISO_STAGING_DIR$INITRD_PATH"; do
        [[ -f "$f" ]] || { log_error "Required component '$f' not found."; exit 1; }
    done

    mkdir -p "$GRUB_DIR/themes/$THEME_NAME"
    
    log_info "Creating GRUB configuration and theme..."
    cat > "$GRUB_DIR/grub.cfg" << EOF
set default=0
set timeout=10
set theme=/boot/grub/themes/${THEME_NAME}/theme.txt

if loadfont /boot/grub/fonts/unicode.pf2 ; then
    set gfxmode=auto
    insmod all_video
    insmod gfxterm
    terminal_output gfxterm
fi

menuentry '${PROJECT_NAME} (Live)' --class on1os {
    linux ${KERNEL_PATH} boot=live components quiet splash
    initrd ${INITRD_PATH}
}

menuentry '${PROJECT_NAME} (Debug Mode)' --class on1os {
    linux ${KERNEL_PATH} boot=live components rd.debug rd.shell
    initrd ${INITRD_PATH}
}

menuentry 'Reboot' { reboot; }
menuentry 'Shutdown' { halt; }
EOF

    cat > "$GRUB_DIR/themes/$THEME_NAME/theme.txt" << 'EOF'
desktop-image: "background.png"
desktop-color: "#000000"
title-color: "#ffffff"
title-font: "DejaVu Sans Bold 16"
+ boot_menu { left=25% top=30% width=50% height=40% item_font="DejaVu Sans 14" item_color="#cccccc" selected_item_color="#000000" selected_item_background_color="#ffffff" }
EOF

    # Copy branding background if available
    if [[ -f "$BUILD_DIR/branding/grub/background.png" ]]; then
        cp "$BUILD_DIR/branding/grub/background.png" "$GRUB_DIR/themes/$THEME_NAME/background.png"
    fi
    
    # Generate GRUB font
    mkdir -p "$GRUB_DIR/fonts"
    grub-mkfont --output="$GRUB_DIR/fonts/unicode.pf2" /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf 2>/dev/null || true

    log_info "Creating live filesystem (squashfs)..."
    mkdir -p "$ISO_STAGING_DIR/live"
    
    if [ -z "$(ls -A "$ROOTFS_DIR")" ]; then
        log_error "Rootfs directory is empty. Cannot create ISO."
        exit 1
    fi
    
    fakeroot mksquashfs "$ROOTFS_DIR" "$ISO_STAGING_DIR/live/filesystem.squashfs" -comp xz -b 1048576 -noappend

    log_info "Generating hybrid ISO image with grub-mkrescue..."
    grub-mkrescue -o "$OUTPUT_ISO" "$ISO_STAGING_DIR"

    # Generate checksum
    sha256sum "$OUTPUT_ISO" > "${OUTPUT_ISO}.sha256"
    
    log_step "ISO Creation Complete!"
    echo -e "  ${GREEN}Output File:${NC} $OUTPUT_ISO"
    echo -e "  ${GREEN}Size:${NC} $(du -h "$OUTPUT_ISO" | cut -f1)"
    echo -e "  ${GREEN}SHA256:${NC} $(cut -d' ' -f1 "${OUTPUT_ISO}.sha256")"
}

clean() {
    log_step "Cleaning intermediate build artifacts..."
    if [ -d "$BUILD_DIR" ]; then
        sudo rm -rf "$BUILD_DIR"
        log_info "Build directory '$BUILD_DIR' has been removed."
    fi
}

distclean() {
    clean
    log_step "Cleaning all generated files (build, dist, and sources)..."
    if [ -d "$DIST_DIR" ]; then
        rm -rf "$DIST_DIR"
        log_info "Distribution directory '$DIST_DIR' has been removed."
    fi
    if [ -d "$SOURCES_DIR" ]; then
        rm -rf "$SOURCES_DIR"
        log_info "Sources directory '$SOURCES_DIR' has been removed."
    fi
    log_info "Full cleanup complete."
}

show_help() {
    cat <<- EOF
	Usage:
	  ./Build_on1OS.sh <command>

	Commands:
	  all         - Run the entire build process from setup to ISO creation
	  setup       - Install dependencies and download/extract sources
	  rootfs      - Build the Debian-based live root filesystem
	  branding    - Generate branding assets (boot splash, themes)
	  kernel      - Build the hardened Linux kernel
	  initramfs   - Build the initramfs
	  iso         - Create the final bootable ISO image
	  clean       - Remove intermediate build artifacts
	  distclean   - Remove all build, dist, and source files
	  help        - Display this help message
	EOF
}

main() {
    check_root
    local command="${1:-all}"

    case "$command" in
        all)
            log_step "Starting full build of ${PROJECT_NAME}..."
            install_dependencies
            setup_environment
            build_rootfs
            generate_branding
            build_kernel
            build_initramfs
            create_iso
            log_step "Build finished successfully!"
            ;;
        setup)
            install_dependencies
            setup_environment
            ;;
        rootfs)
            build_rootfs
            ;;
        branding)
            generate_branding
            ;;
        kernel)
            build_kernel
            ;;
        initramfs)
            build_initramfs
            ;;
        iso)
            create_iso
            ;;
        clean)
            clean
            ;;
        distclean)
            distclean
            ;;
        help)
            show_help
            ;;
        *)
            log_error "Unknown command: '$command'"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
