#!/usr/bin/env bash
set -euo pipefail

# Shared configuration sourcing for on1OS build system
#
# Usage: source scripts/lib/config.sh

# Source build configuration files if they exist
source_config() {
    if [ -f "config/defaults.conf" ]; then
        source "config/defaults.conf"
    fi
    if [ -f "config/build.conf" ]; then
        source "config/build.conf"
    fi
}

# Call the function when this library is sourced
source_config