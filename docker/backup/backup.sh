#!/bin/bash
# SQL Server Backup Script
# Performs daily backups with FTP transfer and cleanup

set -euo pipefail

# Configuration from environment variables
SQL_SERVER="${SQL_SERVER:-sqlserver}"
SQL_PORT="${SQL_PORT:-1433}"
SQL_USER="${SQL_USER:-sa}"
SQL_PASSWORD="${SQL_SA_PASSWORD}"
BACKUP_DIR="${BACKUP_DIR:-/backups}"
BACKUP_DATABASE="${BACKUP_DATABASE:-XAFDocker}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
FTP_HOST="${FTP_HOST}"
FTP_PORT="${FTP_PORT:-21}"
FTP_USER="${FTP_USER}"
FTP_PASSWORD="${FTP_PASSWORD}"
FTP_PATH="${FTP_PATH}"
FTP_USE_TLS="${FTP_USE_TLS:-true}"
WEBHOOK_URL="${WEBHOOK_URL:-}"
WEBHOOK_ENABLED="${WEBHOOK_ENABLED:-false}"
DRY_RUN="${DRY_RUN:-false}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2"
}

# Send webhook notification (placeholder - full implementation in Task 5)
send_webhook() {
    # Placeholder: webhook functionality will be implemented in Task 5
    # Parameters: status, operation, error, backup_file
    if [ "$WEBHOOK_ENABLED" = "true" ]; then
        log "WARN" "Webhook not yet implemented: $1 $2 $3"
    fi
}

# Generate backup filename with timestamp
generate_backup_filename() {
    local timestamp=$(date '+%Y%m%d%H%M')
    echo "xafdocker${timestamp}.bak"
}

# Perform SQL Server database backup
backup_database() {
    local backup_file="$BACKUP_DIR/$(generate_backup_filename)"

    log "INFO" "Backup started: $BACKUP_DATABASE"
    log "INFO" "Backup file: $backup_file"

    # Check disk space
    local available_kb=$(df -k "$BACKUP_DIR" | tail -1 | awk '{print $4}')
    local available_mb=$((available_kb / 1024))
    log "INFO" "Available disk space: ${available_mb}MB"

    if [ "$available_mb" -lt 1024 ]; then
        log "ERROR" "Insufficient disk space: ${available_mb}MB available, 1GB minimum required"
        return 1
    fi

    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"

    # Execute backup with retry logic
    local retry=0
    local max_retries=3
    local start_time=$(date +%s)

    while [ $retry -lt $max_retries ]; do
        if [ $retry -gt 0 ]; then
            log "WARN" "Retry attempt $retry of $max_retries"
            sleep 10
        fi

        # Use environment variable for password (more secure than -P flag)
        export SQLCMDPASSWORD="$SQL_PASSWORD"

        # Execute T-SQL backup command
        if /opt/mssql-tools18/bin/sqlcmd -S "$SQL_SERVER,$SQL_PORT" -U "$SQL_USER" -C -b -Q \
            "BACKUP DATABASE [$BACKUP_DATABASE] TO DISK = N'$backup_file' WITH FORMAT, COMPRESSION, CHECKSUM;" > /tmp/backup.log 2>&1; then

            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            local file_size=$(du -h "$backup_file" | cut -f1)

            log "INFO" "Backup completed: $file_size in ${duration}s"
            echo "$backup_file"
            return 0
        else
            log "ERROR" "Backup attempt $((retry + 1)) failed:"
            cat /tmp/backup.log | while read line; do log "ERROR" "$line"; done
            retry=$((retry + 1))
        fi
    done

    log "ERROR" "Backup failed after $max_retries attempts"
    return 1
}

# Main execution
main() {
    log "INFO" "Backup process started"

    # Perform database backup
    local backup_file
    if ! backup_file=$(backup_database); then
        send_webhook "failure" "backup" "Database backup failed" ""
        return 1
    fi

    log "INFO" "Backup file created: $backup_file"

    log "INFO" "Backup process completed"
}

# Execute main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
