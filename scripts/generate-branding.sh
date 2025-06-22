#!/bin/bash
# Generate branding assets for on1OS from animation frames

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

ASSETS_DIR="assets/branding"
ANIMATION_DIR="$ASSETS_DIR/boot-animation"
BUILD_DIR="build"
ISO_DIR="$BUILD_DIR/iso"

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

log_info "Generating branding assets for on1OS..."

# Check if animation frames exist
if [ ! -d "$ANIMATION_DIR" ]; then
    echo "Error: Animation directory not found at $ANIMATION_DIR"
    exit 1
fi

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v convert >/dev/null 2>&1; then
        missing_deps+=("imagemagick")
    fi
    
    if ! command -v ffmpeg >/dev/null 2>&1; then
        missing_deps+=("ffmpeg")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_warn "Installing missing dependencies: ${missing_deps[*]}"
        sudo apt-get update
        sudo apt-get install -y "${missing_deps[@]}"
    fi
}

check_dependencies

# Create output directories
mkdir -p "$BUILD_DIR/branding/plymouth"
mkdir -p "$BUILD_DIR/branding/grub"
mkdir -p "$BUILD_DIR/branding/wallpapers"

# Count animation frames
FRAME_COUNT=$(ls -1 "$ANIMATION_DIR"/frame-*.png | wc -l)
log_info "Found $FRAME_COUNT animation frames"

# Generate Plymouth theme
log_info "Creating Plymouth boot theme..."
mkdir -p "$BUILD_DIR/branding/plymouth/on1os"

# Create Plymouth theme configuration
cat > "$BUILD_DIR/branding/plymouth/on1os/on1os.plymouth" << EOF
[Plymouth Theme]
Name=on1OS
Description=on1OS Hardened Linux Boot Animation
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/on1os
ScriptFile=/usr/share/plymouth/themes/on1os/on1os.script
EOF

# Generate Plymouth script for animation
cat > "$BUILD_DIR/branding/plymouth/on1os/on1os.script" << 'EOF'
# on1OS Plymouth Boot Animation Script

# Screen dimensions
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();

# Load logo
logo_image = Image("logo.png");
logo_sprite = Sprite(logo_image);

# Center logo
logo_sprite.SetX((screen_width - logo_image.GetWidth()) / 2);
logo_sprite.SetY((screen_height - logo_image.GetHeight()) / 2 - 50);

# Animation frames
frame_count = 80;
current_frame = 0;
frame_images = [];

# Load all animation frames
for (i = 1; i <= frame_count; i++) {
    frame_file = "frame-" + sprintf("%04d", i) + ".png";
    frame_images[i-1] = Image(frame_file);
}

# Create animation sprite
if (frame_count > 0) {
    animation_sprite = Sprite(frame_images[0]);
    animation_sprite.SetX((screen_width - frame_images[0].GetWidth()) / 2);
    animation_sprite.SetY((screen_height - frame_images[0].GetHeight()) / 2 + 50);
}

# Animation function
fun animate() {
    if (frame_count > 0) {
        current_frame = (current_frame + 1) % frame_count;
        animation_sprite.SetImage(frame_images[current_frame]);
    }
}

# Progress bar
progress_bar.image = Image.Text("", 1, 1, 1);
progress_bar.sprite = Sprite();
progress_bar.sprite.SetPosition(screen_width / 2 - 100, screen_height - 80, 10000);

# Update progress
fun progress_callback(duration, progress) {
    if (progress_bar.image.GetWidth() != Math.Int(progress * 200)) {
        progress_bar.image = Image.Text("█" * Math.Int(progress * 50), 0.5, 0.8, 1);
        progress_bar.sprite.SetImage(progress_bar.image);
    }
}

Plymouth.SetBootProgressFunction(progress_callback);

# Main refresh function
fun refresh_callback() {
    animate();
}

Plymouth.SetRefreshFunction(refresh_callback);

# Password dialog (if needed)
fun display_normal_callback() {
    global.status = "normal";
}

fun display_password_callback(prompt, bullets) {
    global.status = "password";
    password_image = Image.Text(prompt + ": " + "*" * bullets, 1, 1, 1);
    password_sprite = Sprite(password_image);
    password_sprite.SetX((screen_width - password_image.GetWidth()) / 2);
    password_sprite.SetY(screen_height - 150);
}

Plymouth.SetDisplayNormalFunction(display_normal_callback);
Plymouth.SetDisplayPasswordFunction(display_password_callback);
EOF

# Copy animation frames to Plymouth theme directory
log_info "Copying animation frames for Plymouth..."
cp "$ANIMATION_DIR"/*.png "$BUILD_DIR/branding/plymouth/on1os/"

# Generate GRUB background from first frame
log_info "Creating GRUB background..."
convert "$ANIMATION_DIR/frame-0001.png" -resize 1024x768^ -gravity center -extent 1024x768 \
    "$BUILD_DIR/branding/grub/background.png"

# Create GRUB selection images
log_info "Creating GRUB menu elements..."
convert -size 300x32 xc:"rgba(64,128,255,128)" "$BUILD_DIR/branding/grub/select_c.png"
convert -size 8x32 xc:"rgba(64,128,255,128)" "$BUILD_DIR/branding/grub/select_w.png"
convert -size 8x32 xc:"rgba(64,128,255,128)" "$BUILD_DIR/branding/grub/select_e.png"

# Create terminal box elements
convert -size 300x200 xc:"rgba(0,0,0,180)" "$BUILD_DIR/branding/grub/terminal_box_c.png"
convert -size 8x200 xc:"rgba(0,0,0,180)" "$BUILD_DIR/branding/grub/terminal_box_w.png"
convert -size 8x200 xc:"rgba(0,0,0,180)" "$BUILD_DIR/branding/grub/terminal_box_e.png"
convert -size 300x8 xc:"rgba(0,0,0,180)" "$BUILD_DIR/branding/grub/terminal_box_n.png"
convert -size 300x8 xc:"rgba(0,0,0,180)" "$BUILD_DIR/branding/grub/terminal_box_s.png"

# Create different resolution wallpapers
log_info "Creating desktop wallpapers..."
for res in "1920x1080" "1366x768" "1280x720" "1024x768"; do
    convert "$ANIMATION_DIR/frame-0001.png" -resize ${res}^ -gravity center -extent $res \
        "$BUILD_DIR/branding/wallpapers/on1os-${res}.png"
done

# Create an animated GIF from frames (for testing/preview)
log_info "Creating preview animation..."
convert -delay 5 "$ANIMATION_DIR"/frame-*.png "$BUILD_DIR/branding/on1os-boot-animation.gif"

# Create a video version for modern boot systems
log_info "Creating video animation..."
ffmpeg -y -framerate 20 -pattern_type glob -i "$ANIMATION_DIR/frame-*.png" \
    -c:v libx264 -pix_fmt yuv420p -movflags +faststart \
    "$BUILD_DIR/branding/on1os-boot-animation.mp4" >/dev/null 2>&1

# Generate installation script for Plymouth theme
cat > "$BUILD_DIR/branding/install-plymouth-theme.sh" << 'EOF'
#!/bin/bash
# Install on1OS Plymouth theme

set -e

THEME_DIR="/usr/share/plymouth/themes/on1os"

# Create theme directory
if sudo mkdir -p "$THEME_DIR" 2>/dev/null; then
    # Copy theme files
    sudo cp -r on1os/* "$THEME_DIR/" 2>/dev/null || log_warn "Failed to copy some theme files"
    
    # Install theme
    if command -v plymouth-set-default-theme >/dev/null 2>&1; then
        sudo plymouth-set-default-theme on1os 2>/dev/null || echo "Warning: Could not set Plymouth theme"
    else
        echo "Warning: plymouth-set-default-theme command not found"
    fi
    
    # Update initramfs
    if command -v update-initramfs >/dev/null 2>&1; then
        sudo update-initramfs -u 2>/dev/null || echo "Warning: Failed to update initramfs"
    else
        log_info "update-initramfs not available (this is normal on some systems)"
    fi
    
    echo "on1OS Plymouth theme installation completed!"
else
    echo "Warning: Failed to create Plymouth theme directory, insufficient permissions"
    echo "Plymouth theme installation skipped."
fi
echo "Reboot to see the new boot animation."
EOF

chmod +x "$BUILD_DIR/branding/install-plymouth-theme.sh"

# Generate summary report
cat > "$BUILD_DIR/branding/README.md" << EOF
# on1OS Branding Assets

This directory contains all generated branding assets for on1OS.

## Generated Assets

### Plymouth Boot Theme
- Location: \`plymouth/on1os/\`
- Files: ${FRAME_COUNT} animation frames + logo
- Install: Run \`install-plymouth-theme.sh\`

### GRUB Graphics
- Background: \`grub/background.png\` (1024x768)
- Menu elements: \`grub/select_*.png\`
- Terminal box: \`grub/terminal_box_*.png\`

### Wallpapers
- Multiple resolutions in \`wallpapers/\`
- Resolutions: 1920x1080, 1366x768, 1280x720, 1024x768

### Preview/Testing
- Animated GIF: \`on1os-boot-animation.gif\`
- Video: \`on1os-boot-animation.mp4\`

## Source
- Original frames: ${FRAME_COUNT} PNG files (1080x512)
- Logo: logo.png (760x376)

## Installation

1. **Plymouth Theme**: Run the install script as root
2. **GRUB Graphics**: Copy files to GRUB theme directory
3. **Wallpapers**: Use in desktop environment

Generated on: $(date)
EOF

log_info "Branding assets generation complete!"
echo
log_note "Generated assets:"
log_note "  - Plymouth theme: $BUILD_DIR/branding/plymouth/on1os/"
log_note "  - GRUB graphics: $BUILD_DIR/branding/grub/"
log_note "  - Wallpapers: $BUILD_DIR/branding/wallpapers/"
log_note "  - Preview: $BUILD_DIR/branding/on1os-boot-animation.gif"
echo
log_info "To integrate with build system:"
log_info "  1. GRUB: Copy graphics to ISO boot theme"
log_info "  2. Plymouth: Include theme in initramfs"
log_info "  3. Wallpapers: Add to default desktop"
