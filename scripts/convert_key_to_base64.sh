#!/bin/bash
# Script to convert PEM private key to base64 format for Secrets.xcconfig
# Usage: ./convert_key_to_base64.sh <path_to_private_key.pem>

if [ $# -eq 0 ]; then
    echo "Usage: $0 <path_to_private_key.pem>"
    echo ""
    echo "This script converts a PEM private key to base64 format"
    echo "suitable for use in Secrets.xcconfig"
    exit 1
fi

KEY_FILE="$1"

if [ ! -f "$KEY_FILE" ]; then
    echo "Error: File not found: $KEY_FILE"
    exit 1
fi

echo "Converting $KEY_FILE to base64 format..."
echo ""
echo "Add this to your Secrets.xcconfig:"
echo "GITHUB_PRIVATE_KEY = $(cat "$KEY_FILE" | base64 | tr -d '\n')"
echo ""

