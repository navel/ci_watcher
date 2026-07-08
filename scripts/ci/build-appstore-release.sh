#!/usr/bin/env bash
set -euo pipefail

# Build and export CIWatcher for Mac App Store upload.
#
# Required environment variables:
#   APPLE_TEAM_ID
#   APP_STORE_CONNECT_API_KEY_ID
#   APP_STORE_CONNECT_API_ISSUER_ID
#   APP_STORE_CONNECT_API_KEY_PATH (path to .p8 file)
#   GITHUB_APP_ID, GITHUB_CLIENT_ID, GITHUB_PRIVATE_KEY (or GITHUB_PRIVATE_KEY_BASE64)

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

VERSION="${VERSION#v}"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-1}}"
ARCHIVE_PATH="$ROOT/build/CIWatcher-macOS-AppStore.xcarchive"
EXPORT_PATH="$ROOT/build/export-appstore"
PKG_PATH="$ROOT/build/CIWatcher-${VERSION}.pkg"

chmod +x scripts/ci/generate-secrets-xcconfig.sh
./scripts/ci/generate-secrets-xcconfig.sh

xcodebuild -resolvePackageDependencies \
  -workspace CIWatcher.xcworkspace \
  -scheme CIWatcher-macOS

xcodebuild archive \
  -workspace CIWatcher.xcworkspace \
  -scheme CIWatcher-macOS \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=macOS" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_ENTITLEMENTS="CIWatcher-macOS/CIWatcher_macOS_AppStore.entitlements" \
  DEVELOPMENT_TEAM="${APPLE_TEAM_ID}" \
  OTHER_SWIFT_FLAGS="-D APPSTORE"

sed "s/TEAM_ID_PLACEHOLDER/${APPLE_TEAM_ID}/g" ExportOptions/AppStore.plist > /tmp/ExportOptions-AppStore.plist

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist /tmp/ExportOptions-AppStore.plist

APP_PATH="$EXPORT_PATH/CIWatcher-macOS.app"

# Sparkle is not allowed in Mac App Store builds
rm -rf "$APP_PATH/Contents/Frameworks/Sparkle.framework"

productbuild --component "$APP_PATH" /Applications "$PKG_PATH"

echo "Uploading to App Store Connect..."
xcrun altool --upload-app \
  --type macos \
  --file "$PKG_PATH" \
  --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_API_ISSUER_ID"

echo "Uploaded: $PKG_PATH"
