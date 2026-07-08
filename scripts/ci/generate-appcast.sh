#!/usr/bin/env bash
# Generate a signed Sparkle appcast.xml using sign_update.
#
# Required env vars:
#   VERSION          - marketing version (e.g. 1.0.1)
#   BUILD_NUMBER     - build number for sparkle:version
#   RELEASE_ZIP      - path to the update archive
#   SPARKLE_BIN_DIR  - path to Sparkle bin/ directory
#   SPARKLE_PRIVATE_ED_KEY - base64-encoded eddsa_private_key file
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

VERSION="${VERSION#v}"
OUTPUT="${1:-build/appcast.xml}"
RELEASE_ZIP="${RELEASE_ZIP:-build/CIWatcher-${VERSION}.zip}"
SPARKLE_BIN_DIR="${SPARKLE_BIN_DIR:-bin}"

for var in VERSION BUILD_NUMBER SPARKLE_PRIVATE_ED_KEY; do
  if [[ -z "${!var:-}" ]]; then
    echo "Error: $var is not set" >&2
    exit 1
  fi
done

if [[ ! -f "$RELEASE_ZIP" ]]; then
  echo "Error: release zip not found: $RELEASE_ZIP" >&2
  exit 1
fi

echo "$SPARKLE_PRIVATE_ED_KEY" | base64 --decode > eddsa_private_key

SIGN_OUTPUT=$("$SPARKLE_BIN_DIR/sign_update" --ed-key-file eddsa_private_key "$RELEASE_ZIP")
echo "sign_update output: $SIGN_OUTPUT"

ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
ZIP_LENGTH=$(echo "$SIGN_OUTPUT" | sed -n 's/.*length="\([^"]*\)".*/\1/p')

if [[ -z "$ED_SIGNATURE" || -z "$ZIP_LENGTH" ]]; then
  echo "Error: failed to parse sign_update output" >&2
  rm -f eddsa_private_key
  exit 1
fi

PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")
DOWNLOAD_URL="https://github.com/navel/ci_watcher/releases/latest/download/CIWatcher-${VERSION}.zip"

mkdir -p "$(dirname "$OUTPUT")"
cat > "$OUTPUT" <<EOF
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>CIWatcher-macOS</title>
        <item>
            <title>${VERSION}</title>
            <pubDate>${PUB_DATE}</pubDate>
            <sparkle:version>${BUILD_NUMBER}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <enclosure url="${DOWNLOAD_URL}" length="${ZIP_LENGTH}" type="application/octet-stream" sparkle:edSignature="${ED_SIGNATURE}"/>
        </item>
    </channel>
</rss>
EOF

rm -f eddsa_private_key

if ! grep -q 'sparkle:edSignature' "$OUTPUT"; then
  echo "Error: generated appcast is missing sparkle:edSignature" >&2
  cat "$OUTPUT"
  exit 1
fi

echo "Generated signed appcast: $OUTPUT"
