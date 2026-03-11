# Production Deployment Quick Start

This guide provides a streamlined path to production deployment on Dokploy with optimized configuration.

## 🚀 Quick Deploy Checklist

### Before You Start (5 minutes)

- [ ] Have a Dokploy account (self-hosted or managed)
- [ ] GitHub repository is up to date
- [ ] Generated strong passwords (see below)
- [ ] Domain name configured (optional - Dokploy handles SSL)

### Generate Secure Credentials

```bash
# Generate strong SQL password
openssl rand -base64 32

# Generate URL signing key (GUID)
# Linux/Mac:
uuidgen

# PowerShell:
[guid]::NewGuid()
```

Save these values - you'll need them in Dokploy.

---

## 📋 Deployment Steps

### Step 1: Create Dokploy Project (2 minutes)

1. Log into Dokploy
2. Click **"New Project"**
3. Name: `XAF Blazor Production`

### Step 2: Add Application (3 minutes)

1. **Add Application** → **Docker Compose**
2. **Repository**: `https://github.com/martinkraeuchi/XAFDocker.git`
3. **Branch**: `main`
4. **Compose File**: `docker-compose.yml`

### Step 3: Configure Environment Variables (2 minutes)

Navigate to **Environment** tab and add:

```
SQL_SA_PASSWORD=<your-generated-password>
URL_SIGNING_KEY=<your-generated-guid>
```

**Critical:** Use the passwords you generated above, not the examples!

### Step 4: Configure Domain (Optional, 3 minutes)

If using a custom domain:

1. **DNS Configuration**:
   - Add A record: `your-domain.com` → `<your-dokploy-ip>`
   - Wait 5-10 minutes for DNS propagation

2. **Dokploy Domain Settings**:
   - Navigate to **Domains** tab
   - Add: `your-domain.com`
   - Enable SSL - Dokploy automatically obtains and manages Let's Encrypt certificates

### Step 5: Deploy (1 minute)

1. Click **"Deploy"** button
2. Watch logs in real-time
3. Wait for "Deployment successful" message (~2-3 minutes)

### Step 6: Verify (2 minutes)

1. **Check Service Status**: All should show "Running" and "Healthy"
2. **Access Application**:
   - With domain: `https://your-domain.com`
   - Direct access: `http://<server-ip>:5080`
   - Dokploy proxy: URL in dashboard

3. **Test Login**: Use default XAF credentials
4. **Change Passwords**: Update admin password immediately

---

## 🔧 Production Optimizations

### Option A: Use Production Compose File

Apply production-specific optimizations:

```bash
# In Dokploy, change Compose File to:
docker-compose.prod.yml
```

**Benefits:**
- `ASPNETCORE_ENVIRONMENT=Production`
- Resource limits configured
- SQL Server port not exposed
- Log rotation enabled
- Optimized for production workloads

### Option B: Environment Variable Override

Keep using `docker-compose.yml` but override in Dokploy Environment tab:

```
ASPNETCORE_ENVIRONMENT=Production
Logging__LogLevel__Default=Warning
```

---

## 📊 Post-Deployment Configuration

### Enable Backups (5 minutes)

**Automated (Recommended):**
1. Dokploy dashboard → **Volumes** tab
2. Find `sqlserver-data`
3. Enable **Automatic Backups**
4. Set schedule: Daily at 2 AM
5. Retention: 7 days minimum

**Manual Backup Script:**
```bash
#!/bin/bash
# Run this weekly for extra safety
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
docker exec xafdocker-sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SQL_SA_PASSWORD" -C \
  -Q "BACKUP DATABASE XAFDocker TO DISK = '/var/opt/mssql/backup/XAFDocker_${BACKUP_DATE}.bak'"
```

### Setup Monitoring (3 minutes)

1. **Dokploy Alerts**:
   - Settings → Notifications
   - Enable email/Slack notifications
   - Configure for: Container restarts, failed deployments

2. **Health Monitoring**:
   - Healthchecks are automatic
   - View in dashboard under **Services**

### Configure Auto-Deploy (Optional, 3 minutes)

**Webhook for Continuous Deployment:**

1. Dokploy → **Settings** → **Webhooks**
2. Copy webhook URL
3. GitHub repo → **Settings** → **Webhooks** → **Add webhook**
4. Paste URL
5. Select events: `push` to `main` branch
6. Save

**Result:** Every `git push` to main automatically deploys to production.

---

## 🔒 Security Hardening

### Production Security Checklist

- [ ] Strong SQL password (minimum 16 characters)
- [ ] Unique URL signing key (new GUID)
- [ ] SQL Server port NOT exposed (remove 1433 from ports)
- [ ] ASPNETCORE_ENVIRONMENT=Production
- [ ] SSL/HTTPS enabled (via Dokploy reverse proxy)
- [ ] Default admin password changed
- [ ] Database backups configured
- [ ] Firewall rules configured (if self-hosted)

### Recommended Port Configuration

**Development (current):**
```yaml
ports:
  - "1433:1433"  # SQL Server
  - "5080:80"    # Direct app access
```

**Production (recommended):**
```yaml
ports:
  # Remove SQL Server port entirely for security
  - "5080:80"    # Application port for Dokploy reverse proxy
```

**Best Practice:** Let Dokploy's reverse proxy handle all external traffic and SSL termination. Only expose the application port (5080) internally for the proxy.

---

## 📈 Performance Tuning

### Resource Allocation

Current configuration works for:
- **Small deployments**: 10-50 concurrent users
- **Database size**: Up to 10GB
- **Memory**: 2GB SQL Server + 1GB App = 3GB total

**For larger deployments**, adjust in `docker-compose.prod.yml`:

```yaml
services:
  sqlserver:
    deploy:
      resources:
        limits:
          memory: 4G      # Increase for larger databases
          cpus: '2.0'     # More CPU for heavy queries

  xafapp:
    deploy:
      resources:
        limits:
          memory: 2G      # Increase for more concurrent users
          cpus: '1.0'
```

### Database Performance

**Connection pooling** is configured in connection string:
```
MultipleActiveResultSets=True
```

**For high-traffic sites**, consider:
- Increasing SQL Server memory limit
- Adding database indexes (via XAF attributes)
- Enabling query result caching in XAF

---

## 🔄 Update and Rollback Procedures

### Deploying Updates

**Method 1: Automatic (with webhook)**
```bash
# On your local machine
git add .
git commit -m "Update: Description of changes"
git push origin main
# Dokploy automatically deploys
```

**Method 2: Manual Deploy**
1. Push changes to GitHub
2. Dokploy dashboard → Click **"Deploy"**
3. Monitor deployment logs

### Rollback Procedure

**If deployment fails:**

1. **Dokploy Dashboard** → **Deployments** tab
2. View deployment history (last 10 shown)
3. Click **"Rollback"** on previous successful deployment
4. Confirm rollback

**Manual rollback via Git:**
```bash
# Find commit hash of working version
git log --oneline -10

# Revert to that commit
git revert <commit-hash>
git push origin main
# Dokploy redeploys previous version
```

**Database rollback:**
```bash
# Restore from backup
docker exec xafdocker-sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SQL_SA_PASSWORD" -C \
  -Q "RESTORE DATABASE XAFDocker FROM DISK = '/var/opt/mssql/backup/XAFDocker_backup.bak' WITH REPLACE"
```

---

## 🐛 Common Issues

### Issue: Deployment Succeeds but App Returns 502/503

**Cause:** XAF app hasn't fully started or healthcheck failing

**Solution:**
```bash
# Check logs
docker compose logs xafapp --tail 50

# Common causes:
# 1. SQL Server not ready → wait 30 more seconds
# 2. Database connection failed → check SQL_SA_PASSWORD
# 3. Missing environment variable → verify all vars in Dokploy
```

### Issue: SSL Certificate Not Generated

**Cause:** Domain not pointing to server or Dokploy SSL configuration issue

**Solution:**
1. Verify DNS: `nslookup your-domain.com`
2. Check Dokploy domain settings - ensure SSL is enabled
3. Verify domain is properly added in Dokploy Domains tab
4. Dokploy automatically handles Let's Encrypt certificates - no manual configuration needed

### Issue: Database Changes Not Persisting

**Cause:** Volume not properly mounted

**Solution:**
```bash
# Verify volume exists
docker volume ls | grep sqlserver-data

# Check volume is mounted
docker inspect xafdocker-sqlserver | grep sqlserver-data

# If missing, recreate with volume:
docker compose down
docker compose up -d
```

---

## 📞 Support Resources

### Documentation
- [Dokploy Docs](https://docs.dokploy.com/)
- [DevExpress XAF Docs](https://docs.devexpress.com/eXpressAppFramework/)
- [Full Deployment Guide](./DEPLOYMENT_DOKPLOY.md)

### Quick Commands

```bash
# View all containers
docker compose ps

# Check logs
docker compose logs -f xafapp

# Restart service
docker compose restart xafapp

# Resource usage
docker stats

# Database connection test
docker exec xafdocker-sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SQL_SA_PASSWORD" -C \
  -Q "SELECT @@VERSION"
```

---

## ✅ Production Launch Checklist

**Before Going Live:**
- [ ] All services healthy in Dokploy dashboard
- [ ] Application accessible via domain
- [ ] SSL certificate valid and auto-renewing
- [ ] Database backups configured and tested
- [ ] Admin password changed from default
- [ ] Monitoring and alerts configured
- [ ] Rollback procedure tested
- [ ] Documentation updated with production URLs

**After Going Live:**
- [ ] Monitor application logs for 24 hours
- [ ] Verify backups are running
- [ ] Test critical user workflows
- [ ] Document any production-specific configuration
- [ ] Share production access with team (if applicable)

---

**Estimated Total Setup Time:** 20-30 minutes
**Deployment Method:** Dokploy with Docker Compose
**Configuration Complexity:** Low (production-ready defaults)
**Maintenance Required:** Minimal (automated updates available)
