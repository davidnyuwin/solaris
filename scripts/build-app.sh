#!/bin/bash
# scripts/build-app.sh

# Colors for terminal styling
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
YELLOW='\033[0;33m'
BLUE='\033[0;34m'

# Versioning and Metadata
APP_NAME="Solaris"
APP_VERSION="0.10.0-beta"
BUNDLE_ID="com.davidnguyen.solaris"

# Parse arguments
SIGN_REQUESTED=false
ZIP_REQUESTED=false

for arg in "$@"; do
    if [ "$arg" = "--sign" ]; then
        SIGN_REQUESTED=true
    elif [ "$arg" = "--zip" ]; then
        ZIP_REQUESTED=true
    fi
done

echo "☄️ Solaris Native App Bundler"
echo "Version: $APP_VERSION"
echo "----------------------------------------"

# 1. Compile release binary
echo -e "${BLUE}Compiling $APP_NAME in release mode...${NC}"
swift build -c release
BUILD_STATUS=$?

if [ $BUILD_STATUS -ne 0 ]; then
    echo -e "${RED}ERROR: Swift build compilation failed.${NC}"
    exit 1
fi
echo -e "${GREEN}Build succeeded!${NC}"
echo ""

# 2. Establish app bundle directories
DIST_DIR="dist"
APP_BUNDLE_NAME="${APP_NAME}.app"
APP_BUNDLE_PATH="$DIST_DIR/$APP_BUNDLE_NAME"
CONTENTS_PATH="$APP_BUNDLE_PATH/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
RESOURCES_PATH="$CONTENTS_PATH/Resources"

echo -e "${BLUE}Structuring local app bundle...${NC}"
rm -rf "$APP_BUNDLE_PATH"
mkdir -p "$MACOS_PATH"
mkdir -p "$RESOURCES_PATH"

# 3. Compile high-resolution macOS .icns file
SRC_ICON="docs/screenshots/app-icon.png"
ICONSET_DIR="dist/Solaris.iconset"
ICNS_FILE="$RESOURCES_PATH/Solaris.icns"

if [ -f "$SRC_ICON" ]; then
    echo -e "${BLUE}Generating macOS multi-resolution .icns file...${NC}"
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"
    
    if command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
        # Resize PNG sizes using native sips tool, forcing PNG format
        sips -s format png -z 16 16     "$SRC_ICON" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null 2>&1
        sips -s format png -z 32 32     "$SRC_ICON" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null 2>&1
        sips -s format png -z 32 32     "$SRC_ICON" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null 2>&1
        sips -s format png -z 64 64     "$SRC_ICON" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null 2>&1
        sips -s format png -z 128 128   "$SRC_ICON" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null 2>&1
        sips -s format png -z 256 256   "$SRC_ICON" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null 2>&1
        sips -s format png -z 256 256   "$SRC_ICON" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null 2>&1
        sips -s format png -z 512 512   "$SRC_ICON" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null 2>&1
        sips -s format png -z 512 512   "$SRC_ICON" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null 2>&1
        sips -s format png -z 1024 1024 "$SRC_ICON" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null 2>&1
        
        # Assemble multi-size PNGs into .icns bundle
        iconutil -c icns "$ICONSET_DIR" -o "$ICNS_FILE"
        ICON_GEN_STATUS=$?
        
        if [ $ICON_GEN_STATUS -eq 0 ] && [ -f "$ICNS_FILE" ]; then
            echo -e "${GREEN}App icon created successfully at Resources/Solaris.icns!${NC}"
        else
            echo -e "${YELLOW}Warning: iconutil failed to compile .icns file. App will use default icon.${NC}"
        fi
        
        # Clean up temporary iconset files
        rm -rf "$ICONSET_DIR"
    else
        echo -e "${YELLOW}Warning: sips or iconutil commands are not available. Skipping icon compilation.${NC}"
    fi
else
    echo -e "${YELLOW}Warning: Source icon $SRC_ICON not found. Skipping icon compilation.${NC}"
fi
echo ""

# 4. Locate compiled binary and copy it
BINARY_SOURCE=""
if [ -f ".build/release/Solaris" ]; then
    BINARY_SOURCE=".build/release/Solaris"
elif [ -f ".build/arm64-apple-macosx/release/Solaris" ]; then
    BINARY_SOURCE=".build/arm64-apple-macosx/release/Solaris"
else
    # Search fallback
    BINARY_SOURCE=$(find .build -type f -name "Solaris" -path "*/release/*" | head -n 1)
fi

if [ -z "$BINARY_SOURCE" ] || [ ! -f "$BINARY_SOURCE" ]; then
    echo -e "${RED}ERROR: Could not locate compiled release binary under .build/release directory.${NC}"
    exit 1
fi

echo "Copying binary from $BINARY_SOURCE to $MACOS_PATH/Solaris..."
cp "$BINARY_SOURCE" "$MACOS_PATH/Solaris"
chmod +x "$MACOS_PATH/Solaris"

# 5. Generate Info.plist containing CFBundleIconFile
INFO_PLIST_PATH="$CONTENTS_PATH/Info.plist"
echo "Generating Info.plist at $INFO_PLIST_PATH..."

cat > "$INFO_PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Solaris</string>
    <key>CFBundleIconFile</key>
    <string>Solaris</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSBackgroundOnly</key>
    <false/>
</dict>
</plist>
EOF

# Verify plist structure using plutil if available
if command -v plutil >/dev/null 2>&1; then
    plutil -lint "$INFO_PLIST_PATH" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Info.plist validation passed!${NC}"
    else
        echo -e "${YELLOW}Warning: Info.plist failed local lint validation.${NC}"
    fi
fi
echo ""

# 6. Optional Ad-hoc codesigning
if [ "$SIGN_REQUESTED" = true ]; then
    echo -e "${BLUE}Performing ad-hoc codesigning (--sign)...${NC}"
    if command -v codesign >/dev/null 2>&1; then
        codesign --force --deep --sign - "$APP_BUNDLE_PATH"
        SIGN_STATUS=$?
        
        if [ $SIGN_STATUS -eq 0 ]; then
            echo -e "${GREEN}Ad-hoc codesigning succeeded!${NC}"
            echo ""
            echo "Verifying signature..."
            codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE_PATH"
            echo ""
            echo "Signature details:"
            codesign -dv --verbose=4 "$APP_BUNDLE_PATH"
        else
            echo -e "${RED}ERROR: Codesigning failed.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}ERROR: codesign tool is not available, but --sign was explicitly requested.${NC}"
        exit 1
    fi
    echo ""
fi

# 7. Optional ZIP packaging
if [ "$ZIP_REQUESTED" = true ]; then
    ZIP_FILENAME="dist/${APP_NAME}-v${APP_VERSION}.zip"
    echo -e "${BLUE}Creating local ZIP artifact (--zip): $ZIP_FILENAME...${NC}"
    
    if command -v ditto >/dev/null 2>&1; then
        ditto -c -k --keepParent "$APP_BUNDLE_PATH" "$ZIP_FILENAME"
        ZIP_STATUS=$?
    else
        # Fallback to standard zip utility
        cd dist || exit 1
        zip -q -r "${APP_NAME}-v${APP_VERSION}.zip" "$APP_BUNDLE_NAME"
        ZIP_STATUS=$?
        cd .. || exit 1
    fi
    
    if [ $ZIP_STATUS -eq 0 ] && [ -f "$ZIP_FILENAME" ]; then
        echo -e "${GREEN}ZIP artifact created successfully at $ZIP_FILENAME!${NC}"
    else
        echo -e "${RED}ERROR: Failed to create ZIP artifact.${NC}"
        exit 1
    fi
    echo ""
fi

echo -e "${GREEN}SUCCESS: Local app bundle packaged successfully!${NC}"
echo -e "Location: ${YELLOW}$APP_BUNDLE_PATH${NC}"
if [ "$ZIP_REQUESTED" = true ]; then
    echo -e "ZIP Release: ${YELLOW}dist/${APP_NAME}-v${APP_VERSION}.zip${NC}"
fi
echo -e "To launch immediately, run: ${BLUE}open $APP_BUNDLE_PATH${NC}"
echo "----------------------------------------"
exit 0
