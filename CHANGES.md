# Configuration Changes Log

## 2026-01-03: Direct Application Access Configuration

### Changes Made

1. **docker-compose.yml Updates:**
   - Added port mapping to `xafapp` service: `5080:80`
   - Changed nginx ports to avoid conflicts:
     - HTTP: `8080:80` (was `80:80`)
     - HTTPS: `8443:443` (was `443:443`)
   - Removed hardcoded subnet from network configuration (now auto-assigned by Docker)
   - Fixed SQL Server health check to use `/opt/mssql-tools18/bin/sqlcmd` with `-C` flag

2. **Script Line Endings:**
   - Converted all shell scripts from CRLF to LF (Unix line endings):
     - `docker/app/entrypoint.sh`
     - `docker/sqlserver/init/01-init-database.sh`
     - `docker/nginx/nginx.conf`
     - `docker/nginx/conf.d/default.conf`
     - `init-letsencrypt.sh`
     - `test-docker-setup.sh`

3. **Documentation Updates:**
   - Added "Development/Testing Setup (Without SSL)" section to DOCKER.md
   - Renamed "Quick Start" to "Production Setup (With SSL)" for clarity
   - Added port configuration table showing internal/external port mappings

### Access Information

#### Development/Testing (No SSL Required)
- **XAF Application:** http://localhost:5080
- **Health Check:** http://localhost:5080/health
- **SQL Server:** localhost:1433

#### Production (With SSL - after running init-letsencrypt.sh)
- **XAF Application (HTTPS):** https://yourdomain.com (via nginx on port 443)
- **XAF Application (HTTP redirect):** http://yourdomain.com (via nginx on port 80, redirects to HTTPS)

### Port Summary

| Service | Internal Port | External Port | Status |
|---------|--------------|---------------|---------|
| **xafapp** | 80 | 5080 | ✅ Healthy - Direct access enabled |
| **sqlserver** | 1433 | 1433 | ✅ Healthy - For development only |
| **nginx** | 80 | 8080 | ⚠️  Requires SSL certificates (init-letsencrypt.sh) |
| **nginx** | 443 | 8443 | ⚠️  Requires SSL certificates (init-letsencrypt.sh) |
| **certbot** | - | - | ✅ Running - SSL renewal service |

### Container Status

All containers successfully started and verified:

```bash
$ docker compose ps
NAME                  STATUS                  PORTS
xafdocker-app         Up (healthy)           0.0.0.0:5080->80/tcp
xafdocker-sqlserver   Up (healthy)           0.0.0.0:1433->1433/tcp
xafdocker-certbot     Up                     -
xafdocker-nginx       Restarting (needs SSL) -
```

### Testing Performed

✅ SQL Server health check passing
✅ XAF application database schema updated successfully
✅ XAF application started and listening on port 80 (internal)
✅ Health check endpoint responding: http://localhost:5080/health
✅ Main application accessible: http://localhost:5080

### Known Issues

1. **nginx container restarting:**
   - Expected behavior - nginx requires SSL certificates
   - Solution: Run `./init-letsencrypt.sh` with a configured domain
   - Alternative: Use direct access via port 5080 for development

### Next Steps for Production

1. Configure a domain name pointing to your server
2. Update `.env` with production values (DOMAIN_NAME, EMAIL_ADDRESS)
3. Update `docker/nginx/conf.d/default.conf` with your domain
4. Run `./init-letsencrypt.sh` to generate SSL certificates
5. Remove SQL Server port exposure (1433) in docker-compose.yml
6. Access application via https://yourdomain.com

### Development Workflow

For local development without SSL:

```bash
# Start all services
docker compose up -d

# Access the application
open http://localhost:5080

# View logs
docker compose logs -f xafapp

# Stop all services
docker compose down
```
