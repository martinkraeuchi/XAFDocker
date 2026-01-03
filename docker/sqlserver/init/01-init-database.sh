#!/bin/bash
# SQL Server initialization script
# This script creates the initial database if it doesn't exist

# Wait for SQL Server to start
echo "Waiting for SQL Server to start..."
sleep 30s

# Create database if it doesn't exist
/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -Q "
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'XAFDocker')
BEGIN
    CREATE DATABASE [XAFDocker];
    PRINT 'Database XAFDocker created successfully.';
END
ELSE
BEGIN
    PRINT 'Database XAFDocker already exists.';
END
"

echo "Database initialization complete."
