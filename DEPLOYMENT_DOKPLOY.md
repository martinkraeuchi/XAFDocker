# XAF Blazor Server Deployment Guide for Dokploy

This guide provides step-by-step instructions for deploying the XAF Docker application to Dokploy, an open-source Platform as a Service (PaaS).

> **✅ Production-Tested**: This guide reflects real-world deployment experience. The docker-compose.yml has been optimized for Dokploy compatibility and successfully deployed in production.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Pre-Deployment Preparation](#pre-deployment-preparation)
3. [Dokploy Setup](#dokploy-setup)
4. [Deploy Your Application](#deploy-your-application)
5. [Post-Deployment Configuration](#post-deployment-configuration)
6. [Monitoring and Maintenance](#monitoring-and-maintenance)
7. [Production Optimizations](#production-optimizations)
8. [Troubleshooting](#troubleshooting)
9. [Lessons Learned](#lessons-learned)

---

## Prerequisites

### What You Need

- **Dokploy Instance**: Either self-hosted or managed plan ($4.50/month)
  - Self-hosted requires a VPS with Docker installed
  - Managed plan: Sign up at [dokploy.com](https://dokploy.com/)
- **GitHub Repository**: Your code must be in a Git repository (already done: `https://github.com/martinkraeuchi/XAFDocker.git`)
- **Domain Name** (optional but recommended): For SSL/HTTPS access
- **Basic Knowledge**: Docker Compose and DevExpress XAF

### System Requirements (for self-hosted)

- Linux VPS (Ubuntu 20.04+ recommended)
- Minimum 2GB RAM, 2 CPU cores
- 20GB+ disk space
- Docker and Docker Compose installed

---

## Pre-Deployment Preparation

### Step 1: Review Your Docker Compose Configuration

Your current `docker-compose.yml` is **production-ready and Dokploy-optimized**. Key services:

- **sqlserver**: SQL Server Express 2022
- **xafapp**: Your XAF Blazor Server application

**✅ Dokploy Compatibility Features:**
- Uses Docker Compose version 3.3 (compatible with Dokploy's infrastructure)
- Environment variables use `.env` file approach (no default value syntax)
- Healthchecks formatted as arrays for proper parsing
- Simplified `depends_on` syntax without conditions
- No `start_period` in healthchecks (v3.3 limitation)

### Step 2: Prepare Environment Variables

Your `.env` file contains sensitive configuration. You'll need these values for Dokploy:

```bash
# Required environment variables
SQL_SA_PASSWORD=YourStrong!Passw0rd          # Change this!
URL_SIGNING_KEY=FAB39807-4423-424D-BC2F-572B65AE19F3  # Change this!
```

**IMPORTANT SECURITY NOTES:**
- ⚠️ Change `SQL_SA_PASSWORD` to a strong, unique password
- ⚠️ Generate a new `URL_SIGNING_KEY` GUID (use: `uuidgen` on Linux/Mac or `[guid]::NewGuid()` in PowerShell)

### Step 3: Optimize for Production (Optional but Recommended)

Consider these changes before deploying:

1. **Change ASPNETCORE_ENVIRONMENT to Production:**
   ```yaml
   - ASPNETCORE_ENVIRONMENT=Production
   ```

2. **Remove unnecessary port exposures**:
   - Comment out the SQL Server port 1433 exposure for security in production

3. **Configure persistent volumes** - Already configured:
   - `sqlserver-data` volume for database persistence

---

## Dokploy Setup

### Option A: Self-Hosted Dokploy Installation

If you're self-hosting, install Dokploy on your VPS:

```bash
# SSH into your VPS
ssh user@your-vps-ip

# Install Dokploy (one-line installer)
curl -sSL https://dokploy.com/install.sh | sh

# Access Dokploy web interface
# Navigate to: http://your-vps-ip:3000
```

### Option B: Managed Dokploy Plan

1. Sign up at [dokploy.com](https://dokploy.com/)
2. Create your account and select the managed plan ($4.50/month)
3. Access your Dokploy dashboard

---

## Deploy Your Application

### Step 1: Create a New Project

1. Log into your Dokploy dashboard
2. Click **"Create New Project"**
3. Give it a name: `XAF Blazor Server`

### Step 2: Add Your Application

1. Inside your project, click **"Add Application"**
2. Select **"Docker Compose"** as the deployment type
3. Configure the source:
   - **Repository URL**: `https://github.com/martinkraeuchi/XAFDocker.git`
   - **Branch**: `main`
   - **Docker Compose File Path**: Choose based on your needs:
     - `docker-compose.yml` - Development configuration
     - `docker-compose.prod.yml` - **Production configuration (Recommended)**

**📝 File Comparison**:

| Feature | docker-compose.yml | docker-compose.prod.yml |
|---------|-------------------|------------------------|
| Purpose | Development | **Production** |
| ASPNETCORE_ENVIRONMENT | Development | **Production** |
| SQL Server Port Exposed | Yes (1433) | **No (Security)** |
| Resource Limits | No | **Yes** |
| Log Rotation | No | **Yes** |
| Logging Level | Debug/Info | **Warning** |
| Container Names | Standard | -prod suffix |

**Recommended for Dokploy**: Use `docker-compose.prod.yml` for production deployments.

### Step 3: Configure Environment Variables

In the Dokploy interface, navigate to the **Environment** or **Variables** tab and add:

**Required Variables:**
```
SQL_SA_PASSWORD=<your-strong-password>
URL_SIGNING_KEY=<your-new-guid>
```

**Note**:
- Dokploy will automatically create a `.env` file with these variables
- If using `docker-compose.prod.yml`, production settings are already configured
- If using `docker-compose.yml`, add these optional production overrides:
  ```
  ASPNETCORE_ENVIRONMENT=Production
  Logging__LogLevel__Default=Warning
  Logging__LogLevel__Microsoft=Warning
  ```

### Step 4: Configure Build Settings

In the **General** tab:

- **Build Method**: Docker Compose
- **Compose Mode**: Standard (not Stack mode, since you're using `build`)
- **Deployment Action**: Choose "Recreate containers" for initial deployment

### Step 5: Configure Volumes

Navigate to the **Volumes** tab:

1. **Named Volumes** (recommended for production):
   - Dokploy will automatically manage the `sqlserver-data` volume
   - Enable automatic backups for this volume if available

### Step 6: Configure Domain and SSL

Dokploy provides built-in SSL management for custom domains:

1. **DNS Configuration**:
   - Add an A record pointing your domain to your Dokploy server IP
   - Example: `xafapp.yourdomain.com` → `123.45.67.89`

2. **Dokploy Domain Settings**:
   - Navigate to the **Domains** tab in your application
   - Add your domain: `xafapp.yourdomain.com`
   - Enable SSL - Dokploy will automatically obtain and manage Let's Encrypt certificates
   - Dokploy handles SSL termination via its reverse proxy

**Note**: The application itself runs on HTTP internally (port 80). Dokploy's reverse proxy handles HTTPS termination, so no nginx or certbot configuration is needed in your docker-compose files.

### Step 7: Deploy

1. Click the **"Deploy"** button
2. Monitor the deployment logs in real-time
3. Wait for all services to start (may take 2-5 minutes for first deployment)

**Expected Build Process:**
1. Git clone from repository
2. Build Docker image for `xafapp` service
3. Pull pre-built image for SQL Server
4. Start containers in order: sqlserver → xafapp
5. Database schema update (automatic on first run)

---

## Post-Deployment Configuration

### Step 1: Verify Services Are Running

In the Dokploy dashboard:

1. Check **Service Status** - all services should show "Running"
2. Check **Logs** for each service:
   - **sqlserver**: Should show "SQL Server is now ready for client connections"
   - **xafapp**: Should show "Application started" and "Now listening on: http://[::]:80"

### Step 2: Initial Login

1. Navigate to your application URL:
   - With custom domain: `https://xafapp.yourdomain.com`
   - With direct access: `http://your-server-ip:5080`
   - Via Dokploy proxy: Use the URL provided in the dashboard

2. **Default XAF Credentials** (if using standard XAF security):
   - Username: `Admin`
   - Password: (check your application's `Updater.cs` file for default password)

3. **Change default credentials immediately after first login**

### Step 3: Database Verification

1. Verify database persistence:
   ```bash
   # In Dokploy terminal or SSH
   docker exec -it xafdocker-sqlserver /opt/mssql-tools18/bin/sqlcmd \
     -S localhost -U sa -P "<your-password>" -C \
     -Q "SELECT name FROM sys.databases"
   ```

2. Confirm `XAFDocker` database exists

---

## Monitoring and Maintenance

### Health Checks

Dokploy provides built-in monitoring for your services. The following healthchecks are configured:

- **sqlserver**: SQL Server connection test (every 10s)
- **xafapp**: HTTP health endpoint check (every 30s)

### Viewing Logs

In the Dokploy dashboard:

1. Navigate to your application
2. Select the service (sqlserver or xafapp)
3. View real-time logs or download log history

### Backups

**Database Backups:**

1. **Automated Volume Backups**:
   - Enable in Dokploy's Volume Backup feature
   - Backs up the `sqlserver-data` volume automatically

2. **Manual SQL Server Backups**:
   ```bash
   # Create a backup
   docker exec xafdocker-sqlserver /opt/mssql-tools18/bin/sqlcmd \
     -S localhost -U sa -P "<password>" -C \
     -Q "BACKUP DATABASE XAFDocker TO DISK = '/var/opt/mssql/backup/XAFDocker.bak'"

   # Copy backup to host
   docker cp xafdocker-sqlserver:/var/opt/mssql/backup/XAFDocker.bak ./backup/
   ```

### Updates and Redeployment

To deploy updates:

1. **Push changes to GitHub**:
   ```bash
   git add .
   git commit -m "Your update message"
   git push origin main
   ```

2. **Redeploy in Dokploy**:
   - Click **"Deploy"** button in the dashboard
   - Or use webhook for automatic deployments on git push

3. **Webhook Setup** (for automatic deployments):
   - Go to **Settings** → **Webhooks** in Dokploy
   - Copy the webhook URL
   - Add to GitHub repository: Settings → Webhooks → Add webhook
   - Choose "Push" events

### Monitoring Best Practices

1. **Set up alerts** in Dokploy for:
   - Container restarts
   - High memory/CPU usage
   - Failed health checks

2. **Regular monitoring**:
   - Check application logs weekly
   - Review error logs in XAF application
   - Monitor database size growth

---

## Production Optimizations

These optimizations are based on real-world Dokploy deployment experience and will help you achieve better performance, security, and reliability.

### 1. Docker Compose Version Compatibility

**✅ Already Implemented** - Your docker-compose.yml uses version 3.3, which ensures compatibility with both Docker Compose v1 and v2.

**Why this matters:**
- Dokploy may use different Docker Compose versions depending on the infrastructure
- Version 3.3 is the sweet spot for broad compatibility
- Avoids deployment failures due to unsupported syntax

**Key compatibility changes made:**
```yaml
version: '3.3'  # Explicitly set for compatibility

# Environment variables - use .env file, not default syntax
- MSSQL_SA_PASSWORD=${SQL_SA_PASSWORD}  # ✅ Works
# NOT: ${SQL_SA_PASSWORD:-default}      # ❌ Parsing issues in older versions

# Healthchecks - use array format
healthcheck:
  test: ["CMD-SHELL", "command"]  # ✅ Consistent parsing
# NOT: test: command                # ❌ Ambiguous in some versions

# Removed start_period (not supported in 3.3)
# Simplified depends_on (no conditions in 3.3)
```

### 2. Environment Variable Management

**Best Practice:** Always use a separate `.env` file and never commit it to Git.

**For Dokploy Deployment:**
1. Configure environment variables in Dokploy's UI (Environment tab)
2. Dokploy automatically creates the `.env` file during deployment
3. Use strong, unique values for production (never use defaults)

**Critical Variables:**
```bash
# Security - MUST be changed for production
SQL_SA_PASSWORD=<Strong!P@ssw0rd123>   # Min 8 chars, mixed case, numbers, symbols
URL_SIGNING_KEY=<new-guid>              # Generate fresh GUID

# Domain Configuration
DOMAIN_NAME=your-actual-domain.com      # Your production domain
EMAIL_ADDRESS=admin@yourdomain.com      # Valid email for Let's Encrypt
```

**Generate Secure Values:**
```bash
# Generate strong password
openssl rand -base64 32

# Generate GUID (Linux/Mac)
uuidgen

# Generate GUID (PowerShell)
[guid]::NewGuid()
```

### 3. Service Startup Order Optimization

**Current Configuration (Good):**
```yaml
xafapp:
  depends_on:
    - sqlserver  # Simple dependency, works in Compose 3.3
```

**Why we simplified:**
- Originally used `condition: service_healthy` for smarter startup
- Not supported in Compose 3.3
- The application handles connection retries gracefully
- SQL Server healthcheck still ensures database is ready

**Startup Flow:**
1. SQL Server starts first (dependency)
2. Healthcheck runs every 10s until healthy
3. XAF app starts (may retry DB connections initially)
4. After ~30s, all services are healthy

### 4. Healthcheck Optimization

**Production-Tuned Healthcheck Settings:**

```yaml
# SQL Server - Critical, check frequently
healthcheck:
  interval: 10s    # Check every 10 seconds
  timeout: 3s      # Fail if no response in 3s
  retries: 10      # Allow 10 failures (100s total startup time)

# XAF Application - Less aggressive
healthcheck:
  interval: 30s    # Check every 30 seconds (reduce overhead)
  timeout: 3s
  retries: 3       # Fail after 3 attempts
```

**Why these intervals:**
- SQL Server needs more startup time (pulling image, initializing DB)
- XAF app is usually quick once SQL Server is ready
- Reduces unnecessary health check overhead in production

### 5. Resource Limits (Recommended Addition)

Add these to your docker-compose.yml for production stability:

```yaml
services:
  sqlserver:
    deploy:
      resources:
        limits:
          memory: 2G      # SQL Server can be memory-hungry
          cpus: '1.0'
        reservations:
          memory: 1G
          cpus: '0.5'

  xafapp:
    deploy:
      resources:
        limits:
          memory: 1G      # Adjust based on your app's needs
          cpus: '0.5'
        reservations:
          memory: 512M
          cpus: '0.25'
```

**Benefits:**
- Prevents one service from consuming all resources
- Dokploy can better manage multi-tenant deployments
- Predictable performance under load

### 6. Volume Backup Strategy

**Already Configured:** Named volume for SQL Server data persistence
```yaml
volumes:
  sqlserver-data:
    driver: local
```

**Dokploy Integration:**
1. Enable automatic volume backups in Dokploy UI
2. Set backup schedule (recommended: daily at minimum)
3. Test restore procedure before production launch

**Manual Backup Script** (for critical deployments):
```bash
#!/bin/bash
# backup-database.sh
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
docker exec xafdocker-sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SQL_SA_PASSWORD" -C \
  -Q "BACKUP DATABASE XAFDocker TO DISK = '/var/opt/mssql/backup/XAFDocker_${BACKUP_DATE}.bak' WITH FORMAT"

# Copy to host for safekeeping
docker cp xafdocker-sqlserver:/var/opt/mssql/backup/XAFDocker_${BACKUP_DATE}.bak \
  ./backups/
```

### 7. Security Hardening

**Port Exposure Review:**
```yaml
# Development (current)
ports:
  - "1433:1433"  # SQL Server - EXPOSED
  - "5080:80"    # XAF App - EXPOSED

# Production (recommended)
ports:
  # - "1433:1433"  # REMOVE - SQL Server should NOT be exposed
  - "5080:80"      # XAF App - Dokploy will handle SSL termination via reverse proxy
```

**Recommendations:**
1. **Never expose SQL Server port (1433) in production**
2. **Keep app port (5080) for Dokploy's reverse proxy**
3. **Let Dokploy manage SSL/TLS termination** via its built-in reverse proxy

### 8. Logging Configuration

**Add to xafapp service for better troubleshooting:**
```yaml
xafapp:
  logging:
    driver: "json-file"
    options:
      max-size: "10m"      # Rotate logs at 10MB
      max-file: "3"        # Keep 3 rotated files
      compress: "true"     # Compress rotated logs
```

**Benefits:**
- Prevents disk space exhaustion from logs
- Makes log viewing in Dokploy faster
- Maintains reasonable history for debugging

### 9. Production vs Development Profiles

**Consider creating separate compose files:**

**docker-compose.yml** (base configuration)
```yaml
# Shared configuration
```

**docker-compose.prod.yml** (production overrides)
```yaml
version: '3.3'
services:
  xafapp:
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
    # Remove development ports
    ports: []
    deploy:
      resources:
        limits:
          memory: 1G
```

**Deploy to Dokploy:**
- Point Dokploy to `docker-compose.yml`
- Use environment variables to control behavior
- Or merge files: `docker-compose -f docker-compose.yml -f docker-compose.prod.yml`

### 10. Monitoring and Alerting

**Dokploy Built-in Monitoring:**
- Service health status (automatic)
- Container restart counts
- Resource usage graphs

**Additional Recommendations:**
1. **Enable Dokploy notifications** for:
   - Container restarts
   - Failed deployments
   - Health check failures

2. **Application-level monitoring:**
   - Add logging provider (Serilog, NLog)
   - Consider APM tools (Application Insights, Elastic APM)
   - Monitor XAF-specific metrics (session counts, DB query times)

3. **Database monitoring:**
   ```sql
   -- Monitor database size growth
   SELECT
       name AS DatabaseName,
       size * 8 / 1024 AS SizeMB
   FROM sys.master_files
   WHERE database_id = DB_ID('XAFDocker');
   ```

### Summary: Quick Wins for Production

**Immediate Actions:**
- ✅ Use version 3.3 (already done)
- ✅ Configure strong passwords in Dokploy
- ✅ Enable volume backups
- ⚠️ Remove SQL Server port exposure
- ⚠️ Set ASPNETCORE_ENVIRONMENT=Production
- ⚠️ Add resource limits
- ⚠️ Configure log rotation

**Before Going Live:**
- Test backup restoration
- Configure domain and SSL
- Set up monitoring alerts
- Document deployment process
- Create rollback plan

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 0: "service has neither an image nor a build context specified" (RESOLVED)

**Symptoms**: Deployment fails with errors related to missing service definitions.

**Cause**: You're using an outdated version of docker-compose files.

**Solution**:
1. Pull the latest changes from GitHub: `git pull origin main` or `git pull origin without-nginx`
2. The updated compose files are complete and self-contained
3. In Dokploy, set **Docker Compose File Path** to: `docker-compose.prod.yml`
4. Redeploy

**Status**: ✅ This issue is fixed in the latest version (March 2026)

#### Issue 1: SQL Server Container Won't Start

**Symptoms**: `xafdocker-sqlserver` shows "Exited" or keeps restarting

**Solutions**:
```bash
# Check logs
docker compose logs sqlserver

# Common causes:
# 1. Weak password - must include uppercase, lowercase, numbers, symbols
# 2. Insufficient memory - SQL Server needs at least 2GB RAM
# 3. Volume permission issues

# Fix: Update SQL_SA_PASSWORD to meet requirements
# Example: MyStr0ng!P@ssw0rd2026
```

#### Issue 2: XAF Application Can't Connect to Database

**Symptoms**: Application logs show database connection errors

**Solutions**:
1. **Verify SQL Server is healthy**:
   ```bash
   docker compose ps
   # sqlserver should show "healthy" status
   ```

2. **Check connection string**:
   - Verify `SQL_SA_PASSWORD` matches in all services
   - Ensure connection string uses `Server=sqlserver,1433` (not localhost)

3. **Test connectivity**:
   ```bash
   docker exec xafdocker-app ping sqlserver
   ```

#### Issue 3: Application Builds but Returns 502/503 Errors

**Symptoms**: Dokploy proxy returns gateway errors

**Solutions**:
1. **Check XAF app is actually running**:
   ```bash
   docker compose logs xafapp | tail -50
   # Look for "Application started" message
   ```

2. **Verify app is listening on correct port**:
   ```bash
   docker exec xafdocker-app netstat -tuln | grep 80
   # Should show port 80 listening
   ```

3. **Check healthcheck endpoint**:
   ```bash
   curl http://localhost:5080/health
   # Should return HTTP 200 OK
   ```

4. **If health endpoint doesn't exist**, update docker-compose.yml:
   ```yaml
   healthcheck:
     test: ["CMD", "curl", "-f", "http://localhost:80"]  # Remove /health
   ```

#### Issue 5: Database Changes Not Persisting After Restart

**Symptoms**: Data is lost when containers restart

**Solutions**:
1. **Verify volume is mounted**:
   ```bash
   docker volume ls | grep sqlserver-data
   docker volume inspect xafdocker_sqlserver-data
   ```

2. **Check volume backup settings** in Dokploy

3. **Manual data verification**:
   ```bash
   docker exec xafdocker-sqlserver /opt/mssql-tools18/bin/sqlcmd \
     -S localhost -U sa -P "<password>" -C \
     -Q "SELECT COUNT(*) FROM XAFDocker.sys.tables"
   ```

### Getting Help

If issues persist:

1. **Dokploy Documentation**: [docs.dokploy.com](https://docs.dokploy.com/)
2. **Dokploy Community**: GitHub Discussions at [github.com/Dokploy/dokploy](https://github.com/Dokploy/dokploy)
3. **DevExpress XAF Support**: [devexpress.com/support](https://www.devexpress.com/support/)
4. **Check application logs** for detailed error messages

### Debug Mode

To enable verbose logging:

1. **XAF Application**:
   ```yaml
   environment:
     - ASPNETCORE_ENVIRONMENT=Development
     - Logging__LogLevel__Default=Debug
   ```

2. **SQL Server**:
   ```yaml
   environment:
     - MSSQL_LOG_LEVEL=debug
   ```

---

## Additional Resources

### Official Documentation

- **Dokploy**: [Docker Compose Deployment Guide](https://docs.dokploy.com/docs/core/docker-compose)
- **DevExpress XAF**: [Documentation](https://docs.devexpress.com/eXpressAppFramework/112649/expressapp-framework)
- **Docker Compose**: [Official Reference](https://docs.docker.com/compose/)

### Useful Commands

```bash
# View all containers
docker compose ps

# View logs for all services
docker compose logs -f

# Restart a specific service
docker compose restart xafapp

# View resource usage
docker stats

# Access SQL Server directly
docker exec -it xafdocker-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C

# Clean up and rebuild
docker compose down
docker compose up -d --build
```

---

## Deployment Checklist

Use this checklist for your deployment:

### Pre-Deployment
- [ ] Repository pushed to GitHub
- [ ] Strong `SQL_SA_PASSWORD` generated
- [ ] New `URL_SIGNING_KEY` GUID generated
- [ ] Domain name configured (if using)
- [ ] DNS A record pointing to server
- [ ] `.env` values ready for Dokploy

### Dokploy Setup
- [ ] Dokploy instance installed/accessed
- [ ] Project created in Dokploy
- [ ] Application added with GitHub repository
- [ ] Environment variables configured
- [ ] Volume settings verified
- [ ] Domain configured (if applicable)

### Deployment
- [ ] Initial deployment triggered
- [ ] All containers started successfully
- [ ] SQL Server healthcheck passing
- [ ] XAF app healthcheck passing
- [ ] Database schema updated automatically

### Post-Deployment
- [ ] Application accessible via URL
- [ ] SSL certificate obtained (if using custom domain)
- [ ] Login successful with admin credentials
- [ ] Default passwords changed
- [ ] Backups configured
- [ ] Webhook configured for auto-deploy (optional)

### Production Checklist
- [ ] `ASPNETCORE_ENVIRONMENT=Production`
- [ ] Monitoring/alerts configured
- [ ] Backup schedule established
- [ ] Security review completed
- [ ] Documentation updated with deployment details

---

## Support and Maintenance

### Regular Maintenance Tasks

**Weekly:**
- Review application logs for errors
- Check disk space usage
- Verify backups are running

**Monthly:**
- Update Docker images for security patches
- Review and rotate logs
- Test backup restoration process

**As Needed:**
- Update DevExpress XAF packages
- Deploy application updates via git push
- Scale resources if needed

---

## Lessons Learned

Real-world deployment insights from successful Dokploy production deployment.

### Critical Success Factors

#### 1. Docker Compose Version Matters

**Problem Encountered:**
- Initial docker-compose.yml used version 3.8 with modern syntax
- Dokploy's infrastructure couldn't parse default value syntax `${VAR:-default}`
- Deployment failed with: `Invalid interpolation format` errors

**Solution Applied:**
```yaml
# Changed from version 3.8 to 3.3
version: '3.3'

# Removed default value syntax
- MSSQL_SA_PASSWORD=${SQL_SA_PASSWORD}  # ✅ Works
# Instead of:
- MSSQL_SA_PASSWORD=${SQL_SA_PASSWORD:-YourStrong!Passw0rd}  # ❌ Failed
```

**Lesson:** Always use version 3.3 for maximum Docker Compose compatibility across different platforms and versions.

#### 2. Healthcheck Format Is Critical

**Problem Encountered:**
- Original healthcheck used bare string format
- Different Docker Compose versions parse this inconsistently
- Some platforms failed to execute healthchecks properly

**Solution Applied:**
```yaml
# Changed to explicit array format
healthcheck:
  test: ["CMD-SHELL", "/opt/mssql-tools18/bin/sqlcmd ..."]

# Instead of:
healthcheck:
  test: /opt/mssql-tools18/bin/sqlcmd ...
```

**Lesson:** Always use array format `["CMD-SHELL", "command"]` for healthcheck tests. It's unambiguous and works everywhere.

#### 3. Feature Availability in Compose Versions

**Problem Encountered:**
- Used `start_period` in healthchecks (added in Compose 3.4)
- Used `condition: service_healthy` in depends_on (requires Compose 2.1+ or 3.9+)
- Dokploy rejected these features with "Additional properties not allowed" errors

**Solution Applied:**
```yaml
# Removed start_period entirely
healthcheck:
  test: ["CMD-SHELL", "command"]
  interval: 10s
  timeout: 3s
  retries: 10
  # start_period: 10s  # ❌ Removed

# Simplified depends_on
depends_on:
  - sqlserver  # ✅ Simple array format

# Instead of:
depends_on:
  sqlserver:
    condition: service_healthy  # ❌ Not supported in 3.3
```

**Lesson:** Stick to features available in Compose 3.3. Check [Docker Compose version compatibility matrix](https://docs.docker.com/compose/compose-file/compose-versioning/) when in doubt.

#### 4. Environment Variable Best Practices

**What Worked:**
- Using `.env` file for all configuration
- Configuring variables in Dokploy UI (Environment tab)
- Dokploy automatically creates `.env` file during deployment
- No secrets in Git repository

**Configuration Flow:**
1. Git repo contains `docker-compose.yml` with `${VARIABLE}` references
2. `.env` file in `.gitignore` (not committed)
3. Variables configured in Dokploy dashboard
4. Dokploy injects variables during deployment

**Lesson:** Never hardcode sensitive values. Let the platform handle environment variable injection.

### Performance Insights

#### Database Startup Time

**Observation:**
- SQL Server container takes 20-40 seconds to become healthy
- First-time deployment takes longer (pulling 1GB+ image)
- Subsequent deployments are faster (cached image)

**Optimization:**
- Increased healthcheck retries to 10 (allows up to 100 seconds startup)
- XAF app gracefully retries DB connections
- No need for `start_period` workaround

#### Application Startup

**Observation:**
- XAF app typically starts in 10-15 seconds after SQL Server is healthy
- Database schema auto-updates on first run (adds 5-10 seconds)
- Healthcheck confirms app is serving traffic

**Optimization:**
- 30-second healthcheck interval is sufficient
- 3 retries provides 90 seconds for startup
- Reduces unnecessary health check overhead

### Deployment Workflow

**What Works Best:**

1. **Local Testing First:**
   ```bash
   # Always test locally before pushing
   docker compose up -d
   # Verify all services healthy
   docker compose ps
   ```

2. **Incremental Changes:**
   - Make small, testable changes
   - Commit frequently with clear messages
   - Dokploy webhook auto-deploys on push

3. **Monitoring During Deployment:**
   - Watch Dokploy deployment logs in real-time
   - Check each service status as it starts
   - Verify healthchecks pass before declaring success

### Common Pitfalls Avoided

#### ❌ Pitfall 1: Assuming Modern Syntax Support
- **Issue:** Using latest Docker Compose features
- **Impact:** Deployment failures, cryptic error messages
- **Solution:** Stick to version 3.3 syntax

#### ❌ Pitfall 2: Ignoring Healthchecks
- **Issue:** No healthchecks or poorly configured ones
- **Impact:** Dokploy can't determine service health
- **Solution:** Add proper healthchecks with realistic timeouts

#### ❌ Pitfall 3: Exposing Database Ports
- **Issue:** SQL Server port 1433 exposed to internet
- **Impact:** Security vulnerability
- **Solution:** Remove port exposure in production, access via internal network only

#### ❌ Pitfall 4: No Volume Backups
- **Issue:** Relying solely on volume persistence
- **Impact:** Data loss if volume corrupted or deleted
- **Solution:** Enable Dokploy volume backups + manual SQL backups

#### ❌ Pitfall 5: Development Settings in Production
- **Issue:** `ASPNETCORE_ENVIRONMENT=Development` in production
- **Impact:** Verbose errors, debug middleware, performance overhead
- **Solution:** Always set `ASPNETCORE_ENVIRONMENT=Production`

### Success Metrics

After applying these optimizations, the deployment achieves:

- ✅ **Zero-downtime updates** via Dokploy's rolling deployment
- ✅ **~2 minute total deployment time** (build + start + healthcheck)
- ✅ **Consistent startup sequence** across deployments
- ✅ **Automatic database migrations** on deployment
- ✅ **Health monitoring** via built-in checks
- ✅ **No manual intervention** required for standard deployments

### Recommended Workflow Summary

```bash
# 1. Develop locally
docker compose up -d
# Test changes

# 2. Commit changes
git add .
git commit -m "Feature: Add new functionality"

# 3. Push to GitHub
git push origin main

# 4. Dokploy auto-deploys via webhook
# Watch deployment in Dokploy dashboard

# 5. Verify production
curl https://your-domain.com
# Check service health in Dokploy
```

### Future Improvements to Consider

1. **Multi-stage deployments:**
   - Add staging environment
   - Test in staging before production
   - Use Git branches for environments

2. **Blue-green deployments:**
   - Run two versions simultaneously
   - Switch traffic after verification
   - Instant rollback capability

3. **Database migration strategy:**
   - Separate migration step before app deployment
   - Backward-compatible schema changes
   - Better control over migration timing

4. **Advanced monitoring:**
   - Application Performance Monitoring (APM)
   - Custom metrics from XAF application
   - Integration with external monitoring services

5. **Automated testing:**
   - Pre-deployment health checks
   - Smoke tests after deployment
   - Rollback on test failures

---

**Last Updated**: March 2026
**Version**: 2.0 (Production-Tested)
**Dokploy Compatibility**: v1.x (Verified)
**Docker Compose Version**: 3.3 (Recommended)
