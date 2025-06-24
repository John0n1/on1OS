#!/bin/bash
# Setup build environment for on1OS
# Repository: https://github.com/John0n1/on1OS

set -e

# Ensure non-interactive mode
export DEBIAN_FRONTEND=noninteractive

# Source shared libraries
source "scripts/lib/config.sh"
source "scripts/lib/log.sh"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   log_error "This script should not be run as root"
   exit 1
fi

log_info "Setting up on1OS build environment..."
log_info "Repository: https://github.com/John0n1/on1OS"
log_info "Target versions:"
log_info "  - Kernel: linux-hardened ${KERNEL_VERSION:-6.14.9-hardened1}"
log_info "  - Buildroot: ${BUILDROOT_VERSION:-2025.05}"
log_info "  - Systemd: ${SYSTEMD_VERSION:-256.16}"
log_info "  - dracut-ng: ${DRACUT_VERSION:-100}"
log_info "  - Bash: ${BASH_VERSION:-5.3}"

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    log_error "Cannot detect Linux distribution"
    exit 1
fi

# Install dependencies based on distribution
case $DISTRO in
    ubuntu|debian)
        log_info "Installing dependencies for Ubuntu/Debian..."
        sudo apt-get update
        sudo apt-get install -y \
            build-essential \
            gcc-multilib \
            g++-multilib \
            libc6-dev \
            make \
            libncurses5-dev \
            libssl-dev \
            bc \
            flex \
            bison \
            libelf-dev \
            rsync \
            wget \
            curl \
            git \
            cpio \
            unzip \
            device-tree-compiler \
            u-boot-tools \
            dosfstools \
            mtools \
            parted \
            squashfs-tools \
            genisoimage \
            xorriso \
            syslinux \
            isolinux \
            dracut \
            dracut-core \
            plymouth-themes \
            tpm2-tools \
            cryptsetup \
            python3 \
            python3-dev \
            python3-setuptools \
            pkg-config \
            libkmod-dev \
            autotools-dev \
            autoconf \
            automake \
            libtool \
            gettext \
            gettext-base \
            autopoint \
            fonts-dejavu-core \
            grub-pc-bin \
            grub-efi-amd64-bin \
            grub-common \
            libfuse3-dev \
            libfuse-dev \
            fuse3 \
            libzfslinux-dev
        ;;
    fedora|centos|rhel)
        log_info "Installing dependencies for Fedora/CentOS/RHEL..."
        sudo dnf groupinstall -y "Development Tools"
        sudo dnf install -y \
            gcc \
            gcc-c++ \
            glibc-devel \
            make \
            ncurses-devel \
            openssl-devel \
            bc \
            flex \
            bison \
            elfutils-libelf-devel \
            rsync \
            wget \
            curl \
            git \
            cpio \
            unzip \
            dtc \
            u-boot-tools \
            dosfstools \
            mtools \
            parted \
            squashfs-tools \
            genisoimage \
            xorriso \
            syslinux \
            dracut \
            tpm2-tools \
            cryptsetup \
            python3 \
            python3-devel \
            python3-setuptools \
            pkg-config \
            autotools \
            autoconf \
            automake \
            libtool \
            gettext \
            gettext-devel \
            grub2-tools \
            grub2-efi-x64 \
            fuse3-devel \
            fuse-devel \
            fuse3 \
            fuse
        ;;
    arch)
        log_info "Installing dependencies for Arch Linux..."
        sudo pacman -Sy --needed \
            base-devel \
            linux-headers \
            ncurses \
            openssl \
            bc \
            flex \
            bison \
            libelf \
            rsync \
            wget \
            curl \
            git \
            cpio \
            unzip \
            dtc \
            uboot-tools \
            dosfstools \
            mtools \
            parted \
            squashfs-tools \
            cdrtools \
            libisoburn \
            syslinux \
            dracut \
            tpm2-tools \
            cryptsetup \
            python \
            python-setuptools \
            pkg-config \
            autoconf \
            automake \
            libtool \
            gettext \
            grub \
            fuse3 \
            fuse2
        ;;
    *)
        log_error "Unsupported distribution: $DISTRO"
        log_info "Please install build dependencies manually and run again."
        exit 1
        ;;
esac

# Create directory structure
log_info "Creating directory structure..."
mkdir -p build/{kernel,rootfs,initramfs,iso,downloads}
mkdir -p tools
mkdir -p config
mkdir -p docs

# Download sources
log_info "Downloading source packages..."

# Create downloads directory
cd build/downloads

# Download kernel source
if [ ! -f "linux-hardened-${KERNEL_VERSION}.tar.gz" ]; then
    log_info "Downloading linux-hardened kernel ${KERNEL_VERSION}..."
    wget https://github.com/anthraxx/linux-hardened/archive/refs/tags/${KERNEL_VERSION}.tar.gz -O linux-hardened-${KERNEL_VERSION}.tar.gz
fi

# Download Buildroot
if [ ! -f "buildroot-2025.05.tar.gz" ]; then
    log_info "Downloading Buildroot 2025.05..."
    wget https://buildroot.org/downloads/buildroot-2025.05.tar.gz
fi

# Download GRUB (latest stable from Git)
if [ ! -d "grub-git" ]; then
    log_info "Cloning GRUB latest stable from Git..."
    git clone --depth 1 --branch master https://git.savannah.gnu.org/git/grub.git grub-git
fi

# Download dracut-ng
if [ ! -f "dracut-ng-100.tar.gz" ]; then
    log_info "Downloading dracut-ng Release 100..."
    wget https://github.com/dracut-ng/dracut-ng/archive/refs/tags/100.tar.gz -O dracut-ng-100.tar.gz
fi

# Download systemd
if [ ! -f "systemd-256.16.tar.gz" ]; then
    log_info "Downloading systemd v256.16..."
    wget https://github.com/systemd/systemd/archive/refs/tags/v256.16.tar.gz -O systemd-256.16.tar.gz
fi

# Download Bash
if [ ! -f "bash-${BASH_VERSION}.tar.gz" ]; then
    log_info "Downloading Bash ${BASH_VERSION}..."
    wget https://ftp.gnu.org/gnu/bash/bash-${BASH_VERSION}.tar.gz
fi

# Download util-linux (latest)
if [ ! -d "util-linux-git" ]; then
    log_info "Cloning util-linux latest from Git..."
    git clone --depth 1 https://github.com/util-linux/util-linux.git util-linux-git
fi

cd ../..

# Extract sources
log_info "Extracting source packages..."
cd build

# Extract kernel
if [ ! -d "linux-hardened-${KERNEL_VERSION#v}" ]; then
    tar -xzf downloads/linux-hardened-${KERNEL_VERSION}.tar.gz
fi

# Extract Buildroot
if [ ! -d "buildroot-2025.05" ]; then
    tar -xzf downloads/buildroot-2025.05.tar.gz
fi

# Extract dracut-ng
if [ ! -d "dracut-ng-100" ]; then
    tar -xzf downloads/dracut-ng-100.tar.gz
fi

# Extract systemd
if [ ! -d "systemd-256.16" ]; then
    tar -xzf downloads/systemd-256.16.tar.gz
fi

# Extract Bash
if [ ! -d "bash-${BASH_VERSION}" ]; then
    tar -xzf downloads/bash-${BASH_VERSION}.tar.gz
fi

# GRUB and util-linux are already cloned as Git repositories

cd ..

log_info "Build environment setup complete!"
log_info "Next steps:"
log_info "  1. Run 'make config' to configure build options"
log_info "  2. Run 'make all' to build the complete system"
log_info "  3. Run 'make iso' to create installation media"
