#!/bin/bash
# Setup DevExpress License for Local Development
# This script reads the DevExpress_License from .env and creates the license file
# in the expected location for native Linux builds.

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
ENV_FILE="$PROJECT_ROOT/.env"
LICENSE_DIR="$HOME/.config/DevExpress"
LICENSE_FILE="$LICENSE_DIR/DevExpress_License.txt"

echo "DevExpress License Setup"
echo "========================"
echo ""

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: .env file not found at $ENV_FILE"
    echo ""
    echo "Please create .env file with DevExpress_License variable:"
    echo "  DevExpress_License=\"your-license-key-here\""
    echo ""
    exit 1
fi

# Extract license key from .env
LICENSE_KEY=$(grep "^DevExpress_License=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs)

# Check if license key is empty
if [ -z "$LICENSE_KEY" ]; then
    echo "❌ Error: DevExpress_License not found or empty in .env file"
    echo ""
    echo "Please add the following line to your .env file:"
    echo "  DevExpress_License=\"your-license-key-here\""
    echo ""
    echo "To obtain your license key:"
    echo "  1. Visit https://devexpress.com"
    echo "  2. Login to your account"
    echo "  3. Go to 'My Account' → 'License Keys'"
    echo "  4. Copy your license key"
    echo ""
    exit 1
fi

# Create license directory if it doesn't exist
echo "📁 Creating license directory: $LICENSE_DIR"
mkdir -p "$LICENSE_DIR"

# Write license key to file
echo "📝 Writing license key to: $LICENSE_FILE"
echo "$LICENSE_KEY" > "$LICENSE_FILE"

# Set appropriate permissions
chmod 644 "$LICENSE_FILE"

echo ""
echo "✅ DevExpress license configured successfully!"
echo ""
echo "License file location: $LICENSE_FILE"
echo "License key (first 20 chars): ${LICENSE_KEY:0:20}..."
echo ""
echo "You can now build the project without license warnings:"
echo "  dotnet build XAFDocker.sln"
echo ""
