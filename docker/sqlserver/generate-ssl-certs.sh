#!/bin/bash
# Generate SSL certificates for SQL Server encrypted connections

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CERT_DIR="$SCRIPT_DIR/certs"

echo "Creating certificate directory..."
mkdir -p "$CERT_DIR"

echo "Generating private key..."
openssl genrsa -out "$CERT_DIR/mssql.key" 2048

echo "Generating self-signed certificate..."
openssl req -new -x509 -key "$CERT_DIR/mssql.key" \
    -out "$CERT_DIR/mssql.pem" \
    -days 3650 \
    -subj "/C=CH/ST=Switzerland/L=Zurich/O=SKG/CN=xafdb.skghub.ch"

echo "Setting correct permissions..."
chmod 600 "$CERT_DIR/mssql.key"
chmod 644 "$CERT_DIR/mssql.pem"

echo ""
echo "SSL certificates generated successfully!"
echo "Certificate: $CERT_DIR/mssql.pem"
echo "Private Key: $CERT_DIR/mssql.key"
echo ""
echo "IMPORTANT: For production, replace these self-signed certificates with"
echo "certificates from a trusted Certificate Authority (CA)."
echo ""
echo "To use Let's Encrypt certificates instead, you can symlink:"
echo "  ln -s /path/to/letsencrypt/fullchain.pem $CERT_DIR/mssql.pem"
echo "  ln -s /path/to/letsencrypt/privkey.pem $CERT_DIR/mssql.key"
