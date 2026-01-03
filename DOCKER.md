# Docker Deployment Guide

This guide covers deploying the XAF Blazor Server application using Docker with SQL Server Express and nginx reverse proxy with SSL.

## Prerequisites

- Docker Engine 20.10+ and Docker Compose 2.0+
- A domain name pointing to your server (for SSL certificates)
- Port 80 and 443 available on your server

## Architecture

The Docker setup consists of four services:

1. **sqlserver** - Microsoft SQL Server Express 2022 for Linux
2. **xafapp** - XAF Blazor Server application (.NET 8)
3. **nginx** - Reverse proxy with SSL termination
4. **certbot** - Automatic SSL certificate management with Let's Encrypt

All services run on a private Docker network (`xafdocker-network`).

## Development/Testing Setup (Without SSL)

For local development and testing, you can access the XAF application directly without SSL certificates:

### Quick Start for Development

1. **Configure environment:**
   ```bash
   cp .env.template .env
   # Edit .env and set at minimum:
   # - SQL_SA_PASSWORD (strong password)
   # - URL_SIGNING_KEY (any GUID)
   ```

2. **Start the application:**
   ```bash
   docker compose up -d
   ```

3. **Access the application:**
   - **XAF Application:** http://localhost:5080
   - **Health Check:** http://localhost:5080/health
   - **SQL Server:** localhost:1433

The application is exposed on port **5080** for direct access, bypassing the nginx reverse proxy.

### Port Configuration

| Service | Internal Port | External Port | Purpose |
|---------|--------------|---------------|---------|
| xafapp | 80 | 5080 | XAF Blazor Server (direct access) |
| sqlserver | 1433 | 1433 | SQL Server (development only) |
| nginx | 80/443 | 8080/8443 | Reverse proxy (requires SSL setup) |

**Note:** In production, remove the SQL Server port exposure (1433) and access the application only through nginx (ports 80/443).



## Quick Start

### 1. Initial Configuration

Copy the environment template and configure it:

```bash
cp .env.template .env
nano .env  # or use your preferred editor
```

**Required configuration in `.env`:**

- `SQL_SA_PASSWORD` - Strong password for SQL Server (min 8 chars, uppercase, lowercase, numbers, symbols)
- `URL_SIGNING_KEY` - Generate a new GUID for production (use `uuidgen` or `[guid]::NewGuid()`)
- `DOMAIN_NAME` - Your domain name (e.g., example.com)
- `EMAIL_ADDRESS` - Your email for Let's Encrypt notifications

### 2. Update nginx Configuration

Edit `docker/nginx/conf.d/default.conf` and replace `yourdomain.com` with your actual domain name:

```bash
sed -i 's/yourdomain.com/your-actual-domain.com/g' docker/nginx/conf.d/default.conf
```

### 3. Initialize SSL Certificates

Run the Let's Encrypt initialization script:

```bash
./init-letsencrypt.sh
```

This script will:
- Create temporary self-signed certificates
- Start nginx
- Request real certificates from Let's Encrypt
- Reload nginx with the real certificates

### 4. Start All Services

```bash
docker compose up -d
```

### 5. Verify Deployment

Check that all services are running:

```bash
docker compose ps
```

Check application logs:

```bash
docker compose logs -f xafapp
```

Access your application at `https://your-domain.com`

## Common Commands

### Start Services
```bash
docker compose up -d
```

### Stop Services
```bash
docker compose down
```

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f xafapp
docker compose logs -f sqlserver
docker compose logs -f nginx
```

### Restart a Service
```bash
docker compose restart xafapp
```

### Rebuild and Restart Application
```bash
docker compose up -d --build xafapp
```

### Access SQL Server
```bash
# From host machine (if port 1433 is exposed)
docker exec -it xafdocker-sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourPassword'

# From within the container
docker exec -it xafdocker-sqlserver bash
```

### Update Database Schema
```bash
docker compose exec xafapp dotnet XAFDocker.Blazor.Server.dll --updateDatabase --forceUpdate
```

### Renew SSL Certificates Manually
```bash
docker compose run --rm certbot renew
docker compose exec nginx nginx -s reload
```

## Database Management

### Backup Database

```bash
# Create backup directory
mkdir -p backups

# Backup database
docker exec xafdocker-sqlserver /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P "$SQL_SA_PASSWORD" \
  -Q "BACKUP DATABASE [XAFDocker] TO DISK = N'/var/opt/mssql/backup/XAFDocker.bak' WITH NOFORMAT, NOINIT, NAME = 'XAFDocker-full', SKIP, NOREWIND, NOUNLOAD, STATS = 10"

# Copy backup to host
docker cp xafdocker-sqlserver:/var/opt/mssql/backup/XAFDocker.bak ./backups/
```

### Restore Database

```bash
# Copy backup to container
docker cp ./backups/XAFDocker.bak xafdocker-sqlserver:/var/opt/mssql/backup/

# Restore database
docker exec xafdocker-sqlserver /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P "$SQL_SA_PASSWORD" \
  -Q "RESTORE DATABASE [XAFDocker] FROM DISK = N'/var/opt/mssql/backup/XAFDocker.bak' WITH REPLACE"
```

## Troubleshooting

### Application Can't Connect to Database

Check if SQL Server is healthy:
```bash
docker compose ps sqlserver
```

Check SQL Server logs:
```bash
docker compose logs sqlserver
```

Verify connection string in docker-compose.yml matches SQL Server configuration.

### SSL Certificate Issues

For testing, you can use staging certificates:
```bash
# Edit init-letsencrypt.sh and set staging=1
# Then re-run the script
./init-letsencrypt.sh
```

Check certbot logs:
```bash
docker compose logs certbot
```

### Blazor SignalR Connection Issues

Ensure nginx is properly configured for WebSocket connections. Check:
- `proxy_set_header Upgrade $http_upgrade;`
- `proxy_set_header Connection "upgrade";`

These are already configured in `docker/nginx/conf.d/default.conf`.

Check nginx logs:
```bash
docker compose logs nginx
```

### Database Update Fails on Startup

The application attempts to run `--updateDatabase --silent` on first start. If this fails:

1. Check XAF application logs:
```bash
docker compose logs xafapp
```

2. Manually update the database:
```bash
docker compose exec xafapp dotnet XAFDocker.Blazor.Server.dll --updateDatabase --forceUpdate
```

3. Restart the application:
```bash
docker compose restart xafapp
```

## Security Considerations

### Production Checklist

- [ ] Change `SQL_SA_PASSWORD` to a strong, unique password
- [ ] Generate new `URL_SIGNING_KEY` GUID
- [ ] Remove SQL Server port exposure (1433) from docker-compose.yml
- [ ] Configure firewall to only allow ports 80 and 443
- [ ] Enable Docker secrets for sensitive data (optional, advanced)
- [ ] Set up automated backups
- [ ] Monitor logs for security issues
- [ ] Keep Docker images updated

### Updating Docker Images

```bash
# Pull latest images
docker compose pull

# Rebuild and restart
docker compose up -d --build
```

## Volumes and Data Persistence

### SQL Server Data
- Volume: `sqlserver-data`
- Location: `/var/opt/mssql` in container
- Persists database files across container restarts

### SSL Certificates
- Path: `./docker/certbot/conf`
- Contains Let's Encrypt certificates and keys
- Automatically renewed by certbot service

### nginx Configuration
- Path: `./docker/nginx/`
- Mounted read-only into nginx container

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SQL_SA_PASSWORD` | SQL Server SA password | YourStrong!Passw0rd |
| `URL_SIGNING_KEY` | XAF security signing key | (debug key) |
| `DOMAIN_NAME` | Domain for SSL certificate | yourdomain.com |
| `EMAIL_ADDRESS` | Email for Let's Encrypt | admin@yourdomain.com |

## Network Configuration

The `xafdocker-network` bridge network uses subnet `172.20.0.0/16`.

Service communication:
- nginx → xafapp on port 80 (internal)
- xafapp → sqlserver on port 1433 (internal)

External access:
- Port 80 (HTTP) → nginx → redirects to HTTPS
- Port 443 (HTTPS) → nginx → xafapp

## Monitoring

### Health Checks

All services include health checks:

```bash
# View health status
docker compose ps
```

### Resource Usage

```bash
# View resource usage
docker stats
```

## Support

For issues related to:
- Docker setup: Check this documentation and Docker logs
- XAF Framework: See [CLAUDE.md](CLAUDE.md) and DevExpress documentation
- nginx: Check nginx logs and configuration syntax

## Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [SQL Server on Linux](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-overview)
- [DevExpress XAF Documentation](https://docs.devexpress.com/eXpressAppFramework/112670/expressapp-framework)
