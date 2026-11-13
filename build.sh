#!/bin/zsh
# Builds .build/Owl Switch.app and .build/Owl-Switch.zip.
# Output stays in the hidden .build folder so the build copy isn't opened by accident;
# install by copying it to /Applications.
set -euo pipefail
cd "$(dirname "$0")"

BUILD=".build"
APP="$BUILD/Owl Switch.app"
rm -rf "$BUILD" "Owl Awake.app" "Owl Switch.app"
mkdir -p "$BUILD" "$APP/Contents/MacOS" "$APP/Contents/Resources"

# App icon
swiftc -O Sources/OwlShape.swift Tools/IconGen/main.swift -o "$BUILD/icongen"
"$BUILD/icongen" "$BUILD/AppIcon.iconset"
iconutil -c icns "$BUILD/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
cp "$BUILD/AppIcon.iconset/icon_512x512@2x.png" icon-preview.png

# App binary — universal, so it runs on both Apple Silicon and Intel Macs
for arch in arm64 x86_64; do
    swiftc -O -target $arch-apple-macos13.0 Sources/*.swift -o "$BUILD/OwlSwitch-$arch"
done
lipo -create "$BUILD/OwlSwitch-arm64" "$BUILD/OwlSwitch-x86_64" -output "$APP/Contents/MacOS/OwlSwitch"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Owl Switch</string>
    <key>CFBundleDisplayName</key><string>Owl Switch</string>
    <key>CFBundleIdentifier</key><string>com.techcreatorslab.owlswitch</string>
    <key>CFBundleExecutable</key><string>OwlSwitch</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>2.0</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
ditto -c -k --keepParent "$APP" "$BUILD/Owl-Switch.zip"
echo "Built $APP and $BUILD/Owl-Switch.zip"
