#!/usr/bin/env bash
# Build, sign, notarize, and package CIWatcher for GitHub Releases.
#
# Required: APPLE_TEAM_ID, NOTARY_APPLE_ID, NOTARY_PASSWORD,
#           GITHUB_APP_ID, GITHUB_CLIENT_ID, GITHUB_PRIVATE_KEY (or GITHUB_PRIVATE_KEY_BASE64)
# Optional: SPARKLE_PUBLIC_ED_KEY, VERSION, BUILD_NUMBER
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

VERSION="${VERSION#v}"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-1}}"
ARCHIVE_PATH="$ROOT/build/CIWatcher-macOS.xcarchive"
EXPORT_PATH="$ROOT/build/export"
APP_PATH="$EXPORT_PATH/CIWatcher-macOS.app"
DMG_PATH="$ROOT/build/CIWatcher-${VERSION}.dmg"
ZIP_PATH="$ROOT/build/CIWatcher-${VERSION}.zip"

echo "Building CIWatcher ${VERSION} (${BUILD_NUMBER})"

# Generate secrets config
chmod +x scripts/ci/generate-secrets-xcconfig.sh
./scripts/ci/generate-secrets-xcconfig.sh

# Verify Developer ID certificate is available
KEYCHAIN_SEARCH=(find-identity -v -p codesigning)
if [[ -n "${KEYCHAIN_PATH:-}" ]]; then
  KEYCHAIN_SEARCH+=( "$KEYCHAIN_PATH" )
fi

if ! security "${KEYCHAIN_SEARCH[@]}" | grep -q "Developer ID Application"; then
  echo "Error: Developer ID Application certificate not found in keychain" >&2
  security "${KEYCHAIN_SEARCH[@]}" >&2 || true
  exit 1
fi

# Use the generic identity name — xcodebuild matches the cert in keychain
SIGNING_IDENTITY="Developer ID Application"
echo "Using signing identity: $SIGNING_IDENTITY"

# Resolve packages (use locked versions only)
xcodebuild -resolvePackageDependencies \
  -workspace CIWatcher.xcworkspace \
  -scheme CIWatcher-macOS \
  ONLY_USE_PACKAGE_VERSIONS_FROM_RESOLVED_FILE=YES

# Archive (universal binary)
xcodebuild archive \
  -workspace CIWatcher.xcworkspace \
  -scheme CIWatcher-macOS \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=macOS" \
  ONLY_USE_PACKAGE_VERSIONS_FROM_RESOLVED_FILE=YES \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  DEVELOPMENT_TEAM="${APPLE_TEAM_ID}"

# Generate export options with team ID
sed "s/TEAM_ID_PLACEHOLDER/${APPLE_TEAM_ID}/g" ExportOptions/DirectDistribution.plist > /tmp/ExportOptions.plist

# Export
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist /tmp/ExportOptions.plist

# Verify signature
codesign --verify --deep --strict "$APP_PATH"
spctl --assess --type execute "$APP_PATH" || true

# Notarize
NOTARIZE_ZIP="$ROOT/build/.notarize-submit.zip"
ditto -c -k --keepParent "$APP_PATH" "$NOTARIZE_ZIP"
xcrun notarytool submit "$NOTARIZE_ZIP" \
  --apple-id "$NOTARY_APPLE_ID" \
  --password "$NOTARY_PASSWORD" \
  --team-id "$APPLE_TEAM_ID" \
  --wait

xcrun stapler staple "$APP_PATH"

chmod +x scripts/ci/validate-sparkle-public-key.sh
./scripts/ci/validate-sparkle-public-key.sh "$APP_PATH"

# Package DMG
mkdir -p "$ROOT/build/dmg-staging"
cp -R "$APP_PATH" "$ROOT/build/dmg-staging/"
ln -s /Applications "$ROOT/build/dmg-staging/Applications"

hdiutil create -volname "CIWatcher" \
  -srcfolder "$ROOT/build/dmg-staging" \
  -ov -format UDZO \
  "$DMG_PATH"

# ZIP for Sparkle appcast
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Built:"
echo "  $APP_PATH"
echo "  $DMG_PATH"
echo "  $ZIP_PATH"
