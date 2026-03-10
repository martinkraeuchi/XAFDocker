# XAFDocker - DevExpress XAF Blazor Server Application

A fully containerized DevExpress XAF (eXpressApp Framework) application built with .NET 8.0 and ASP.NET Core Blazor Server, configured for Docker deployment with SQL Server.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Solution Structure](#solution-structure)
- [Configuration](#configuration)
- [Database](#database)
- [Business Objects](#business-objects)
- [Docker Setup](#docker-setup)
- [Development](#development)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)

## Overview

This project demonstrates a production-ready containerized XAF application with:
- **DevExpress XAF 25.2** - Business application framework
- **.NET 8.0** - Latest LTS version
- **Blazor Server** - Interactive web UI
- **Entity Framework Core** - ORM with SQL Server
- **Docker** - Full containerization with Docker Compose
- **Nginx** - Reverse proxy with SSL support
- **Let's Encrypt** - Automated SSL certificate management

## Architecture

### Solution Components

```
XAFDocker/
├── XAFDocker.Module/              # Platform-agnostic business logic
│   ├── BusinessObjects/           # Domain models and DbContext
│   │   ├── Contact.cs            # Sample Contact entity
│   │   └── XAFDockerDbContext.cs # EF Core DbContext
│   ├── Controllers/               # XAF controllers
│   ├── DatabaseUpdate/            # Database seeders and updaters
│   └── Module.cs                  # Module configuration
│
├── XAFDocker.Blazor.Server/       # Blazor Server UI implementation
│   ├── Controllers/               # Blazor-specific controllers
│   ├── Pages/                     # Blazor pages and components
│   ├── Services/                  # Application services
│   ├── BlazorApplication.cs       # XAF Blazor application class
│   ├── BlazorModule.cs            # Blazor module configuration
│   ├── Program.cs                 # Application entry point
│   └── Startup.cs                 # Service configuration
│
└── docker/                        # Docker configuration
    ├── app/                       # Application container scripts
    ├── nginx/                     # Nginx configuration
    ├── sqlserver/                 # SQL Server initialization
    └── certbot/                   # SSL certificate management
```

### Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Framework | DevExpress XAF | 25.2.* |
| Runtime | .NET | 8.0 |
| UI | Blazor Server | ASP.NET Core 8.0 |
| Database | SQL Server Express | 2022 |
| ORM | Entity Framework Core | 8.0 |
| Web Server | Nginx | Alpine |
| SSL | Let's Encrypt (Certbot) | Latest |
| Container | Docker | Latest |
| Orchestration | Docker Compose | Latest |

## Prerequisites

### Development

- [.NET 8.0 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Visual Studio 2022](https://visualstudio.microsoft.com/) or [VS Code](https://code.visualstudio.com/)
- DevExpress Universal Subscription (with valid license)

### DevExpress License

You need a valid DevExpress license to run this application. Configure your NuGet feed:

1. Get your feed URL from [nuget.devexpress.com](https://nuget.devexpress.com/)
2. The feed URL is already configured in `nuget.config`

## Quick Start

### 1. Clone and Configure

```bash
# Clone the repository
cd XAFDocker

# Copy environment template
cp .env.template .env

# Edit .env with your settings
# IMPORTANT: Change SQL_SA_PASSWORD in production!
```

### 2. Start with Docker

```bash
# Build and start all containers
docker compose build
docker compose up -d

# View logs
docker compose logs -f xafapp
```

### 3. Access the Application

- **Application**: http://localhost:5080
- **SQL Server**: localhost:1433
  - User: `sa`
  - Password: (from `.env` file)
  - Database: `XAFDocker`

## Solution Structure

### XAFDocker.Module

Platform-agnostic module containing:
- **Business Objects**: Domain models (Contact, etc.)
- **Controllers**: XAF controllers for business logic
- **Database Context**: EF Core DbContext configuration
- **Module Configuration**: Module dependencies and settings

### XAFDocker.Blazor.Server

Blazor Server implementation:
- **Blazor Components**: UI components and pages
- **Application Class**: XAF application setup
- **Startup Configuration**: Service registration and middleware
- **Security**: Authentication and authorization setup

## Configuration

### Environment Variables

Configure via `.env` file:

```bash
# SQL Server Configuration
SQL_SA_PASSWORD=YourStrong!Passw0rd

# XAF Security
URL_SIGNING_KEY=FAB39807-4423-424D-BC2F-572B65AE19F3

# Domain (for SSL)
DOMAIN_NAME=yourdomain.com
EMAIL_ADDRESS=admin@yourdomain.com
```

### Connection Strings

#### Development (Local Docker SQL Server)
**File**: `appsettings.Development.json`
```json
"ConnectionString": "Server=localhost,1433;Database=XAFDocker;User Id=sa;Password=YourStrong!Passw0rd;TrustServerCertificate=True;MultipleActiveResultSets=True"
```

#### Production (Docker Internal Network)
**File**: `docker-compose.yml`
```yaml
ConnectionStrings__ConnectionString: "Server=sqlserver,1433;Database=XAFDocker;User Id=sa;Password=${SQL_SA_PASSWORD};TrustServerCertificate=True;MultipleActiveResultSets=True"
```

### Application Settings

**Default Environment**: Development (Debug mode)
- Set in `docker-compose.yml`: `ASPNETCORE_ENVIRONMENT=Development`
- Enables detailed error messages
- Auto-updates database schema
- Diagnostic actions enabled

## Database

### Entity Framework Core

The application uses EF Core with SQL Server:

**DbContext**: `XAFDockerEFCoreDbContext`
- Location: `XAFDocker.Module/BusinessObjects/XAFDockerDbContext.cs`
- Features:
  - Deferred deletion
  - Optimistic locking
  - Change tracking with original values
  - SQL Server-specific optimizations

### Database Updates

Database schema updates are handled automatically:

#### Via Docker Entrypoint
The `entrypoint.sh` script runs database updates on container start:
```bash
dotnet XAFDocker.Blazor.Server.dll --updateDatabase --silent
```

#### Manual Update
```bash
# Using Docker
docker exec xafdocker-app dotnet XAFDocker.Blazor.Server.dll --updateDatabase

# Local development
dotnet run --project XAFDocker.Blazor.Server --updateDatabase
```

#### Using EF Migrations
```bash
# Add migration
dotnet ef migrations add MigrationName \
  --project XAFDocker.Module \
  --startup-project XAFDocker.Blazor.Server

# Apply migration
dotnet ef database update \
  --project XAFDocker.Module \
  --startup-project XAFDocker.Blazor.Server
```

### Database Access

Connect to the SQL Server container:

#### Using DataGrip / SQL Server Management Studio
- **Host**: `localhost`
- **Port**: `1433`
- **User**: `sa`
- **Password**: (from `.env`)
- **Database**: `XAFDocker`

#### Using Docker
```bash
docker exec -it xafdocker-sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "YourStrong!Passw0rd" -C
```

## Business Objects

### Contact Entity

**File**: `XAFDocker.Module/BusinessObjects/Contact.cs`

A sample business object demonstrating XAF capabilities:

```csharp
[DefaultClassOptions]
[DefaultProperty(nameof(FullName))]
public class Contact : BaseObject
{
    public virtual string FirstName { get; set; }
    public virtual string LastName { get; set; }

    [RuleRequiredField(DefaultContexts.Save)]
    public virtual string Email { get; set; }

    public virtual string Phone { get; set; }
    public virtual string Company { get; set; }

    [FieldSize(FieldSizeAttribute.Unlimited)]
    public virtual string Notes { get; set; }

    [VisibleInListView(false)]
    public string FullName => $"{FirstName} {LastName}".Trim();
}
```

**Features**:
- Auto-generated UI (list and detail views)
- Required field validation (Email)
- Unlimited text field (Notes)
- Calculated property (FullName)
- Full CRUD operations
- Search, filter, and sort capabilities

### Adding New Business Objects

1. Create new class in `XAFDocker.Module/BusinessObjects/`
2. Inherit from `BaseObject`
3. Add `[DefaultClassOptions]` attribute
4. Register in `XAFDockerEFCoreDbContext`:
   ```csharp
   public DbSet<YourEntity> YourEntities { get; set; }
   ```
5. Rebuild and restart application

## Docker Setup

### Container Architecture

```
┌─────────────────┐
│     nginx       │ Reverse Proxy + SSL
│   Port: 8080    │
│   Port: 8443    │
└────────┬────────┘
         │
┌────────▼────────┐
│   xafapp        │ XAF Blazor Application
│   Port: 5080    │ (Direct access for dev)
└────────┬────────┘
         │
┌────────▼────────┐
│  sqlserver      │ SQL Server 2022 Express
│   Port: 1433    │ (Exposed for dev)
└─────────────────┘
```

### Services

#### xafapp (XAF Application)
- **Image**: Custom built from `Dockerfile`
- **Port**: 5080 (direct access)
- **Environment**: Development
- **Dependencies**: SQL Server (healthy)
- **Health Check**: HTTP GET `/health`

#### sqlserver (SQL Server)
- **Image**: `mcr.microsoft.com/mssql/server:2022-latest`
- **Port**: 1433 (exposed for development)
- **Volume**: `sqlserver-data` (persistent storage)
- **Health Check**: `sqlcmd` query

#### nginx (Reverse Proxy)
- **Image**: `nginx:alpine`
- **Ports**: 8080 (HTTP), 8443 (HTTPS)
- **Volumes**: Configuration, SSL certificates
- **Status**: Currently requires SSL setup

#### certbot (SSL Certificates)
- **Image**: `certbot/certbot:latest`
- **Purpose**: Let's Encrypt certificate renewal
- **Schedule**: Every 12 hours

### Docker Commands

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f [service]

# Restart a service
docker compose restart xafapp

# Rebuild after code changes
docker compose build xafapp
docker compose up -d xafapp

# Stop all services
docker compose down

# Remove volumes (WARNING: deletes data)
docker compose down -v

# Check service status
docker compose ps

# Execute command in container
docker exec -it xafdocker-app bash
```

## Development

### Local Development (Without Docker)

1. **Start SQL Server** (Docker or local):
   ```bash
   docker compose up -d sqlserver
   ```

2. **Update connection string** in `appsettings.Development.json`

3. **Run the application**:
   ```bash
   dotnet run --project XAFDocker.Blazor.Server
   ```

4. **Access**: https://localhost:5001 or http://localhost:5000

### Building

```bash
# Restore dependencies
dotnet restore XAFDocker.sln

# Build solution
dotnet build XAFDocker.sln

# Build specific configuration
dotnet build XAFDocker.sln -c Release

# Publish for deployment
dotnet publish XAFDocker.Blazor.Server -c Release -o ./publish
```

### Hot Reload

The application supports hot reload in Development mode:
```bash
dotnet watch --project XAFDocker.Blazor.Server
```

## Deployment

This project includes comprehensive deployment documentation for production environments.

### 🚀 Quick Deploy to Dokploy (Recommended)

**Dokploy** is a production-tested Platform as a Service (PaaS) that simplifies deployment.

**Quick Start**: See [PRODUCTION_SETUP.md](./PRODUCTION_SETUP.md) for 20-minute deployment guide.

**Features:**
- ✅ One-click deployment from GitHub
- ✅ Automatic SSL certificates
- ✅ Built-in monitoring and health checks
- ✅ Volume backups
- ✅ Webhook support for continuous deployment

**Estimated Setup Time:** 20-30 minutes

### 📚 Deployment Documentation

| Guide | Purpose | Audience |
|-------|---------|----------|
| **[PRODUCTION_SETUP.md](./PRODUCTION_SETUP.md)** | Quick start production deployment | DevOps, Quick deployment |
| **[DEPLOYMENT_DOKPLOY.md](./DEPLOYMENT_DOKPLOY.md)** | Comprehensive Dokploy guide | Complete reference, troubleshooting |
| **docker-compose.prod.yml** | Production configuration overrides | Advanced customization |

### 🎯 Deployment Highlights

**Docker Compose Compatibility:**
- ✅ Version 3.3 (compatible with Dokploy and most platforms)
- ✅ Environment variables via `.env` file
- ✅ Healthchecks for all services
- ✅ Production-tested configuration

**What's Included:**
- XAF Blazor Server application
- SQL Server Express 2022
- Nginx reverse proxy with SSL
- Let's Encrypt certificate management
- Automated database migrations
- Volume persistence for data

### Manual Production Deployment

If not using Dokploy, follow these steps:

1. **Update environment variables** in `.env`:
   ```bash
   SQL_SA_PASSWORD=<strong-unique-password>
   URL_SIGNING_KEY=<new-guid>
   DOMAIN_NAME=your-domain.com
   EMAIL_ADDRESS=admin@your-domain.com
   ```

2. **Use production compose file**:
   ```bash
   docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
   ```

3. **Configure domain and SSL** (if using custom domain):
   - Point domain A record to your server
   - Let's Encrypt will auto-generate certificates

4. **Verify deployment**:
   ```bash
   docker compose ps  # All services should be "healthy"
   ```

### Security Considerations

- ✅ Change default SQL Server password
- ✅ Generate new URL signing key (GUID)
- ✅ Use proper SSL certificates (Let's Encrypt)
- ✅ Don't expose SQL Server port in production
- ✅ Set `ASPNETCORE_ENVIRONMENT=Production`
- ✅ Enable firewall rules
- ✅ Configure regular backups

**See [DEPLOYMENT_DOKPLOY.md](./DEPLOYMENT_DOKPLOY.md) for detailed security hardening steps.**

## Troubleshooting

### Common Issues

#### Application won't start
```bash
# Check container logs
docker logs xafdocker-app --tail 100

# Check if SQL Server is ready
docker compose ps sqlserver
```

#### Database connection failed
```bash
# Verify SQL Server is running
docker exec xafdocker-sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "YourStrong!Passw0rd" -Q "SELECT 1" -C

# Check connection string in logs
docker logs xafdocker-app | grep "ConnectionString"
```

#### Port already in use
```bash
# Find process using port
lsof -i :5080  # or :1433

# Change port in docker-compose.yml
ports:
  - "5081:80"  # Instead of 5080
```

#### SkiaSharp missing dependencies
This is already fixed in the Dockerfile with:
```dockerfile
RUN apt-get update && apt-get install -y \
    libfontconfig1 libfreetype6 libx11-6 libxcb1 \
    libxrender1 libice6 libsm6
```

#### Nginx keeps restarting
Nginx requires SSL certificates. For development:
- Access app directly at http://localhost:5080
- For production: Run `./init-letsencrypt.sh`

### Logs

```bash
# Application logs
docker logs xafdocker-app -f

# SQL Server logs
docker logs xafdocker-sqlserver -f

# All services
docker compose logs -f

# Specific time range
docker logs xafdocker-app --since 10m
```

### Database Issues

#### Reset database
```bash
# Stop containers
docker compose down

# Remove SQL Server volume
docker volume rm xafdocker_sqlserver-data

# Restart (creates new database)
docker compose up -d
```

#### Backup database
```bash
docker exec xafdocker-sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "YourStrong!Passw0rd" -C \
  -Q "BACKUP DATABASE XAFDocker TO DISK='/var/opt/mssql/backup/XAFDocker.bak'"

# Copy backup out of container
docker cp xafdocker-sqlserver:/var/opt/mssql/backup/XAFDocker.bak ./
```

## Project Information

- **Framework**: DevExpress XAF (eXpressApp Framework)
- **Version**: 25.2.*
- **Target**: .NET 8.0
- **License**: DevExpress Universal Subscription required

## Additional Resources

- [DevExpress XAF Documentation](https://docs.devexpress.com/eXpressAppFramework/113577/expressapp-framework)
- [XAF Blazor](https://docs.devexpress.com/eXpressAppFramework/401456/expressapp-framework-for-blazor)
- [Docker Documentation](https://docs.docker.com/)
- [.NET 8.0 Documentation](https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-8)
- [Entity Framework Core](https://learn.microsoft.com/en-us/ef/core/)

## License

This project uses DevExpress XAF which requires a commercial license.
See [DevExpress Licensing](https://www.devexpress.com/support/license-faq/) for details.

---

**Last Updated**: January 2026
**Maintained by**: XAFDocker Project Team
