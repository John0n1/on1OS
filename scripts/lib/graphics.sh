#!/bin/bash
# Shared graphics generation functions for on1OS build system
#
# Usage: source scripts/lib/graphics.sh

# Create GRUB theme directory and ensure it exists
ensure_grub_theme_dir() {
    local theme_dir="$1"
    mkdir -p "$theme_dir"
}

# Generate GRUB menu and terminal graphics using ImageMagick
generate_grub_menu_graphics() {
    local dest_dir="$1"
    
    if ! command -v convert >/dev/null 2>&1; then
        log_warn "ImageMagick convert command not found, skipping graphics generation"
        return 1
    fi
    
    log_info "Creating GRUB menu elements..."
    
    # Selection elements
    convert -size 300x32 xc:"rgba(64,128,255,128)" "$dest_dir/select_c.png"
    convert -size 8x32 xc:"rgba(64,128,255,128)" "$dest_dir/select_w.png"
    convert -size 8x32 xc:"rgba(64,128,255,128)" "$dest_dir/select_e.png"
    convert -size 300x8 xc:"rgba(64,128,255,128)" "$dest_dir/select_n.png"
    convert -size 300x8 xc:"rgba(64,128,255,128)" "$dest_dir/select_s.png"
    convert -size 8x8 xc:"rgba(64,128,255,128)" "$dest_dir/select_nw.png"
    convert -size 8x8 xc:"rgba(64,128,255,128)" "$dest_dir/select_ne.png"
    convert -size 8x8 xc:"rgba(64,128,255,128)" "$dest_dir/select_sw.png"
    convert -size 8x8 xc:"rgba(64,128,255,128)" "$dest_dir/select_se.png"
    
    # Terminal box elements
    convert -size 300x200 xc:"rgba(0,0,0,180)" "$dest_dir/terminal_box_c.png"
    convert -size 8x200 xc:"rgba(0,0,0,180)" "$dest_dir/terminal_box_w.png"
    convert -size 8x200 xc:"rgba(0,0,0,180)" "$dest_dir/terminal_box_e.png"
    convert -size 300x8 xc:"rgba(0,0,0,180)" "$dest_dir/terminal_box_n.png"
    convert -size 300x8 xc:"rgba(0,0,0,180)" "$dest_dir/terminal_box_s.png"
}

# Generate fallback GRUB graphics using ImageMagick
generate_grub_fallback_graphics() {
    local theme_dir="$1"
    
    if ! command -v convert >/dev/null 2>&1; then
        log_warn "ImageMagick convert command not found, skipping fallback graphics"
        return 1
    fi
    
    log_info "Creating fallback GRUB graphics..."
    
    # Background
    convert -size 1024x768 xc:"#000033" "$theme_dir/background.png" 2>/dev/null || true
    
    # Generate menu graphics
    generate_grub_menu_graphics "$theme_dir"
}

# Copy custom branding graphics if available
copy_custom_grub_graphics() {
    local source_dir="$1"
    local dest_dir="$2"
    
    if [ -d "$source_dir" ]; then
        log_info "Using custom on1OS graphics..."
        cp "$source_dir"/*.png "$dest_dir/" 2>/dev/null || log_warn "Failed to copy some custom graphics"
        return 0
    else
        log_warn "Custom graphics not found. Run './scripts/generate-branding.sh' first."
        return 1
    fi
}

# Setup GRUB theme with graphics (custom or fallback)
setup_grub_theme_graphics() {
    local theme_dir="$1"
    local custom_graphics_dir="${2:-build/branding/grub}"
    
    ensure_grub_theme_dir "$theme_dir"
    
    if ! copy_custom_grub_graphics "$custom_graphics_dir" "$theme_dir"; then
        generate_grub_fallback_graphics "$theme_dir"
    fi
}