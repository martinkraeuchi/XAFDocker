#!/bin/sh
# Configure DevExpress license from either local file or build argument
# Used during Docker build to support both local development and Dokploy deployment

set -e

LICENSE_DIR="/root/.config/DevExpress"
LICENSE_FILE="$LICENSE_DIR/DevExpress_License.txt"
LOCAL_LICENSE="/tmp/local-license/DevExpress_License.txt"

mkdir -p "$LICENSE_DIR"

if [ -f "$LOCAL_LICENSE" ]; then
    # Use local file (development)
    echo "📝 DevExpress license: Using local file"
    cp "$LOCAL_LICENSE" "$LICENSE_FILE"
elif [ -n "$DevExpress_License" ]; then
    # Use build argument (Dokploy/CI)
    echo "📝 DevExpress license: Using build argument"
    echo "$DevExpress_License" > "$LICENSE_FILE"
else
    echo "⚠️  WARNING: No DevExpress license provided"
    echo "   Build will show DX1000/DX1001 warnings"
    exit 0
fi

echo "✅ DevExpress license configured at: $LICENSE_FILE"
