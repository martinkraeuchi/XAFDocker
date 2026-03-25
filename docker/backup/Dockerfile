FROM mcr.microsoft.com/mssql-tools:latest

# Install required packages
RUN apt-get update && apt-get install -y \
    lftp \
    curl \
    cron \
    findutils \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy scripts
COPY backup.sh /app/backup.sh
COPY entrypoint.sh /app/entrypoint.sh

# Make scripts executable
RUN chmod +x /app/backup.sh /app/entrypoint.sh

# Create backup directory
RUN mkdir -p /backups

# Health check: verify cron is running
HEALTHCHECK --interval=60s --timeout=3s --retries=3 \
    CMD pgrep crond || exit 1

# Start cron daemon
CMD ["/app/entrypoint.sh"]
