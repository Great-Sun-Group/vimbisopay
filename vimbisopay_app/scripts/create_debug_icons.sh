#!/bin/bash
#
# Script to create debug-specific app icons with a red badge
# This script requires ImageMagick to be installed
# Install with: brew install imagemagick (macOS) or apt-get install imagemagick (Linux)
#

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick is not installed. Please install it first."
    echo "macOS: brew install imagemagick"
    echo "Linux: apt-get install imagemagick"
    exit 1
fi

# Base directories
MAIN_RES_DIR="android/app/src/main/res"
DEBUG_RES_DIR="android/app/src/debug/res"

# Create debug resource directories if they don't exist
mkdir -p "$DEBUG_RES_DIR/mipmap-hdpi"
mkdir -p "$DEBUG_RES_DIR/mipmap-mdpi"
mkdir -p "$DEBUG_RES_DIR/mipmap-xhdpi"
mkdir -p "$DEBUG_RES_DIR/mipmap-xxhdpi"
mkdir -p "$DEBUG_RES_DIR/mipmap-xxxhdpi"

# Process each density
for DENSITY in hdpi mdpi xhdpi xxhdpi xxxhdpi; do
    echo "Processing $DENSITY icons..."
    
    # Source and destination paths
    SRC_ICON="$MAIN_RES_DIR/mipmap-$DENSITY/ic_launcher.png"
    DEST_ICON="$DEBUG_RES_DIR/mipmap-$DENSITY/ic_launcher.png"
    
    # Check if source icon exists
    if [ ! -f "$SRC_ICON" ]; then
        echo "Warning: Source icon $SRC_ICON not found. Skipping."
        continue
    fi
    
    # Get image dimensions
    DIMENSIONS=$(identify -format "%wx%h" "$SRC_ICON")
    WIDTH=$(echo $DIMENSIONS | cut -d'x' -f1)
    HEIGHT=$(echo $DIMENSIONS | cut -d'x' -f2)
    
    # Calculate badge size (30% of the icon size)
    BADGE_SIZE=$(( WIDTH * 30 / 100 ))
    
    # Calculate badge position (bottom right corner)
    X_POS=$(( WIDTH - BADGE_SIZE ))
    Y_POS=$(( HEIGHT - BADGE_SIZE ))
    
    # Create a debug badge (red circle with "D" text)
    echo "Adding debug badge to $DEST_ICON..."
    convert "$SRC_ICON" \
        \( -size "${BADGE_SIZE}x${BADGE_SIZE}" \
           -background red \
           -fill white \
           -gravity center \
           label:"D" \
           -alpha set \
           -virtual-pixel transparent \
           -distort SRT 0 \
           -gravity southeast \
        \) \
        -gravity southeast \
        -composite \
        "$DEST_ICON"
    
    echo "Created debug icon: $DEST_ICON"
done

echo "Debug icons created successfully!"
echo "The debug app will now use these icons when built in debug mode."
