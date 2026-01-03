# Plan / Backlog
## Goal
is to containerize the whole application:
- .net core app mit XAF Framework / Blazor
- SQL Server Express (Linux) Database in a separate Container
- ngnix Container mit SSL Certificate LetsEncrypt
- all other ports closed

## Requirements
Application
- based on .net core 8
- self contanined app container (linux based)

Database
- based on latest sql server express

Reverse Proxy
- providing SSL Access
- secure whole application and linux server

Docker
- based on docker-compose
- private net for the containers


## Backlog
### Task 1 - ✅ COMPLETED
Analyze the situation and make a proposal and a plan with the further tasks

### Task 2 - ✅ COMPLETED - Create Docker Infrastructure
- ✅ Create Dockerfile for the .NET application
- ✅ Create docker-compose.yml with all services
- ✅ Configure private Docker network
- ✅ Set up volume mounts for SQL Server data persistence

### Task 3 - ✅ COMPLETED - Configure SQL Server Container
- ✅ Set up SQL Server Express for Linux container
- ✅ Configure connection strings via environment variables
- ✅ Create initialization scripts for database setup
- ✅ Test XAF database update mechanism in container

### Task 4 - ✅ COMPLETED - Prepare Application for Containerization
- ✅ Update appsettings.json to support environment-based configuration
- ✅ Modify connection strings to work with containerized SQL Server
- ✅ Ensure proper handling of production vs development environments
- ✅ Configure Kestrel for container hosting

### Task 5 - ✅ COMPLETED - Configure nginx Reverse Proxy
- ✅ Create nginx configuration for reverse proxy
- ✅ Set up Let's Encrypt certificate automation (using certbot or similar)
- ✅ Configure SSL/TLS settings
- ✅ Set up HTTP → HTTPS redirection
- ✅ Configure proxy headers for Blazor SignalR WebSockets

### Task 6 - Security Hardening
- Close all unnecessary ports (only 80/443 exposed)
- Configure firewall rules
- Implement Docker secrets for sensitive data
- Review and update security-related appsettings

### Task 7 - Testing & Validation
- Test container startup and database initialization
- Verify XAF database migrations work correctly
- Test SSL certificate generation and renewal
- Verify Blazor SignalR connections through proxy
- Test application functionality in containerized environment

### Task 8 - ✅ COMPLETED - Documentation & Deployment
- ✅ Document deployment process
- ✅ Create environment variable template
- ✅ Document backup/restore procedures
- ✅ Create docker-compose commands cheat sheet