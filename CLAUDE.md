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

### Controllers

XAF Controllers extend functionality and can be added to:
- `XAFDocker.Module/Controllers/` - Platform-agnostic controllers
- `XAFDocker.Blazor.Server/Controllers/` - Blazor-specific controllers

Controllers inherit from `ViewController` or `ObjectViewController<T>` and use Actions to add UI interactions.

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

## Key XAF Concepts

1. **Object Space** - Unit of Work pattern for data access. Always use `IObjectSpace` for CRUD operations, never DbContext directly in XAF code.

2. **Module Dependencies** - Modules declare dependencies via `RequiredModuleTypes`. The order matters for initialization.

3. **Database Version Mismatch** - XAF tracks schema versions. The `DatabaseVersionMismatch` event in BlazorApplication.cs handles schema updates.

4. **Design-Time vs Runtime** - The `IDesignTimeApplicationFactory` in Program.cs enables XAF's design-time tools and Model Editor.

## Development Notes

- Business objects typically inherit from `BaseObject` or implement `IXafEntityObject`
- Use XAF attributes (e.g., `[DefaultClassOptions]`, `[RuleRequiredField]`) to control UI generation and validation
- The `.vs/` directory contains Visual Studio user settings and should remain in .gitignore
- For Blazor-specific services, see `XAFDocker.Blazor.Server/Services/` (e.g., CircuitHandlerProxy for SignalR circuit lifecycle management)
