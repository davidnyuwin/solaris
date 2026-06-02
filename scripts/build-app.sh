#!/bin/bash
# scripts/build-app.sh

# Colors for terminal styling
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
YELLOW='\033[0;33m'
BLUE='\033[0;34m'

echo "☄️ Solaris Native App Bundler"
echo "----------------------------------------"

# 1. Compile release binary
echo -e "${BLUE}Compiling Solaris in release mode...${NC}"
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
APP_NAME="Solaris.app"
APP_BUNDLE_PATH="$DIST_DIR/$APP_NAME"
CONTENTS_PATH="$APP_BUNDLE_PATH/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
RESOURCES_PATH="$CONTENTS_PATH/Resources"

echo -e "${BLUE}Structuring local app bundle...${NC}"
rm -rf "$APP_BUNDLE_PATH"
mkdir -p "$MACOS_PATH"
mkdir -p "$RESOURCES_PATH"

# 3. Locate compiled binary and copy it
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

# 4. Generate Info.plist
INFO_PLIST_PATH="$CONTENTS_PATH/Info.plist"
echo "Generating minimal Info.plist at $INFO_PLIST_PATH..."

cat > "$INFO_PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Solaris</string>
    <key>CFBundleIdentifier</key>
    <string>com.davidnguyen.solaris</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Solaris</string>
    <key>CFBundleDisplayName</key>
    <string>Solaris</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.3.0-dev</string>
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
echo -e "${GREEN}SUCCESS: Local app bundle packaged successfully!${NC}"
echo -e "Location: ${YELLOW}$APP_BUNDLE_PATH${NC}"
echo -e "To launch immediately, run: ${BLUE}open $APP_BUNDLE_PATH${NC}"
echo "----------------------------------------"
exit 0
