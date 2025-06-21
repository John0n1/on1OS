# Makefile for on1OS Build System
# Security-focused Linux distribution with hardening features

# Build configuration
BUILD_DIR := build
KERNEL_DIR := $(BUILD_DIR)/kernel
ROOTFS_DIR := $(BUILD_DIR)/rootfs
INITRAMFS_DIR := $(BUILD_DIR)/initramfs
ISO_DIR := $(BUILD_DIR)/iso
TOOLS_DIR := tools

# Version configuration
KERNEL_VERSION := v6.14.11-hardened1
BUILDROOT_VERSION := 2025.05
GRUB_VERSION := latest
SYSTEMD_VERSION := 256.16
DRACUT_VERSION := 100
BASH_VERSION := 5.2
UTIL_LINUX_VERSION := latest

# Target architecture
ARCH := x86_64

.PHONY: all setup clean kernel rootfs initramfs bootloader iso help

all: setup kernel rootfs initramfs bootloader iso
	@echo "on1OS build complete!"

help:
	@echo "on1OS Build System"
	@echo "=================="
	@echo "Available targets:"
	@echo "  setup      - Install build dependencies and download sources"
	@echo "  kernel     - Build hardened Linux kernel"
	@echo "  rootfs     - Build minimal root filesystem with Buildroot"
	@echo "  initramfs  - Generate dracut-based initramfs"
	@echo "  bootloader - Build and configure GRUB2 bootloader"
	@echo "  iso        - Create bootable ISO image"
	@echo "  clean      - Clean build artifacts"
	@echo "  help       - Show this help message"

setup:
	@echo "Setting up build environment..."
	./scripts/setup-build-env.sh

kernel:
	@echo "Building hardened kernel..."
	./scripts/build-kernel.sh

rootfs:
	@echo "Building root filesystem..."
	./scripts/build-rootfs.sh

initramfs:
	@echo "Generating initramfs..."
	./scripts/build-initramfs.sh

bootloader:
	@echo "Building bootloader..."
	./scripts/build-bootloader.sh

iso:
	@echo "Creating ISO image..."
	./scripts/create-iso.sh

config:
	@echo "Configuring build options..."
	./scripts/configure.sh

clean:
	@echo "Cleaning build directory..."
	rm -rf $(BUILD_DIR)
	@echo "Build directory cleaned."

distclean: clean
	@echo "Cleaning downloads and tools..."
	rm -rf downloads $(TOOLS_DIR)
	@echo "Complete cleanup finished."
