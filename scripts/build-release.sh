#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load .env if present
if [ -f "$ROOT_DIR/.env" ]; then
  export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)
fi
BUILD_DIR="$ROOT_DIR/build"
IDENTITY="2481CAB44B59140AFAD31E42684C8481CB0F432C"
TEAM_ID="3444HCQA2D"
BUNDLE_ID="com.suraj.LOLI"

echo "Building LOLI release..."

# Clean & build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cd "$ROOT_DIR"
xcodebuild -scheme LOLI -configuration Release -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR/derived" \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  build

APP_PATH="$BUILD_DIR/derived/Build/Products/Release/LOLI.app"

echo "Signing app..."
codesign --deep --force --options runtime \
  --sign "$IDENTITY" \
  --entitlements "$ROOT_DIR/LOLI/LOLI.entitlements" \
  "$APP_PATH"

codesign --verify --deep --strict "$APP_PATH"
echo "Signature verified."

echo "Creating DMG..."
DMG_DIR="$BUILD_DIR/dmg-staging"
mkdir -p "$DMG_DIR"
cp -R "$APP_PATH" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"
hdiutil create -volname "LOLI" -srcfolder "$DMG_DIR" -ov -format UDZO "$BUILD_DIR/LOLI.dmg"

echo "Signing DMG..."
codesign --force --sign "$IDENTITY" "$BUILD_DIR/LOLI.dmg"

echo "Notarizing..."
xcrun notarytool submit "$BUILD_DIR/LOLI.dmg" \
  --team-id "$TEAM_ID" \
  --apple-id "${APPLE_ID:?Set APPLE_ID in .env}" \
  --password "${APPLE_APP_PASSWORD:?Set APPLE_APP_PASSWORD in .env}" \
  --wait

echo "Stapling..."
xcrun stapler staple "$BUILD_DIR/LOLI.dmg"

echo ""
echo "Done! Release DMG: $BUILD_DIR/LOLI.dmg"
