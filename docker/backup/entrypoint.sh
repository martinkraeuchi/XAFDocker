#!/bin/bash
# Backup Container Entrypoint
# Sets up cron and starts daemon

set -euo pipefail

# Validate required environment variables
: "${SQL_SA_PASSWORD:?SQL_SA_PASSWORD is required}"
: "${FTP_HOST:?FTP_HOST is required}"
: "${FTP_USER:?FTP_USER is required}"
: "${FTP_PASSWORD:?FTP_PASSWORD is required}"
: "${FTP_PATH:?FTP_PATH is required}"

# Generate crontab from BACKUP_SCHEDULE
BACKUP_SCHEDULE="${BACKUP_SCHEDULE:-30 23 * * *}"
echo "$BACKUP_SCHEDULE /app/backup.sh >> /proc/1/fd/1 2>&1" | crontab -

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Backup service starting"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Schedule: $BACKUP_SCHEDULE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Database: ${BACKUP_DATABASE:-XAFDocker}"

# Test SQL Server connectivity
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Testing SQL Server connectivity..."
export SQLCMDPASSWORD="$SQL_SA_PASSWORD"
if /opt/mssql-tools18/bin/sqlcmd -S "${SQL_SERVER:-sqlserver},${SQL_PORT:-1433}" -U "${SQL_USER:-sa}" -C -b -Q "SELECT 1" > /dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] SQL Server connection successful"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] SQL Server connection failed, will retry on schedule"
fi

# Start cron in foreground
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Starting cron daemon"
exec cron -f
