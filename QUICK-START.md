# XAFDocker Quick Start Guide

Get up and running with XAFDocker in 5 minutes!

## Prerequisites

- Docker Desktop installed and running
- DevExpress NuGet feed configured (already done in `nuget.config`)

## Quick Start

### 1. Start the Application

```bash
# Start all containers
docker compose up -d

# Watch application startup
docker compose logs -f xafapp
```

Wait for: `Database update completed successfully`

### 2. Access the Application

Open your browser: **http://localhost:5080**

### 3. Test the Contact Module

1. Navigate to **Contact** in the left menu
2. Click **New** to create a contact
3. Fill in:
   - First Name: John
   - Last Name: Doe
   - Email: john.doe@example.com (required)
   - Company: Example Corp
4. Click **Save**

## Connection Details

### Application
- **URL**: http://localhost:5080
- **Environment**: Development (Debug mode)

### SQL Server
- **Server**: localhost,1433
- **Database**: XAFDocker
- **User**: sa
- **Password**: YourStrong!Passw0rd (from `.env`)

### DataGrip/SSMS Connection
```
Server: localhost,1433
Authentication: SQL Server Authentication
User: sa
Password: YourStrong!Passw0rd
Database: XAFDocker
```

## Common Commands

```bash
# View logs
docker compose logs -f xafapp

# Restart after code changes
docker compose build xafapp && docker compose up -d xafapp

# Stop all containers
docker compose down

# Complete reset (deletes database!)
docker compose down -v && docker compose up -d

# Check container status
docker compose ps

# Access SQL Server
docker exec -it xafdocker-sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "YourStrong!Passw0rd" -C
```

## Project Structure

```
XAFDocker/
├── XAFDocker.Module/              # Business logic and models
│   └── BusinessObjects/
│       ├── Contact.cs             # Sample business object
│       └── XAFDockerDbContext.cs  # EF Core DbContext
│
├── XAFDocker.Blazor.Server/       # Blazor UI
│   ├── BlazorApplication.cs       # XAF application
│   ├── Program.cs                 # Entry point
│   └── Startup.cs                 # Configuration
│
└── docker/                        # Docker configuration
    ├── app/entrypoint.sh          # Startup script
    └── nginx/                     # Reverse proxy
```

## Adding a New Business Object

1. Create class in `XAFDocker.Module/BusinessObjects/`:
```csharp
using DevExpress.Persistent.Base;
using DevExpress.Persistent.BaseImpl.EF;

[DefaultClassOptions]
public class Product : BaseObject
{
    public virtual string Name { get; set; }
    public virtual decimal Price { get; set; }
}
```

2. Register in `XAFDockerDbContext.cs`:
```csharp
public DbSet<Product> Products { get; set; }
```

3. Rebuild and restart:
```bash
docker compose build xafapp && docker compose up -d xafapp
```

## Troubleshooting

### Application won't start
```bash
docker logs xafdocker-app --tail 100
```

### Database connection error
```bash
# Check SQL Server
docker compose ps sqlserver

# Verify connection
docker exec xafdocker-sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "YourStrong!Passw0rd" -Q "SELECT 1" -C
```

### Port 5080 already in use
```bash
# Change port in docker-compose.yml
ports:
  - "5081:80"
```

## Next Steps

- Read [README.md](README.md) for detailed documentation
- Check [OPERATIONS.md](OPERATIONS.md) for container management
- Review [CONSISTENCY-REPORT.md](CONSISTENCY-REPORT.md) for current status
- Explore the XAF application at http://localhost:5080

## Need Help?

- XAF Documentation: https://docs.devexpress.com/eXpressAppFramework/
- Docker Logs: `docker compose logs -f`
- Container Status: `docker compose ps`

---

**Ready to develop!** The application is running and accessible at http://localhost:5080
