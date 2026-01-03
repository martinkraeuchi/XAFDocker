#!/bin/bash
set -e

echo "Starting XAF Blazor Server application..."

# Wait a bit for SQL Server to initialize
# Docker health check ensures SQL Server is ready before this container starts
echo "Waiting for SQL Server initialization..."
sleep 5

echo "Attempting to update database schema..."

# Try to update the database schema
# If it fails, the application will handle it on first request (in DEBUG mode)
if dotnet XAFDocker.Blazor.Server.dll --updateDatabase --silent; then
    echo "Database schema updated successfully"
else
    echo "Database update failed or not needed - application will handle schema updates on startup"
fi

# Start the application normally
echo "Starting the application..."
exec dotnet XAFDocker.Blazor.Server.dll
