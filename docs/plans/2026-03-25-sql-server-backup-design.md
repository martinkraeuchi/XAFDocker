# SQL Server Backup System Design

**Date:** 2026-03-25
**Author:** Claude Code
**Status:** Approved for Implementation

## Overview

Automated daily backup system for XAFDocker SQL Server database with FTP transfer and webhook notifications.

## Requirements

- Daily backups at 11:30 PM
- Backup filename format: `xafdocker{YYYYMMDDHHMM}.bak`
- Store backups locally in Docker volume
- Transfer to FTP server immediately after backup
- 7-day retention (local and FTP)
- Webhook notifications on failures
- Clean separation using dedicated backup container

## Architecture

### Container Design

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│  SQL Server     │────▶│  Backup Volume   │◀────│   Backup    │
│  Container      │     │  (shared mount)  │     │  Container  │
└─────────────────┘     └──────────────────┘     └──────┬──────┘
                                                         │
                                                         ▼
                                                  ┌─────────────┐
                                                  │ FTP Server  │
                                                  │  (remote)   │
                                                  └─────────────┘
```

### Components

1. **Backup Container**
   - Base image: `mcr.microsoft.com/mssql-tools:latest`
   - Additional packages: lftp, curl, cron, findutils
   - Runs cron daemon for scheduling
   - Executes backup script on schedule

2. **Shared Volume**
   - Docker volume `backup-data` mounted at `/backups`
   - Accessible to both SQL Server and backup containers
   - Stores backup files locally

3. **FTP Integration**
   - Immediate transfer after successful backup
   - Uses lftp for robust file transfer
   - Supports FTP and FTPS

4. **Webhook Notifications**
   - Generic webhook (works with Slack, Discord, Teams, etc.)
   - Notifies on backup, FTP, or cleanup failures
   - Includes detailed error context

## Backup Workflow

### Process Flow

1. **Generate filename** with timestamp: `xafdocker202603252330.bak`
2. **Execute T-SQL BACKUP command** via sqlcmd:
   ```sql
   BACKUP DATABASE [XAFDocker]
   TO DISK = '/backups/xafdocker202603252330.bak'
   WITH FORMAT, COMPRESSION, CHECKSUM
   ```
3. **Verify backup completed** - check sqlcmd exit code and file exists
4. **Transfer to FTP immediately** - upload to configured FTP path
5. **Verify FTP upload** - check file size matches local file
6. **Cleanup old local backups** - delete files older than 7 days
7. **Cleanup old FTP backups** - delete files older than 7 days
8. **Log success** - write completion message with file size and duration

### Schedule

- **Cron expression:** `30 23 * * *` (11:30 PM daily)
- **Timezone:** Configurable via `TZ` environment variable
- **Default timezone:** Europe/Berlin

## Configuration

### Environment Variables

```bash
# SQL Server Backup Configuration
BACKUP_SCHEDULE=30 23 * * *           # Daily at 11:30 PM
BACKUP_RETENTION_DAYS=7               # Keep backups for 7 days
BACKUP_DATABASE=XAFDocker             # Database name to backup
TZ=Europe/Berlin                      # Timezone for cron schedule

# FTP Configuration
FTP_HOST=ftp.example.com              # FTP server hostname/IP
FTP_PORT=21                           # FTP port (default 21)
FTP_USER=backupuser                   # FTP username
FTP_PASSWORD=secure_password          # FTP password
FTP_PATH=/backups/xafdocker           # Remote path for backups
FTP_USE_TLS=true                      # Use FTPS (FTP over TLS)

# Webhook Notification Configuration
WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
WEBHOOK_ENABLED=true                  # Enable/disable notifications
WEBHOOK_NOTIFY_SUCCESS=false          # Optional: notify on success
```

### Docker Compose Configuration

```yaml
backup:
  build:
    context: ./docker/backup
    dockerfile: Dockerfile
  container_name: xafdocker-backup
  depends_on:
    - sqlserver
  environment:
    - SQL_SA_PASSWORD=${SQL_SA_PASSWORD}
    - BACKUP_SCHEDULE=${BACKUP_SCHEDULE}
    - BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS}
    - BACKUP_DATABASE=${BACKUP_DATABASE}
    - TZ=${TZ}
    - FTP_HOST=${FTP_HOST}
    - FTP_PORT=${FTP_PORT}
    - FTP_USER=${FTP_USER}
    - FTP_PASSWORD=${FTP_PASSWORD}
    - FTP_PATH=${FTP_PATH}
    - FTP_USE_TLS=${FTP_USE_TLS}
    - WEBHOOK_URL=${WEBHOOK_URL}
    - WEBHOOK_ENABLED=${WEBHOOK_ENABLED}
  volumes:
    - backup-data:/backups
  networks:
    - xafdocker-network
  restart: unless-stopped
  healthcheck:
    test: ["CMD", "pgrep", "crond"]
    interval: 60s
    timeout: 3s
    retries: 3

volumes:
  backup-data:
    driver: local
```

## Implementation Details

### Backup Script (`/app/backup.sh`)

#### Main Functions

1. **`backup_database()`**
   - Connects to SQL Server using sqlcmd
   - Uses COMPRESSION for 60-70% size reduction
   - Uses CHECKSUM for integrity verification
   - Generates filename: `xafdocker{YYYYMMDDHHMM}.bak`
   - Returns exit code: 0 = success, non-zero = failure

2. **`upload_to_ftp()`**
   - Uses lftp for robust transfer with resume capability
   - Supports FTP and FTPS based on `FTP_USE_TLS`
   - Verifies remote file size matches local file
   - Retry logic: 3 attempts with 30-second delays
   - Returns exit code: 0 = success, non-zero = failure

3. **`cleanup_old_backups()`**
   - Parses timestamp from filename pattern: `xafdocker{YYYYMMDDHHMM}.bak`
   - Calculates file age from embedded timestamp (not mtime)
   - Deletes files where age > `BACKUP_RETENTION_DAYS`
   - Cleanup logic:
     ```bash
     for file in xafdocker*.bak; do
       timestamp=$(echo $file | grep -oP '\d{12}')
       file_date=$(date -d "${timestamp:0:8} ${timestamp:8:2}:${timestamp:10:2}" +%s)
       age_days=$(( (current_time - file_date) / 86400 ))
       if [ $age_days -gt 7 ]; then
         rm $file
       fi
     done
     ```
   - Applies to both local volume and FTP server
   - Logs deleted files for audit trail

4. **`send_webhook()`**
   - Posts JSON notification via curl
   - Timeout: 10 seconds
   - Non-blocking (won't fail backup if webhook fails)
   - Payload format:
     ```json
     {
       "timestamp": "2026-03-25T23:30:15Z",
       "status": "failure",
       "service": "sql-backup",
       "database": "XAFDocker",
       "operation": "backup|ftp_upload|cleanup",
       "error": "Error message details",
       "details": {
         "backup_file": "xafdocker202603252330.bak",
         "file_size": "245MB",
         "duration": "45s",
         "ftp_host": "ftp.example.com"
       }
     }
     ```

### Entrypoint Script (`/app/entrypoint.sh`)

Responsibilities:
- Validate all required environment variables are set
- Generate crontab from `BACKUP_SCHEDULE` variable
- Test SQL Server connectivity before starting cron
- Start crond in foreground mode (keeps container running)
- Log startup information

### Dockerfile

```dockerfile
FROM mcr.microsoft.com/mssql-tools:latest

# Install required packages
RUN apt-get update && apt-get install -y \
    lftp \
    curl \
    cron \
    findutils \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy scripts
COPY backup.sh /app/backup.sh
COPY entrypoint.sh /app/entrypoint.sh

# Make scripts executable
RUN chmod +x /app/backup.sh /app/entrypoint.sh

# Start cron daemon
CMD ["/app/entrypoint.sh"]
```

## Error Handling

### Disk Space Management

- Check available space in `/backups` before backup
- Require at least 2x previous backup size (or 1GB minimum)
- If insufficient space, skip backup and send webhook notification
- Log current disk usage for troubleshooting

### SQL Server Connectivity

- Entrypoint tests connection before starting cron
- Backup script retries connection 3 times with 10-second delays
- If SQL Server is down, log error and send webhook
- Container continues running for next scheduled attempt

### FTP Failures

- Use lftp's resume capability for interrupted transfers
- Verify file size on FTP matches local file exactly
- If mismatch detected, delete remote file and retry
- After 3 failed upload attempts, keep local backup and alert
- Local backup remains available for manual recovery

### Concurrent Backup Prevention

- Use lock file (`/tmp/backup.lock`) to prevent overlapping backups
- If previous backup still running, log warning and skip current run
- Lock file automatically cleaned up on script exit (trap)

### Notification Triggers

**Send webhook on:**
- Backup failure (SQL Server connection error, insufficient space, backup command fails)
- FTP upload failure (after 3 retry attempts)
- Cleanup failure (logged but non-critical)

**Retry before notification:**
- Backup failures: No retry (database issues need investigation)
- FTP upload failures: 3 retries with 30-second delays
- Only send webhook after all retries exhausted

## Security Considerations

- **Backup files contain sensitive data** - volume should be properly secured
- **FTP credentials in .env file** - already gitignored
- **Use FTP_USE_TLS=true** for encrypted transfers in production
- **SQL connection uses existing SA password** - no new credentials needed
- **Webhook URL may contain secrets** - keep .env file secure

## Monitoring and Operations

### Log Visibility

- **View logs:** `docker logs -f xafdocker-backup`
- **Log format:** Structured with timestamps, operation names, status codes
- **Success log entry:**
  ```
  2026-03-25 23:30:15 [INFO] Backup started: XAFDocker
  2026-03-25 23:31:45 [INFO] Backup completed: xafdocker202603252330.bak (245MB in 90s)
  2026-03-25 23:32:30 [INFO] FTP upload completed: ftp.example.com/backups/xafdocker/xafdocker202603252330.bak
  2026-03-25 23:32:35 [INFO] Cleanup: removed 1 local file, 1 FTP file
  ```

### Manual Operations

- **Trigger immediate backup:**
  ```bash
  docker exec xafdocker-backup /app/backup.sh
  ```

- **List local backups:**
  ```bash
  docker exec xafdocker-backup ls -lh /backups
  ```

- **Test FTP connection:**
  ```bash
  docker exec xafdocker-backup lftp -u $FTP_USER,$FTP_PASSWORD $FTP_HOST -e "ls $FTP_PATH; bye"
  ```

- **View cron schedule:**
  ```bash
  docker exec xafdocker-backup crontab -l
  ```

### Backup Restoration Procedure

1. **Copy backup file to SQL Server container:**
   ```bash
   docker cp backup.bak xafdocker-sqlserver:/tmp/
   ```

2. **Restore database via sqlcmd:**
   ```sql
   RESTORE DATABASE [XAFDocker]
   FROM DISK='/tmp/backup.bak'
   WITH REPLACE
   ```

3. **Verify application connectivity**
   - Start application container
   - Test login and data access

## Testing Strategy

### Unit Testing

- **Test backup script locally:**
  ```bash
  docker exec xafdocker-backup /app/backup.sh
  ```

- **Dry-run mode:**
  ```bash
  docker exec -e DRY_RUN=true xafdocker-backup /app/backup.sh
  ```

- **Test individual functions:**
  - SQL connectivity test
  - FTP connection test
  - Webhook delivery test

### Integration Testing

1. **Full backup cycle:**
   - Trigger manual backup
   - Verify local file created with correct filename format
   - Verify FTP upload successful
   - Verify webhook notification (if enabled)

2. **Cleanup testing:**
   - Create test files with old timestamps
   - Run cleanup function
   - Verify old files deleted (local and FTP)

3. **Failure scenarios:**
   - Stop SQL Server → verify error handling and webhook
   - Invalid FTP credentials → verify retry logic and webhook
   - Fill disk space → verify space check and webhook

4. **Schedule verification:**
   - Verify cron is running: `docker exec xafdocker-backup pgrep crond`
   - Check crontab: `docker exec xafdocker-backup crontab -l`
   - Wait for scheduled time and verify execution

## Future Enhancements

Not included in initial implementation:

- Backup verification via `RESTORE VERIFYONLY`
- Backup compression level tuning
- Multiple FTP server support (redundancy)
- Backup encryption at rest
- Backup file compression (.zip instead of .bak)
- Incremental or differential backups
- Backup metrics and dashboards
- Success notifications (currently only failures)

## File Structure

```
docker/
├── backup/
│   ├── Dockerfile
│   ├── backup.sh           # Main backup script
│   └── entrypoint.sh       # Container startup script
```

## Dependencies

- SQL Server container must be running
- Shared volume `backup-data` mounted to both containers
- Network connectivity to FTP server
- Webhook URL accessible from container (if notifications enabled)

## Rollout Plan

1. Create backup container files (Dockerfile, scripts)
2. Update docker-compose.yml with backup service
3. Add environment variables to .env file
4. Test manually before relying on schedule
5. Monitor logs for first scheduled backup
6. Verify FTP uploads working correctly
7. Test restoration procedure with backup file

## Success Criteria

- ✅ Daily backups running at 11:30 PM
- ✅ Backup files follow naming convention: `xafdocker{YYYYMMDDHHMM}.bak`
- ✅ Files successfully uploaded to FTP server
- ✅ Old backups cleaned up after 7 days (local and FTP)
- ✅ Webhook notifications sent on failures
- ✅ Container restarts automatically on failure
- ✅ Backup and restore tested successfully
