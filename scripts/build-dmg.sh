#!/bin/bash
set -euo pipefail

# Configuration — update these for your signing identity
IDENTITY="Developer ID Application"
NOTARY_PROFILE="notarytool-profile"

SCHEME="SupermojiApp"
PROJECT="Supermoji.xcodeproj"
BUILD_DIR=".build/release-app"
APP_NAME="Supermoji.app"
DMG_NAME="Supermoji.dmg"

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Building ${SCHEME}..."
xcodebuild -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  build

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME"

echo "==> Signing app..."
codesign --deep --force --verify --verbose \
  --sign "$IDENTITY" \
  --options runtime \
  "$APP_PATH"

echo "==> Creating DMG..."
hdiutil create -volname "Supermoji" \
  -srcfolder "$APP_PATH" \
  -ov -format UDZO \
  "$DMG_NAME"

echo "==> Signing DMG..."
codesign --sign "$IDENTITY" "$DMG_NAME"

echo "==> Notarising..."
xcrun notarytool submit "$DMG_NAME" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

echo "==> Stapling..."
xcrun stapler staple "$DMG_NAME"

echo "==> Done: $DMG_NAME"
