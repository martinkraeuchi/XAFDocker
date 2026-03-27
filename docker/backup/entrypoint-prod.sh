#!/bin/bash
# Backup Container Entrypoint for Production (Dokploy)
# Sets up permissions and keeps container running
# Scheduling handled by Dokploy Scheduled Tasks

set -euo pipefail

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Backup service starting (Dokploy mode)"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Database: ${BACKUP_DATABASE:-XAFDocker}"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Scheduling handled by Dokploy"

# Ensure backup directory has correct permissions
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Setting /backups permissions to 777"
mkdir -p /backups
chmod 777 /backups

# Validate required environment variables
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Validating environment variables..."
: "${SQL_SA_PASSWORD:?SQL_SA_PASSWORD is required}"
: "${FTP_HOST:?FTP_HOST is required}"
: "${FTP_USER:?FTP_USER is required}"
: "${FTP_PASSWORD:?FTP_PASSWORD is required}"
: "${FTP_PATH:?FTP_PATH is required}"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Environment variables validated"

# Test SQL Server connectivity
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Testing SQL Server connectivity..."
export SQLCMDPASSWORD="$SQL_SA_PASSWORD"
if /opt/mssql-tools18/bin/sqlcmd -S "${SQL_SERVER:-sqlserver},${SQL_PORT:-1433}" -U "${SQL_USER:-sa}" -C -b -Q "SELECT 1" > /dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] SQL Server connection successful"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] SQL Server connection failed, backups will retry when scheduled"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Backup container ready"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] To trigger backup manually: docker exec xafdocker-backup /app/backup.sh"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Container will remain running for Dokploy scheduled tasks"

# Keep container running indefinitely
# Dokploy will execute /app/backup.sh via scheduled tasks
exec tail -f /dev/null
