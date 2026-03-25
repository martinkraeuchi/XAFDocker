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

# Logging function - output to stderr so it doesn't interfere with function returns
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2" >&2
}

# Send webhook notification
send_webhook() {
    local status="$1"      # success or failure
    local operation="$2"   # backup, ftp_upload, cleanup
    local error="$3"       # error message
    local backup_file="$4" # backup filename

    # Skip if webhooks disabled
    if [ "$WEBHOOK_ENABLED" != "true" ] || [ -z "$WEBHOOK_URL" ]; then
        return 0
    fi

    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    local file_size=""
    local duration=""

    if [ -n "$backup_file" ] && [ -f "$backup_file" ]; then
        file_size=$(du -h "$backup_file" | cut -f1)
    fi

    # Build JSON payload
    local payload=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "status": "$status",
  "service": "sql-backup",
  "database": "$BACKUP_DATABASE",
  "operation": "$operation",
  "error": "$error",
  "details": {
    "backup_file": "$(basename "$backup_file")",
    "file_size": "$file_size",
    "ftp_host": "$FTP_HOST",
    "retention_days": "$BACKUP_RETENTION_DAYS"
  }
}
EOF
    )

    log "INFO" "Sending webhook notification: $status - $operation"

    # Send webhook with timeout
    if curl -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        --max-time 10 \
        --silent \
        --show-error \
        > /tmp/webhook.log 2>&1; then
        log "INFO" "Webhook notification sent successfully"
    else
        log "WARN" "Webhook notification failed (non-critical):"
        cat /tmp/webhook.log | while read line; do log "WARN" "$line"; done
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

        # Execute T-SQL backup command (without COMPRESSION for Express Edition compatibility)
        if /opt/mssql-tools18/bin/sqlcmd -S "$SQL_SERVER,$SQL_PORT" -U "$SQL_USER" -C -b -Q \
            "BACKUP DATABASE [$BACKUP_DATABASE] TO DISK = N'$backup_file' WITH FORMAT, CHECKSUM;" > /tmp/backup.log 2>&1; then

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

# Upload backup file to FTP server
upload_to_ftp() {
    local local_file="$1"
    local filename=$(basename "$local_file")
    local remote_file="$FTP_PATH/$filename"

    log "INFO" "FTP upload started: $filename"
    log "INFO" "Destination: $FTP_HOST:$FTP_PORT$remote_file"

    # Always use ftp:// protocol for explicit FTPS (port 21 with AUTH TLS)
    # Use ftps:// only for implicit FTPS (port 990)
    local ftp_protocol="ftp"

    # Upload with retry logic
    local retry=0
    local max_retries=3

    while [ $retry -lt $max_retries ]; do
        if [ $retry -gt 0 ]; then
            log "WARN" "FTP retry attempt $retry of $max_retries"
            sleep 30
        fi

        # Execute lftp upload with explicit FTPS support
        if lftp -c "
            set ftp:ssl-allow $([ \"$FTP_USE_TLS\" = \"true\" ] && echo \"yes\" || echo \"no\");
            set ftp:ssl-force $([ \"$FTP_USE_TLS\" = \"true\" ] && echo \"yes\" || echo \"no\");
            set ftp:ssl-protect-data $([ \"$FTP_USE_TLS\" = \"true\" ] && echo \"yes\" || echo \"no\");
            set ftp:ssl-protect-list $([ \"$FTP_USE_TLS\" = \"true\" ] && echo \"yes\" || echo \"no\");
            set ssl:verify-certificate no;
            open -u \"$FTP_USER\",\"$FTP_PASSWORD\" -p $FTP_PORT $ftp_protocol://$FTP_HOST;
            mkdir -p \"$FTP_PATH\" || echo \"Directory exists\";
            put -O \"$FTP_PATH\" \"$local_file\";
            bye
        " > /tmp/ftp.log 2>&1; then
            # Upload succeeded
            local local_size=$(stat -c%s "$local_file")
            log "INFO" "FTP upload completed: $filename (${local_size} bytes)"
            return 0
        else
            log "ERROR" "FTP upload attempt $((retry + 1)) failed:"
            cat /tmp/ftp.log | while read line; do log "ERROR" "$line"; done
            retry=$((retry + 1))
        fi
    done

    log "ERROR" "FTP upload failed after $max_retries attempts"
    return 1
}

# Parse timestamp from filename (xafdockerYYYYMMDDHHMM.bak)
parse_timestamp_from_filename() {
    local filename="$1"
    # Extract 12-digit timestamp: YYYYMMDDHHMM
    echo "$filename" | grep -oP '(?<=xafdocker)\d{12}(?=\.bak)'
}

# Convert timestamp to epoch seconds
timestamp_to_epoch() {
    local timestamp="$1"
    local year="${timestamp:0:4}"
    local month="${timestamp:4:2}"
    local day="${timestamp:6:2}"
    local hour="${timestamp:8:2}"
    local minute="${timestamp:10:2}"

    date -d "$year-$month-$day $hour:$minute:00" +%s 2>/dev/null || echo "0"
}

# Cleanup old backup files (local)
cleanup_local_backups() {
    log "INFO" "Cleanup started: local backups"

    local current_time=$(date +%s)
    local retention_seconds=$((BACKUP_RETENTION_DAYS * 86400))
    local deleted_count=0

    for file in "$BACKUP_DIR"/xafdocker*.bak; do
        [ -f "$file" ] || continue

        local filename=$(basename "$file")
        local timestamp=$(parse_timestamp_from_filename "$filename")

        if [ -z "$timestamp" ]; then
            log "WARN" "Could not parse timestamp from: $filename"
            continue
        fi

        local file_epoch=$(timestamp_to_epoch "$timestamp")
        if [ "$file_epoch" = "0" ]; then
            log "WARN" "Invalid timestamp in filename: $filename"
            continue
        fi

        local age_seconds=$((current_time - file_epoch))
        local age_days=$((age_seconds / 86400))

        if [ $age_seconds -gt $retention_seconds ]; then
            log "INFO" "Deleting local file (age: ${age_days} days): $filename"
            rm -f "$file"
            deleted_count=$((deleted_count + 1))
        fi
    done

    log "INFO" "Cleanup completed: $deleted_count local file(s) deleted"
}

# Cleanup old backup files (FTP)
cleanup_ftp_backups() {
    log "INFO" "Cleanup started: FTP backups"

    local ftp_protocol="ftp"
    if [ "$FTP_USE_TLS" = "true" ]; then
        ftp_protocol="ftps"
    fi

    local current_time=$(date +%s)
    local retention_seconds=$((BACKUP_RETENTION_DAYS * 86400))
    local deleted_count=0

    # List FTP files
    local ftp_files=$(lftp -c "
        set ftp:ssl-allow $([ \"$FTP_USE_TLS\" = \"true\" ] && echo \"yes\" || echo \"no\");
        set ssl:verify-certificate no;
        open -u $FTP_USER,$FTP_PASSWORD -p $FTP_PORT $ftp_protocol://$FTP_HOST;
        cls -1 $FTP_PATH/xafdocker*.bak;
        bye
    " 2>/dev/null || echo "")

    if [ -z "$ftp_files" ]; then
        log "INFO" "No FTP files found to cleanup"
        return 0
    fi

    # Process each file
    while read filename; do
        [ -z "$filename" ] && continue

        local timestamp=$(parse_timestamp_from_filename "$(basename "$filename")")

        if [ -z "$timestamp" ]; then
            log "WARN" "Could not parse timestamp from FTP file: $filename"
            continue
        fi

        local file_epoch=$(timestamp_to_epoch "$timestamp")
        if [ "$file_epoch" = "0" ]; then
            log "WARN" "Invalid timestamp in FTP filename: $filename"
            continue
        fi

        local age_seconds=$((current_time - file_epoch))
        local age_days=$((age_seconds / 86400))

        if [ $age_seconds -gt $retention_seconds ]; then
            log "INFO" "Deleting FTP file (age: ${age_days} days): $(basename "$filename")"

            lftp -c "
                set ftp:ssl-allow $([ \"$FTP_USE_TLS\" = \"true\" ] && echo \"yes\" || echo \"no\");
                set ssl:verify-certificate no;
                open -u $FTP_USER,$FTP_PASSWORD -p $FTP_PORT $ftp_protocol://$FTP_HOST;
                rm -f $filename;
                bye
            " > /dev/null 2>&1

            deleted_count=$((deleted_count + 1))
        fi
    done < <(echo "$ftp_files")

    log "INFO" "Cleanup completed: $deleted_count FTP file(s) deleted"
}

# Main execution
main() {
    # Prevent concurrent backups
    local lock_file="/tmp/backup.lock"

    if [ -f "$lock_file" ]; then
        log "WARN" "Previous backup still running (lock file exists), skipping"
        return 0
    fi

    # Create lock file
    touch "$lock_file"

    # Ensure lock file is removed on exit
    trap "rm -f $lock_file" EXIT INT TERM

    log "INFO" "Backup process started"

    # Perform database backup
    local backup_file
    if ! backup_file=$(backup_database); then
        send_webhook "failure" "backup" "Database backup failed" ""
        return 1
    fi

    log "INFO" "Backup file created: $backup_file"

    # Upload to FTP server
    if ! upload_to_ftp "$backup_file"; then
        send_webhook "failure" "ftp_upload" "FTP upload failed" "$backup_file"
        return 1
    fi

    # Cleanup old backups
    cleanup_local_backups || log "WARN" "Local cleanup had errors"
    cleanup_ftp_backups || log "WARN" "FTP cleanup had errors"

    log "INFO" "Backup process completed"
}

# Execute main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
