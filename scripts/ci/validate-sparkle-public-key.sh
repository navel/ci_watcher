#!/usr/bin/env bash
# Verify SUPublicEDKey in a built app decodes to a valid 32-byte Ed25519 public key.
set -euo pipefail

APP_PATH="${1:?Usage: validate-sparkle-public-key.sh <path-to-.app>}"

KEY=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)
if [[ -z "$KEY" ]]; then
  echo "Error: SUPublicEDKey is missing from $APP_PATH" >&2
  exit 1
fi

python3 - "$KEY" <<'PY'
import base64, sys
key = sys.argv[1].strip()
try:
    data = base64.b64decode(key, validate=True)
except Exception:
    print(f"Error: SUPublicEDKey is not valid base64: {key!r}", file=sys.stderr)
    sys.exit(1)
if len(data) != 32:
    print(f"Error: SUPublicEDKey must decode to 32 bytes, got {len(data)}: {key!r}", file=sys.stderr)
    sys.exit(1)
print(f"SUPublicEDKey is valid ({len(data)} bytes)")
PY
