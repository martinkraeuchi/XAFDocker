# SQL Server SSL/TLS Configuration

This directory contains SSL certificate configuration for encrypted SQL Server connections.

## Quick Start

### 1. Generate Self-Signed Certificates (Development/Testing)

```bash
cd docker/sqlserver
chmod +x generate-ssl-certs.sh
./generate-ssl-certs.sh
```

This creates:
- `certs/mssql.pem` - Public certificate
- `certs/mssql.key` - Private key

### 2. Deploy the Stack

```bash
docker compose -f docker-compose.prod.yml up -d
```

SQL Server will now require encrypted connections.

## Production Setup with Let's Encrypt

For production, use your existing Let's Encrypt certificates:

```bash
mkdir -p docker/sqlserver/certs

# Option 1: Copy certificates
cp /path/to/letsencrypt/live/xafdb.skghub.ch/fullchain.pem docker/sqlserver/certs/mssql.pem
cp /path/to/letsencrypt/live/xafdb.skghub.ch/privkey.pem docker/sqlserver/certs/mssql.key

# Option 2: Symlink certificates (recommended - auto-updates on renewal)
ln -s /path/to/letsencrypt/live/xafdb.skghub.ch/fullchain.pem docker/sqlserver/certs/mssql.pem
ln -s /path/to/letsencrypt/live/xafdb.skghub.ch/privkey.pem docker/sqlserver/certs/mssql.key

# Set permissions
chmod 600 docker/sqlserver/certs/mssql.key
chmod 644 docker/sqlserver/certs/mssql.pem
```

## Environment Variables

The following environment variables enforce SSL:

- `MSSQL_ENCRYPT_CONNECTIONS=1` - Enable encryption
- `MSSQL_FORCE_ENCRYPTION=1` - Require all connections to be encrypted

## Connection Strings

### From Application (Inside Docker Network)
```
Server=sqlserver,1433;Database=XAFDocker;User Id=sa;Password=xxx;Encrypt=True;TrustServerCertificate=True;MultipleActiveResultSets=True
```

### From External Client (DataGrip, SSMS, etc.)
```
Server=xafdb.skghub.ch,1433;Database=XAFDocker;User Id=sa;Password=xxx;Encrypt=True;TrustServerCertificate=False
```

**Note:** Use `TrustServerCertificate=False` for production with valid CA certificates.

## DataGrip Configuration

1. **Host:** `xafdb.skghub.ch`
2. **Port:** `1433`
3. **Database:** `XAFDocker`
4. **User:** `sa`
5. **Password:** [your SQL_SA_PASSWORD]
6. **Advanced Settings:**
   - `encrypt=true`
   - `trustServerCertificate=false` (if using valid CA cert)
   - `trustServerCertificate=true` (if using self-signed cert)

## Troubleshooting

### Connection Refused
Check if certificates are properly mounted:
```bash
docker exec xafdocker-sqlserver-prod ls -la /var/opt/mssql/certs/
```

### Certificate Errors
If using self-signed certificates, clients must either:
1. Set `TrustServerCertificate=True` in connection string
2. Import the certificate to their trusted root store

### Check SQL Server Logs
```bash
docker logs xafdocker-sqlserver-prod
```

Look for messages about encryption initialization.

## Security Best Practices

1. **Use CA-Signed Certificates** - Replace self-signed certificates with Let's Encrypt or commercial CA certificates
2. **Strong Passwords** - Ensure `SQL_SA_PASSWORD` is strong and stored securely
3. **Certificate Rotation** - Renew certificates before expiration (Let's Encrypt certs expire in 90 days)
4. **Disable TrustServerCertificate** - In production, set `TrustServerCertificate=False` and use valid certificates
5. **Firewall Rules** - Limit access to port 1433 to trusted IPs only

## Certificate Renewal

### For Let's Encrypt (Automated)
If you symlinked the certificates, they will automatically use the renewed certificates after certbot renewal. Just restart SQL Server:

```bash
docker restart xafdocker-sqlserver-prod
```

### For Self-Signed Certificates
Re-run the generation script before expiry (valid for 10 years by default):

```bash
./generate-ssl-certs.sh
docker restart xafdocker-sqlserver-prod
```
