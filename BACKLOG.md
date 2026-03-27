# ✅ Story 1 - handle License Key for DevExpress properly (done)

**Status:** Completed on 2026-03-23

**Reference:** https://docs.devexpress.com/GeneralInformation/405494/trial-register/set-up-your-dev-express-license-key

**Requirements:**
- ✅ Works on native Linux development environment
- ✅ Works in Docker builds
- ✅ Eliminates DX1000/DX1001 build warnings
- ✅ Compatible with Dokploy deployment

**Implementation:**
- Setup script: `scripts/setup-devexpress-license.sh`
- Design document: `docs/plans/2026-03-23-devexpress-license-configuration-design.md`
- User guide: `docs/DEVEXPRESS-LICENSE-SETUP.md`
- License key stored in `.env` file (git-ignored)
- Automatic configuration in Docker via build args

**Testing:**
- ✅ Native Linux build: No DX1000/DX1001 warnings
- ⏳ Docker build: Pending Docker daemon availability

**Usage:**
```bash
# Native Linux setup (one-time)
./scripts/setup-devexpress-license.sh

# Build without warnings
dotnet build XAFDocker.sln

# Docker build
docker compose -f docker-compose.prod.yml build
```

## Story 2 - Backup of SQL-Server ✅ COMPLETED

As data is very important, we need to back up the MSSQL Server database. MSSQL Server provides a function for creating database backups, which must be invoked once a day at 11.30pm. The backup file must then be placed on the mounted share.

### Implementation Details

**Completed:** 2026-03-25

**Architecture:**
- Dedicated backup container with cron scheduler
- Backup filename format: `xafdocker{YYYYMMDDHHMM}.bak`
- Daily backups at 11:30 PM (configurable)
- Immediate FTP transfer after backup
- 7-day retention based on filename timestamp
- Webhook notifications on failures

**Key Components:**
- [Backup Script](docker/backup/backup.sh) - Main backup logic
- [Entrypoint Script](docker/backup/entrypoint.sh) - Cron setup
- [Dockerfile](docker/backup/Dockerfile) - Container definition
- [Docker Compose](docker-compose.yml) - Service configuration

**Features:**
- ✅ Scheduled daily backups at 11:30 PM
- ✅ Backup format: `xafdocker{YYYYMMDDHHMM}.bak`
- ✅ FTP transfer with retry logic
- ✅ 7-day retention (local and FTP)
- ✅ Webhook notifications
- ✅ Disk space checking
- ✅ Concurrent backup prevention
- ✅ Comprehensive error handling

**Testing:**
- Manual backup trigger tested
- Filename format verified
- FTP upload functionality verified
- Cleanup logic tested
- Container health checks validated

## additional information:
Backup files must follow this format: `{prefix}{YYYYMMDDHHMM}.{extension}`

Examples:
- `xafdocker202603220045.zip`
- `SKGFormDEV202603150048.bak`

Trigger Backup in Docker:
docker exec xafdocker-backup /app/backup.sh


## Story 3 - Modify docker.compose.prod.yml ✅ COMPLETED

**Completed:** 2026-03-27

**Requirements:**
- ✅ Remove cron job from production backup container
- ✅ Keep backup.sh script unchanged for Dokploy scheduled execution
- ✅ Set /backups folder permissions to 777 for SQL Server access

**Implementation:**
- Created [Dockerfile.prod](docker/backup/Dockerfile.prod) - Production Dockerfile without cron
- Created [entrypoint-prod.sh](docker/backup/entrypoint-prod.sh) - Sets permissions and keeps container running
- Updated [docker-compose.prod.yml](docker-compose.prod.yml) - Uses Dockerfile.prod and updated healthcheck
- Removed `BACKUP_SCHEDULE` environment variable (not needed in production)
- Changed healthcheck from `pgrep crond` to `test -x /app/backup.sh`

**Dokploy Configuration:**
```
Scheduled Task:
- Name: SQL Server Backup
- Schedule: 0 * * * * (every hour)
- Command: docker exec xafdocker-backup /app/backup.sh
```

**Key Changes:**
- Production container runs indefinitely with `tail -f /dev/null`
- Permissions set automatically on container startup
- Scheduling handled externally by Dokploy
- Development environment still uses cron (docker-compose.yml unchanged)


## Story 4 - Free up space before backup ✅ COMPLETED

**Completed:** 2026-03-27

**Requirements:**
- ✅ Check if available space is less than the size of the last backup file
- ✅ Delete the 3 oldest backup files if space is insufficient
- ✅ Perform space check before invoking backup operation

**Implementation:**
- Added `get_last_backup_size()` - Gets size of most recent backup (defaults to 100MB if no previous backup)
- Added `delete_oldest_backups(count)` - Deletes specified number of oldest backup files
- Added `ensure_sufficient_space(dir)` - Main logic that checks space and triggers cleanup if needed
- Integrated space check into `backup_database()` function before backup creation
- Removed old hardcoded 1GB minimum check, now uses actual last backup size

**Logic Flow:**
1. Before backup, get available space and last backup file size
2. If available space < last backup size:
   - Log warning about insufficient space
   - Delete 3 oldest backup files
   - Re-check available space
   - Ensure at least 100MB still available
3. If still insufficient after cleanup, fail with error
4. Otherwise, proceed with backup

**Benefits:**
- Prevents backup failures due to insufficient space
- Automatically manages disk space by removing old backups
- Uses actual backup size rather than arbitrary minimum
- Maintains at least 3 backups before cleanup (if 3+ exist)