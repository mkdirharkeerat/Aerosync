#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "🔨 Building AeroSync release binary..."
swift build -c release

APP_DIR="$DIR/build/AeroSync.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

cp "$DIR/.build/arm64-apple-macosx/release/AeroSync" "$MACOS/AeroSync"
cp "$DIR/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"

cat << 'PLIST' > "$CONTENTS/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.aerosync.mac</string>
    <key>CFBundleName</key>
    <string>AeroSync</string>
    <key>CFBundleDisplayName</key>
    <string>AeroSync</string>
    <key>CFBundleExecutable</key>
    <string>AeroSync</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "💿 Creating standalone distributable DMG..."
DMG_PATH="$DIR/build/AeroSync.dmg"
rm -f "$DMG_PATH"
hdiutil create -volname "AeroSync" -srcfolder "$APP_DIR" -ov -format UDZO "$DMG_PATH" > /dev/null

echo "✅ App successfully bundled at: $APP_DIR"
echo "✅ DMG installer generated at: $DMG_PATH"
