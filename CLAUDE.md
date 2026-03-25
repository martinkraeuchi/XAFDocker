# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **DevExpress XAF (eXpressApp Framework)** application built with **.NET 8.0** and **ASP.NET Core Blazor Server**. XAF is a framework for building business applications with automatic UI generation based on business objects and an Application Model.

## Solution Structure

The solution contains two projects following XAF's modular architecture:

- **XAFDocker.Module** - Platform-agnostic module containing business logic, business objects, controllers, and database context. This is where domain models and shared logic live.
- **XAFDocker.Blazor.Server** - Blazor Server UI implementation with XAF-specific application setup, services, and presentation layer.

## Common Commands

### Build and Run
```bash
# Build the solution
dotnet build XAFDocker.sln

# Run the Blazor Server application
dotnet run --project XAFDocker.Blazor.Server/XAFDocker.Blazor.Server.csproj

# Build in Release mode
dotnet build XAFDocker.sln -c Release
```

The application runs on:
- HTTPS: https://localhost:5001
- HTTP: http://localhost:5000

### Database Management

XAF provides built-in database update mechanisms:

```bash
# Update database schema to match the application model
dotnet run --project XAFDocker.Blazor.Server --updateDatabase

# Force update (even if versions match)
dotnet run --project XAFDocker.Blazor.Server --updateDatabase --forceUpdate

# Silent update (no user interaction)
dotnet run --project XAFDocker.Blazor.Server --updateDatabase --silent
```

**Note**: In DEBUG mode with debugger attached, the database updates automatically on startup.

### Entity Framework Migrations

```bash
# Add a new migration (run from Module project directory)
dotnet ef migrations add MigrationName --project XAFDocker.Module --startup-project XAFDocker.Blazor.Server

# Update database using EF tools
dotnet ef database update --project XAFDocker.Module --startup-project XAFDocker.Blazor.Server
```

## Architecture

### XAF Module System

XAF uses a **module-based architecture**:

1. **XAFDockerModule** ([Module.cs](XAFDocker.Module/Module.cs)) - Base module with dependencies on:
   - SystemModule
   - ConditionalAppearanceModule
   - ValidationModule

2. **XAFDockerBlazorModule** ([BlazorModule.cs](XAFDocker.Blazor.Server/BlazorModule.cs)) - Blazor-specific module for UI customizations

Modules are registered in [Startup.cs:31-41](XAFDocker.Blazor.Server/Startup.cs#L31-L41) via `builder.Modules`.

### Application Setup

The XAF application is initialized in two key files:

- **[Program.cs](XAFDocker.Blazor.Server/Program.cs)** - Entry point with database update command-line handling and host configuration
- **[Startup.cs](XAFDocker.Blazor.Server/Startup.cs)** - Service registration and middleware pipeline configuration
- **[BlazorApplication.cs](XAFDocker.Blazor.Server/BlazorApplication.cs)** - XAF application class with database version mismatch handling

### Data Layer

- **DbContext**: [XAFDockerEFCoreDbContext](XAFDocker.Module/BusinessObjects/XAFDockerDbContext.cs) uses EF Core with:
  - Deferred deletion support
  - Optimistic locking
  - Change tracking with original values
  - SQL Server LocalDB (configurable in appsettings.json)

- **Database Updates**: [Updater.cs](XAFDocker.Module/DatabaseUpdate/Updater.cs) - ModuleUpdater for seeding data and schema migrations

- **Connection String**: Configured in [appsettings.json:3](XAFDocker.Blazor.Server/appsettings.json#L3)

### Business Objects

Business objects should be added to `XAFDocker.Module/BusinessObjects/` and registered as DbSet properties in XAFDockerEFCoreDbContext if persistence is needed.

XAF automatically generates UI based on business object structure using attributes and the Application Model.

**Current Business Objects:**
- **[Contact](XAFDocker.Module/BusinessObjects/Contact.cs)** - Contact management with validation rules
- **[FieldInstruction](XAFDocker.Module/BusinessObjects/FieldInstruction.cs)** - Stores contextual help instructions for DetailView fields. Administrators can manage instructions at runtime without code deployment.

### Controllers

XAF Controllers extend functionality and can be added to:
- `XAFDocker.Module/Controllers/` - Platform-agnostic controllers
- `XAFDocker.Blazor.Server/Controllers/` - Blazor-specific controllers

Controllers inherit from `ViewController` or `ObjectViewController<T>` and use Actions to add UI interactions.

**Implemented Controllers:**
- **[FieldInstructionViewController](XAFDocker.Module/Controllers/FieldInstructionViewController.cs)** - Displays contextual help instructions when users focus on editor controls in DetailViews. Instructions are stored in the database via the FieldInstruction business object.

### Application Model

XAF stores UI customizations in XAFML files:
- **Model.xafml** - Application-level settings in Blazor.Server
- **Model.DesignedDiffs.xafml** - Module-level settings

These can be edited in code or via the Model Editor (Design-Time tools).

## Configuration

### appsettings.json

Key configuration sections:
- **ConnectionStrings** - Database connections (main and EasyTest)
- **DevExpress.ExpressApp.Security.UrlSigningKey** - Security token signing (change in production!)
- **DevExpress.ExpressApp.Languages** - Localization settings
- **DevExpress.ExpressApp.ThemeSwitcher** - UI theme configuration

### DevExpress Version

The project uses **DevExpress 25.2.*** packages. When updating DevExpress versions, update all package references in both .csproj files simultaneously.

### DevExpress License Configuration

The project requires a DevExpress license key to eliminate build warnings (DX1000/DX1001). The license configuration works for both native Linux development and Docker deployments.

**Setup for Local Development:**
1. Add your license key to `.env` file:
   ```
   DevExpress_License="your-license-key-here"
   ```
2. Run the setup script:
   ```bash
   ./scripts/setup-devexpress-license.sh
   ```
3. Build the project (no warnings):
   ```bash
   dotnet build XAFDocker.sln
   ```

**Docker/Dokploy Deployment:**
- The license key is automatically passed as a build argument from the `.env` file
- For Dokploy: Add `DevExpress_License` to environment variables in the Dokploy UI
- The Dockerfile creates the license file during the build stage

**How to obtain your license key:**
1. Visit [devexpress.com](https://devexpress.com)
2. Login to your account (or register for a trial)
3. Navigate to "My Account" → "License Keys"
4. Copy your license key

For detailed setup instructions, see [docs/DEVEXPRESS-LICENSE-SETUP.md](docs/DEVEXPRESS-LICENSE-SETUP.md).

## Key XAF Concepts

1. **Object Space** - Unit of Work pattern for data access. Always use `IObjectSpace` for CRUD operations, never DbContext directly in XAF code.

2. **Module Dependencies** - Modules declare dependencies via `RequiredModuleTypes`. The order matters for initialization.

3. **Database Version Mismatch** - XAF tracks schema versions. The `DatabaseVersionMismatch` event in BlazorApplication.cs handles schema updates.

4. **Design-Time vs Runtime** - The `IDesignTimeApplicationFactory` in Program.cs enables XAF's design-time tools and Model Editor.

## Features

### Field Instruction System

A contextual help system that displays instructions when users focus on editor controls in DetailViews.

**Architecture:**
- **[FieldInstruction](XAFDocker.Module/BusinessObjects/FieldInstruction.cs)** - Business object storing instructions per field
- **[FieldInstructionService](XAFDocker.Module/Services/FieldInstructionService.cs)** - In-memory caching service for O(1) instruction lookups
- **[FieldInstructionViewController](XAFDocker.Module/Controllers/FieldInstructionViewController.cs)** - Controller that intercepts focus events and displays instructions

**How it works:**
1. Instructions are stored in database with BusinessObjectType, PropertyName, InstructionText, and IsEnabled fields
2. When a DetailView opens, the controller loads all enabled instructions into cache
3. Focus events (mouse click or keyboard tab) on editor controls trigger instruction display
4. Instructions appear as toast notifications at the top of the screen for 3 seconds
5. Administrators can manage instructions through the XAF UI without code deployment

**Configuration:**
- Sample instructions for Contact fields are seeded in [Updater.cs](XAFDocker.Module/DatabaseUpdate/Updater.cs)
- Unique constraint ensures one instruction per field
- Instructions can be disabled without deletion via IsEnabled flag

## Development Notes

- Business objects typically inherit from `BaseObject` or implement `IXafEntityObject`
- Use XAF attributes (e.g., `[DefaultClassOptions]`, `[RuleRequiredField]`) to control UI generation and validation
- The `.vs/` directory contains Visual Studio user settings and should remain in .gitignore
- For Blazor-specific services, see `XAFDocker.Blazor.Server/Services/` (e.g., CircuitHandlerProxy for SignalR circuit lifecycle management)

### Backup System

An automated backup system for SQL Server database with FTP transfer.

**Architecture:**
- **[Backup Container](docker/backup/)** - Dedicated container with cron scheduler
- **[Backup Script](docker/backup/backup.sh)** - Main backup logic with FTP transfer
- **[Entrypoint Script](docker/backup/entrypoint.sh)** - Cron setup and validation

**How it works:**
1. Cron runs backup script daily at 11:30 PM (configurable via BACKUP_SCHEDULE)
2. Creates backup file: `xafdocker{YYYYMMDDHHMM}.bak` with COMPRESSION and CHECKSUM
3. Uploads to FTP server immediately after successful backup
4. Cleans up files older than 7 days (local and FTP) based on filename timestamp
5. Sends webhook notifications on failures

**Configuration:**
- Environment variables in `.env` file (see `.env.example`)
- Backup files stored in `backup-data` Docker volume
- Retention based on timestamp parsed from filename pattern

**Manual operations:**
```bash
# Trigger immediate backup
docker exec xafdocker-backup /app/backup.sh

# List backups
docker exec xafdocker-backup ls -lh /backups

# View logs
docker logs -f xafdocker-backup
```

**Restoration procedure:**
```bash
# Copy backup file to SQL Server container
docker cp backup.bak xafdocker-sqlserver:/tmp/

# Restore database
docker exec xafdocker-sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SQL_SA_PASSWORD" -C \
  -Q "RESTORE DATABASE [XAFDocker] FROM DISK='/tmp/backup.bak' WITH REPLACE"
```
