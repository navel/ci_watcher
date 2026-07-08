#!/usr/bin/env bash
set -euo pipefail

# Generates Secrets.xcconfig from environment variables.
# Used locally and in CI — never commit the output file.

OUTPUT="${1:-CIWatcher-macOS/CIWatcher-macOS/Secrets.xcconfig}"

for var in GITHUB_APP_ID GITHUB_CLIENT_ID; do
  if [[ -z "${!var:-}" ]]; then
    echo "Error: $var is not set" >&2
    exit 1
  fi
done

if [[ -z "${GITHUB_PRIVATE_KEY:-}" && -z "${GITHUB_PRIVATE_KEY_BASE64:-}" ]]; then
  echo "Error: GITHUB_PRIVATE_KEY or GITHUB_PRIVATE_KEY_BASE64 must be set" >&2
  exit 1
fi

private_key="${GITHUB_PRIVATE_KEY:-${GITHUB_PRIVATE_KEY_BASE64}}"

cat > "$OUTPUT" <<EOF
// Auto-generated — do not commit
GITHUB_APP_ID = ${GITHUB_APP_ID}
GITHUB_CLIENT_ID = ${GITHUB_CLIENT_ID}
GITHUB_CLIENT_SECRET = ${GITHUB_CLIENT_SECRET:-}
GITHUB_PRIVATE_KEY = ${private_key}
SPARKLE_PUBLIC_ED_KEY = ${SPARKLE_PUBLIC_ED_KEY:-}
EOF

echo "Generated $OUTPUT"
