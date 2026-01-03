# XAFDocker Operations Guide

Complete guide for managing, rebuilding, and recreating Docker containers and the XAF application.

## Table of Contents

- [Container Management](#container-management)
- [Recreating Containers](#recreating-containers)
- [Database Operations](#database-operations)
- [Backup and Restore](#backup-and-restore)
- [Maintenance](#maintenance)
- [Monitoring](#monitoring)

## Container Management

### Check Container Status

```bash
# List all containers with status
docker compose ps

# Detailed status
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

# Check specific service
docker compose ps xafapp
```

### View Logs

```bash
# Follow all logs
docker compose logs -f

# Specific service logs
docker compose logs -f xafapp
docker compose logs -f sqlserver

# Last 100 lines
docker logs xafdocker-app --tail 100

# Logs since specific time
docker logs xafdocker-app --since 10m
docker logs xafdocker-app --since "2026-01-03T10:00:00"
```

### Start/Stop Services

```bash
# Start all services
docker compose up -d

# Start specific service
docker compose up -d xafapp

# Stop all services
docker compose stop

# Stop specific service
docker compose stop xafapp

# Restart service
docker compose restart xafapp

# Restart all services
docker compose restart
```

## Recreating Containers

### Method 1: Quick Recreate (Keep Data)

Recreates containers without losing database data:

```bash
# Stop and remove containers
docker compose down

# Rebuild images
docker compose build

# Start fresh containers
docker compose up -d

# Verify
docker compose ps
```

### Method 2: Complete Rebuild (Keep Data)

Forces rebuild from scratch, keeps database:

```bash
# Stop all containers
docker compose down

# Rebuild without cache
docker compose build --no-cache

# Start containers
docker compose up -d

# Watch logs during startup
docker compose logs -f xafapp
```

### Method 3: Full Reset (Delete Everything)

**WARNING**: This deletes ALL data including the database!

```bash
# Stop containers and remove volumes
docker compose down -v

# Remove all related images
docker rmi xafdocker-xafapp

# Clean build cache (optional)
docker builder prune -a

# Rebuild from scratch
docker compose build --no-cache

# Start with fresh database
docker compose up -d

# Database will be created automatically
```

### Method 4: Recreate Specific Service

Recreate only one service (e.g., xafapp):

```bash
# Stop and remove specific container
docker compose rm -sf xafapp

# Rebuild the service
docker compose build xafapp

# Recreate and start
docker compose up -d xafapp

# Verify
docker logs xafdocker-app --tail 50
```

### Method 5: In-Place Container Recreate

Update running container with new image:

```bash
# Rebuild the image
docker compose build xafapp

# Recreate container with new image
docker compose up -d --force-recreate xafapp

# Alternative: Recreate all services
docker compose up -d --force-recreate
```

## Database Operations

### Reset Database Schema

Keep container but reset database:

```bash
# Method 1: Using Docker volume
docker compose down
docker volume rm xafdocker_sqlserver-data
docker compose up -d

# Method 2: Drop and recreate database
docker exec xafdocker-sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "YourStrong!Passw0rd" -C \
  -Q "DROP DATABASE XAFDocker; CREATE DATABASE XAFDocker;"

# Then update schema
docker exec xafdocker-app dotnet XAFDocker.Blazor.Server.dll --updateDatabase
```

### Force Database Update

Force database schema update:

```bash
# Using Docker
docker exec xafdocker-app \
  dotnet XAFDocker.Blazor.Server.dll --updateDatabase --forceUpdate

# With silent mode
docker exec xafdocker-app \
  dotnet XAFDocker.Blazor.Server.dll --updateDatabase --forceUpdate --silent
```

### Check Database Version

```bash
# Connect to SQL Server
docker exec -it xafdocker-sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "YourStrong!Passw0rd" -C

# Run query
SELECT * FROM ModuleInfo;
GO
```

## Backup and Restore

### Backup Database

```bash
# Create backup directory in container
docker exec xafdocker-sqlserver mkdir -p /var/opt/mssql/backup

# Backup database
docker exec xafdocker-sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "YourStrong!Passw0rd" -C \
  -Q "BACKUP DATABASE XAFDocker TO DISK='/var/opt/mssql/backup/XAFDocker_$(date +%Y%m%d_%H%M%S).bak'"

# Copy backup to host
docker cp xafdocker-sqlserver:/var/opt/mssql/backup/XAFDocker_*.bak ./backups/

# Backup entire volume
docker run --rm -v xafdocker_sqlserver-data:/data \
  -v $(pwd)/backups:/backup alpine \
  tar czf /backup/sqlserver-data-$(date +%Y%m%d).tar.gz -C /data .
```

### Restore Database

```bash
# Copy backup to container
docker cp ./backups/XAFDocker.bak xafdocker-sqlserver:/var/opt/mssql/backup/

# Restore database
docker exec xafdocker-sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "YourStrong!Passw0rd" -C \
  -Q "RESTORE DATABASE XAFDocker FROM DISK='/var/opt/mssql/backup/XAFDocker.bak' WITH REPLACE"

# Restart application
docker compose restart xafapp
```

### Export/Import Data

```bash
# Export specific table
docker exec xafdocker-sqlserver /opt/mssql-tools18/bin/bcp \
  "SELECT * FROM XAFDocker.dbo.Contacts" queryout /tmp/contacts.csv \
  -S localhost -U sa -P "YourStrong!Passw0rd" -c -t,

# Copy to host
docker cp xafdocker-sqlserver:/tmp/contacts.csv ./data/
```

## Maintenance

### Clean Up Unused Resources

```bash
# Remove stopped containers
docker container prune

# Remove unused images
docker image prune

# Remove unused volumes
docker volume prune

# Remove everything unused (BE CAREFUL!)
docker system prune -a --volumes
```

### Update Application Code

After code changes:

```bash
# 1. Rebuild image
docker compose build xafapp

# 2. Recreate container
docker compose up -d --force-recreate xafapp

# 3. Watch logs for errors
docker compose logs -f xafapp

# 4. Verify database updated
# Check logs for "Database update completed successfully"
```

### Update DevExpress Version

```bash
# 1. Update version in .csproj files
# XAFDocker.Module/XAFDocker.Module.csproj
# XAFDocker.Blazor.Server/XAFDocker.Blazor.Server.csproj

# 2. Clear NuGet cache
docker compose down
rm -rf ./XAFDocker.Module/bin ./XAFDocker.Module/obj
rm -rf ./XAFDocker.Blazor.Server/bin ./XAFDocker.Blazor.Server/obj

# 3. Rebuild
docker compose build --no-cache xafapp

# 4. Start and update database
docker compose up -d
docker logs xafdocker-app -f
```

## Monitoring

### Resource Usage

```bash
# Container resource usage
docker stats

# Specific container
docker stats xafdocker-app xafdocker-sqlserver

# One-time snapshot
docker stats --no-stream
```

### Health Checks

```bash
# Check health status
docker inspect --format='{{.State.Health.Status}}' xafdocker-app
docker inspect --format='{{.State.Health.Status}}' xafdocker-sqlserver

# View health check logs
docker inspect xafdocker-app | grep -A 10 Health
```

### Disk Usage

```bash
# Docker disk usage
docker system df

# Detailed breakdown
docker system df -v

# Volume sizes
docker volume ls
docker volume inspect xafdocker_sqlserver-data
```

## Complete Rebuild Workflow

### Scenario: Fresh Start After Code Changes

```bash
# Step 1: Stop everything
docker compose down

# Step 2: Clean up (optional - removes database)
docker volume rm xafdocker_sqlserver-data  # Only if you want fresh DB

# Step 3: Rebuild images
docker compose build --no-cache

# Step 4: Start services
docker compose up -d

# Step 5: Monitor startup
docker compose logs -f xafapp

# Step 6: Wait for healthy status
watch docker compose ps

# Step 7: Test application
curl http://localhost:5080
```

### Scenario: Update Single Service

```bash
# Example: Update only XAF application

# Step 1: Rebuild app image
docker compose build xafapp

# Step 2: Recreate container
docker compose up -d --force-recreate --no-deps xafapp

# Step 3: Verify
docker compose ps xafapp
docker logs xafdocker-app --tail 50
```

### Scenario: Migrate to Production

```bash
# Step 1: Backup current data
docker exec xafdocker-sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "YourStrong!Passw0rd" -C \
  -Q "BACKUP DATABASE XAFDocker TO DISK='/var/opt/mssql/backup/pre-prod.bak'"

# Step 2: Update environment
sed -i 's/ASPNETCORE_ENVIRONMENT=Development/ASPNETCORE_ENVIRONMENT=Production/' docker-compose.yml

# Step 3: Update passwords in .env
vi .env

# Step 4: Rebuild for production
docker compose build --no-cache

# Step 5: Deploy
docker compose down
docker compose up -d

# Step 6: Verify
docker compose logs -f
```

## Troubleshooting Recreate Issues

### Container Won't Start

```bash
# Check logs
docker logs xafdocker-app --tail 100

# Check for port conflicts
netstat -tlnp | grep :5080
lsof -i :5080

# Force remove and recreate
docker rm -f xafdocker-app
docker compose up -d xafapp
```

### Database Connection Failed After Recreate

```bash
# Verify SQL Server is healthy
docker compose ps sqlserver

# Check SQL Server logs
docker logs xafdocker-sqlserver --tail 50

# Test connection
docker exec xafdocker-sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "YourStrong!Passw0rd" -Q "SELECT 1" -C

# Restart both services
docker compose restart sqlserver
sleep 10
docker compose restart xafapp
```

### Volume Permission Issues

```bash
# Fix permissions on volume
docker run --rm -v xafdocker_sqlserver-data:/data alpine \
  chmod -R 755 /data

# Recreate with proper permissions
docker compose down
docker volume rm xafdocker_sqlserver-data
docker compose up -d
```

## Quick Reference

### Most Common Operations

```bash
# Quick restart after code change
docker compose build xafapp && docker compose up -d xafapp

# Fresh start (keep database)
docker compose down && docker compose build && docker compose up -d

# Complete reset (lose database)
docker compose down -v && docker compose build --no-cache && docker compose up -d

# Check if everything is healthy
docker compose ps && docker stats --no-stream

# View application logs
docker logs xafdocker-app -f --tail 100

# Force database update
docker exec xafdocker-app dotnet XAFDocker.Blazor.Server.dll --updateDatabase --forceUpdate
```

### Container Lifecycle Commands

```bash
# Stop
docker compose stop

# Start
docker compose start

# Restart
docker compose restart

# Remove
docker compose down

# Remove with volumes
docker compose down -v

# Recreate
docker compose up -d --force-recreate

# Rebuild and recreate
docker compose up -d --build --force-recreate
```

---

**Note**: Always ensure you have backups before performing destructive operations!
