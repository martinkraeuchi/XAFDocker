#!/bin/bash
# Quick test script to validate Docker setup

echo "=== XAF Docker Setup Validation ==="
echo ""

# Check if .env exists
echo "1. Checking for .env file..."
if [ -f .env ]; then
    echo "   ✓ .env file exists"
else
    echo "   ✗ .env file not found"
    echo "   → Copy .env.template to .env and configure it"
    exit 1
fi

# Check if Docker is running
echo "2. Checking Docker..."
if docker info > /dev/null 2>&1; then
    echo "   ✓ Docker is running"
else
    echo "   ✗ Docker is not running"
    exit 1
fi

# Check if docker-compose is available
echo "3. Checking docker compose..."
if command -v docker compose > /dev/null 2>&1; then
    echo "   ✓ docker compose is available"
elif docker compose version > /dev/null 2>&1; then
    echo "   ✓ docker compose (plugin) is available"
else
    echo "   ✗ docker compose not found"
    exit 1
fi

# Validate docker-compose.yml
echo "4. Validating docker-compose.yml..."
if docker compose config > /dev/null 2>&1; then
    echo "   ✓ docker-compose.yml is valid"
else
    echo "   ✗ docker-compose.yml has errors"
    exit 1
fi

# Check required directories
echo "5. Checking directory structure..."
for dir in docker/nginx/conf.d docker/sqlserver/init docker/app docker/certbot; do
    if [ -d "$dir" ]; then
        echo "   ✓ $dir exists"
    else
        echo "   ✗ $dir missing"
        exit 1
    fi
done

# Check required files
echo "6. Checking required files..."
for file in Dockerfile docker-compose.yml init-letsencrypt.sh docker/app/entrypoint.sh; do
    if [ -f "$file" ]; then
        echo "   ✓ $file exists"
    else
        echo "   ✗ $file missing"
        exit 1
    fi
done

echo ""
echo "=== All checks passed! ==="
echo ""
echo "Next steps:"
echo "1. Configure .env file with your settings"
echo "2. Update docker/nginx/conf.d/default.conf with your domain"
echo "3. Run: docker compose build"
echo "4. Run: ./init-letsencrypt.sh (for SSL setup)"
echo "5. Run: docker compose up -d"
echo ""
