# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] - 2026-03-10

### Added - Production Deployment Documentation

#### New Documentation Files
- **DEPLOYMENT_DOKPLOY.md** - Comprehensive deployment guide for Dokploy platform
  - Step-by-step deployment instructions
  - Production optimizations section with real-world experience
  - Troubleshooting guide for common issues
  - Lessons learned from actual production deployment
  - Complete monitoring and maintenance procedures

- **PRODUCTION_SETUP.md** - Quick start guide for production deployment
  - 20-30 minute deployment timeline
  - Streamlined checklist format
  - Security hardening steps
  - Backup configuration
  - Auto-deployment via webhooks

- **docker-compose.prod.yml** - Production configuration overrides
  - Resource limits for all services
  - ASPNETCORE_ENVIRONMENT=Production
  - Removed SQL Server port exposure for security
  - Log rotation configuration
  - Optimized for production workloads

- **CHANGELOG.md** - This file documenting all changes

#### Documentation Updates
- **README.md** - Updated deployment section
  - Added links to new deployment guides
  - Deployment options comparison table
  - Quick start links
  - Security considerations

### Changed - Docker Compose Compatibility Improvements

#### docker-compose.yml Optimizations
- Added version 3.3 specification for broad compatibility
- Removed default value syntax `${VAR:-default}` in environment variables
- Converted healthcheck tests to array format `["CMD-SHELL", "command"]`
- Removed `start_period` from healthchecks (not supported in version 3.3)
- Simplified `depends_on` syntax (removed `condition: service_healthy`)

**Compatibility Impact:**
- ✅ Works with Docker Compose v1 (1.25.0+)
- ✅ Works with Docker Compose v2
- ✅ Compatible with Dokploy infrastructure
- ✅ Compatible with most PaaS platforms

### Production Features

#### Deployment Optimizations
1. **Docker Compose Version 3.3**
   - Maximum compatibility across platforms
   - Tested with Dokploy production environment
   - No parsing errors with environment variables

2. **Environment Variable Management**
   - All sensitive values via `.env` file
   - No defaults in docker-compose.yml
   - Platform-agnostic configuration

3. **Healthcheck Improvements**
   - Array format for consistent parsing
   - Realistic timeout values
   - Optimized intervals for production

4. **Resource Management**
   - Memory limits in prod compose file
   - CPU allocation
   - Log rotation to prevent disk exhaustion

5. **Security Hardening**
   - SQL Server port not exposed in production
   - Production environment configuration
   - Strong password requirements documented

#### Monitoring and Maintenance
- Automated volume backups guide
- Health check monitoring
- Log aggregation configuration
- Rollback procedures documented

#### Developer Experience
- Quick deploy checklist (production-ready in 20 minutes)
- Troubleshooting guide with common issues
- Lessons learned from real deployment
- Webhook setup for continuous deployment

### Technical Details

#### Files Modified
- `docker-compose.yml` - Compatibility improvements
- `README.md` - Deployment documentation updates

#### Files Added
- `DEPLOYMENT_DOKPLOY.md` (comprehensive, 800+ lines)
- `PRODUCTION_SETUP.md` (quick start, 400+ lines)
- `docker-compose.prod.yml` (production overrides)
- `CHANGELOG.md` (this file)

#### Deployment Tested
- ✅ Dokploy platform (production environment)
- ✅ Docker Compose v1.25.0
- ✅ Docker Compose v2.x
- ✅ Local development environment

### Lessons Learned (Production Deployment)

1. **Docker Compose Version Matters**
   - Version 3.3 is the sweet spot for compatibility
   - Modern syntax (3.8+) causes issues on some platforms
   - Default value syntax breaks on older parsers

2. **Healthcheck Format Critical**
   - Array format `["CMD-SHELL", "..."]` works everywhere
   - String format has inconsistent parsing
   - Explicit is better than implicit

3. **Feature Availability**
   - `start_period` not available in 3.3
   - `condition: service_healthy` requires 3.9+
   - Always check version compatibility matrix

4. **Environment Variables**
   - Platform injection is reliable
   - Avoid hardcoded defaults
   - Use `.env` for local, UI for production

5. **Startup Sequence**
   - SQL Server needs 20-40 seconds
   - Increase retry counts for reliability
   - Application handles connection retries well

### Migration Guide

For existing deployments, no breaking changes. To adopt new features:

1. **Update docker-compose.yml**:
   ```bash
   git pull origin main
   ```

2. **For production deployments**:
   ```bash
   # Review production configuration
   cat docker-compose.prod.yml

   # Deploy with production overrides
   docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
   ```

3. **Review security settings**:
   - Check ASPNETCORE_ENVIRONMENT is "Production"
   - Verify SQL Server port is not exposed
   - Confirm strong passwords in use

### Support

- **Documentation**: See DEPLOYMENT_DOKPLOY.md for comprehensive guide
- **Quick Start**: See PRODUCTION_SETUP.md for fast deployment
- **Issues**: Submit via GitHub issues
- **Community**: Dokploy community forums

---

## [1.0.0] - 2026-01-15

### Initial Release

- XAF Blazor Server application with Docker support
- SQL Server 2022 Express containerization
- Nginx reverse proxy with SSL support
- Let's Encrypt certificate management
- Development environment ready
- Basic documentation

---

**Version Format**: [Major.Minor.Patch]
- **Major**: Breaking changes
- **Minor**: New features, backward compatible
- **Patch**: Bug fixes, documentation updates
