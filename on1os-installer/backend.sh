#!/bin/bash
# on1OS Installer Backend
# Performs the actual installation based on configuration

set -euo pipefail

CONFIG_FILE="/tmp/on1os-install-config.json"
INSTALL_ROOT="/mnt/on1os-install"

log() {
    echo "[$(date +'%H:%M:%S')] $1" >&2
}

die() {
    echo "ERROR: $1" >&2
    exit 1
}

# Parse configuration using simple grep/sed (no jq dependency)
get_config() {
    local key="$1"
    grep "\"$key\"" "$CONFIG_FILE" | sed 's/.*": *"\([^"]*\)".*/\1/' | head -1
}

get_config_bool() {
    local key="$1"
    local value=$(grep "\"$key\"" "$CONFIG_FILE" | sed 's/.*": *\([^,}]*\).*/\1/' | head -1)
    [[ "$value" == "true" ]]
}

# Parse configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    die "Configuration file not found"
fi

TARGET_DISK=$(get_config "target_disk")
FILESYSTEM=$(get_config "filesystem")
DESKTOP=$(get_config "desktop_environment")
USERNAME=$(get_config "username")
USER_PASSWORD=$(get_config "user_password")
USER_FULLNAME=$(get_config "user_fullname")
ROOT_PASSWORD=$(get_config "root_password")
HOSTNAME=$(get_config "hostname")
LANGUAGE=$(get_config "language")
KEYBOARD=$(get_config "keyboard")
TIMEZONE=$(get_config "timezone")

# Boolean configs
INSTALL_NVIDIA=false
INSTALL_NONFREE=false
get_config_bool "install_nvidia" && INSTALL_NVIDIA=true
get_config_bool "install_nonfree" && INSTALL_NONFREE=true

# Partition disk
partition_disk() {
    log "Partitioning $TARGET_DISK"
    
    # Check if system is UEFI
    if [[ -d /sys/firmware/efi ]]; then
        IS_UEFI=true
        log "UEFI system detected"
    else
        IS_UEFI=false
        log "Legacy BIOS system detected"
    fi
    
    # Unmount any existing partitions
    umount ${TARGET_DISK}* 2>/dev/null || true
    
    # Wipe disk
    wipefs -af "$TARGET_DISK"
    
    if [[ "$IS_UEFI" == "true" ]]; then
        # UEFI partitioning
        parted -s "$TARGET_DISK" mklabel gpt
        parted -s "$TARGET_DISK" mkpart ESP fat32 1MiB 513MiB
        parted -s "$TARGET_DISK" set 1 esp on
        parted -s "$TARGET_DISK" mkpart primary ext4 513MiB 100%
        
        # Format partitions
        mkfs.fat -F32 "${TARGET_DISK}1"
        if [[ "$FILESYSTEM" == "btrfs" ]]; then
            mkfs.btrfs -f "${TARGET_DISK}2"
        elif [[ "$FILESYSTEM" == "xfs" ]]; then
            mkfs.xfs -f "${TARGET_DISK}2"
        else
            mkfs.ext4 -F "${TARGET_DISK}2"
        fi
        
        ROOT_PARTITION="${TARGET_DISK}2"
        EFI_PARTITION="${TARGET_DISK}1"
    else
        # Legacy BIOS partitioning
        parted -s "$TARGET_DISK" mklabel msdos
        parted -s "$TARGET_DISK" mkpart primary ext4 1MiB 100%
        parted -s "$TARGET_DISK" set 1 boot on
        
        # Format partition
        if [[ "$FILESYSTEM" == "btrfs" ]]; then
            mkfs.btrfs -f "${TARGET_DISK}1"
        elif [[ "$FILESYSTEM" == "xfs" ]]; then
            mkfs.xfs -f "${TARGET_DISK}1"
        else
            mkfs.ext4 -F "${TARGET_DISK}1"
        fi
        
        ROOT_PARTITION="${TARGET_DISK}1"
        EFI_PARTITION=""
    fi
}

# Mount target filesystem
mount_target() {
    log "Mounting target filesystem"
    
    mkdir -p "$INSTALL_ROOT"
    mount "$ROOT_PARTITION" "$INSTALL_ROOT"
    
    if [[ -n "$EFI_PARTITION" ]]; then
        mkdir -p "$INSTALL_ROOT/boot/efi"
        mount "$EFI_PARTITION" "$INSTALL_ROOT/boot/efi"
    fi
}

# Copy live system
copy_system() {
    log "Copying live system to target disk"
    
    # Copy everything except virtual filesystems
    rsync -axHAX \
        --exclude=/proc \
        --exclude=/sys \
        --exclude=/dev \
        --exclude=/tmp \
        --exclude=/mnt \
        --exclude=/media \
        --exclude=/run \
        / "$INSTALL_ROOT/"
    
    # Create empty directories for virtual filesystems
    mkdir -p "$INSTALL_ROOT"/{proc,sys,dev,tmp,mnt,media,run}
}

# Configure installed system
configure_system() {
    log "Configuring installed system"
    
    # Mount virtual filesystems for chroot
    mount --bind /dev "$INSTALL_ROOT/dev"
    mount --bind /proc "$INSTALL_ROOT/proc"
    mount --bind /sys "$INSTALL_ROOT/sys"
    
    # Generate fstab
    ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PARTITION")
    
    cat > "$INSTALL_ROOT/etc/fstab" << EOF
# <file system> <mount point> <type> <options> <dump> <pass>
UUID=$ROOT_UUID / $FILESYSTEM defaults 0 1
EOF

    if [[ -n "$EFI_PARTITION" ]]; then
        EFI_UUID=$(blkid -s UUID -o value "$EFI_PARTITION")
        echo "UUID=$EFI_UUID /boot/efi vfat defaults 0 2" >> "$INSTALL_ROOT/etc/fstab"
    fi

    # Configure users in chroot
    cat > "$INSTALL_ROOT/tmp/user-setup.sh" << EOF
#!/bin/bash
set -euo pipefail

# Set root password
echo "root:$ROOT_PASSWORD" | chpasswd

# Remove live user and create new user
userdel -r live 2>/dev/null || true
useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev "$USERNAME"
echo "$USERNAME:$USER_PASSWORD" | chpasswd

# Set user's full name
chfn -f "$USER_FULLNAME" "$USERNAME"

# Configure sudo
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME

# Set hostname
echo "$HOSTNAME" > /etc/hostname

# Configure hosts
cat > /etc/hosts << EOL
127.0.0.1   localhost
127.0.1.1   $HOSTNAME
EOL

# Configure locales
echo "$LANGUAGE.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LANGUAGE.UTF-8" > /etc/locale.conf

# Configure keyboard
echo "XKBLAYOUT=\"$KEYBOARD\"" > /etc/default/keyboard

# Set timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
echo "$TIMEZONE" > /etc/timezone

# Remove installer from installed system
rm -rf /usr/local/share/on1os-installer
rm -f /usr/share/applications/on1os-installer.desktop
rm -f /home/*/Desktop/on1os-installer.desktop

# Disable autologin
rm -f /etc/lightdm/lightdm.conf.d/12-autologin.conf

EOF

    chmod +x "$INSTALL_ROOT/tmp/user-setup.sh"
    chroot "$INSTALL_ROOT" /tmp/user-setup.sh
    rm -f "$INSTALL_ROOT/tmp/user-setup.sh"
}

# Install bootloader
install_bootloader() {
    log "Installing GRUB bootloader"
    
    # Ensure GRUB packages are installed
    chroot "$INSTALL_ROOT" apt-get update
    if [[ -d /sys/firmware/efi ]]; then
        chroot "$INSTALL_ROOT" apt-get install -y grub-efi-amd64 grub-efi-amd64-signed
    else
        chroot "$INSTALL_ROOT" apt-get install -y grub-pc
    fi
    
    # Install GRUB in chroot
    cat > "$INSTALL_ROOT/tmp/grub-setup.sh" << EOF
#!/bin/bash
set -euo pipefail

# Check if system is UEFI
if [[ -d /sys/firmware/efi ]]; then
    # UEFI installation
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=on1OS
else
    # Legacy BIOS installation
    grub-install $TARGET_DISK
fi

# Update GRUB configuration
update-grub

EOF

    chmod +x "$INSTALL_ROOT/tmp/grub-setup.sh"
    chroot "$INSTALL_ROOT" /tmp/grub-setup.sh
    rm -f "$INSTALL_ROOT/tmp/grub-setup.sh"
}

# Cleanup and unmount
cleanup() {
    log "Cleaning up and unmounting filesystems"
    
    # Unmount virtual filesystems
    umount "$INSTALL_ROOT/dev" 2>/dev/null || true
    umount "$INSTALL_ROOT/proc" 2>/dev/null || true
    umount "$INSTALL_ROOT/sys" 2>/dev/null || true
    
    # Unmount target filesystems
    if [[ -n "$EFI_PARTITION" ]]; then
        umount "$INSTALL_ROOT/boot/efi" 2>/dev/null || true
    fi
    
    umount "$INSTALL_ROOT" 2>/dev/null || true
    
    log "Installation completed successfully!"
}

# Set up cleanup trap
trap cleanup EXIT

# Main installation process
main() {
    partition_disk
    mount_target
    copy_system
    configure_system
    install_bootloader
}

main "$@"
