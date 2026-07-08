#!/usr/bin/env bash
set -euo pipefail

# Generates Secrets.xcconfig from environment variables.
# Used locally and in CI — never commit the output file.

OUTPUT="${1:-CIWatcher-macOS/CIWatcher-macOS/Secrets.xcconfig}"

required_vars=(
  GITHUB_APP_ID
  GITHUB_CLIENT_ID
  GITHUB_PRIVATE_KEY
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "Error: $var is not set" >&2
    exit 1
  fi
done

# Support base64-encoded private key in CI (GITHUB_PRIVATE_KEY_BASE64)
private_key="${GITHUB_PRIVATE_KEY}"
if [[ -n "${GITHUB_PRIVATE_KEY_BASE64:-}" ]]; then
  private_key="${GITHUB_PRIVATE_KEY_BASE64}"
fi

cat > "$OUTPUT" <<EOF
// Auto-generated — do not commit
GITHUB_APP_ID = ${GITHUB_APP_ID}
GITHUB_CLIENT_ID = ${GITHUB_CLIENT_ID}
GITHUB_CLIENT_SECRET = ${GITHUB_CLIENT_SECRET:-}
GITHUB_PRIVATE_KEY = ${private_key}
SPARKLE_PUBLIC_ED_KEY = ${SPARKLE_PUBLIC_ED_KEY:-}
EOF

echo "Generated $OUTPUT"
