# DevExpress License Configuration Design

**Date:** 2026-03-23
**Status:** Approved for Implementation

## Problem Statement

The application currently shows DevExpress trial license warnings (DX1000/DX1001) during builds:
- DX1000: "For evaluation purposes only. Redistribution prohibited."
- DX1001: Instructs to place license file in specific locations

These warnings appear in:
- Native Linux (WSL) development builds
- Docker image builds
- Both prevent clean production deployments

## Requirements

1. Eliminate DX1000/DX1001 warnings from build output
2. Support native Linux development environment
3. Support Docker builds (local and Dokploy)
4. Use existing `.env` file with `DevExpress_License` variable
5. Keep license key secure (not committed to git)
6. Work seamlessly with Dokploy deployment platform

## Solution Design

### Architecture Overview

Use environment variable-based approach with dynamic file generation:
- **Source of truth**: `DevExpress_License` in `.env` file
- **Native Linux**: Setup script creates `~/.config/DevExpress/DevExpress_License.txt`
- **Docker build**: Build ARG creates `/root/.config/DevExpress/DevExpress_License.txt`
- **Dokploy**: Environment variable passed through Dokploy UI

### Component 1: Native Linux Setup Script

**File:** `scripts/setup-devexpress-license.sh`

**Purpose:** One-time setup for local development

**Behavior:**
1. Check if `.env` file exists
2. Extract `DevExpress_License` value from `.env`
3. Create `$HOME/.config/DevExpress/` directory
4. Write license key to `DevExpress_License.txt`
5. Set appropriate file permissions

**Usage:**
```bash
./scripts/setup-devexpress-license.sh
```

### Component 2: Dockerfile Modifications

**Changes to Dockerfile:**

Add in the build stage (after FROM, before dotnet restore):
```dockerfile
# DevExpress License Configuration
ARG DevExpress_License
RUN if [ -n "$DevExpress_License" ]; then \
        mkdir -p /root/.config/DevExpress && \
        echo "$DevExpress_License" > /root/.config/DevExpress/DevExpress_License.txt; \
    fi
```

**Why build stage?**
- License needed during `dotnet build` compilation
- MSBuild checks for license during compilation
- Not needed at runtime (only build-time validation)

### Component 3: Docker Compose Configuration

**Changes to docker-compose.yml and docker-compose.prod.yml:**

Add build args section to xafapp service:
```yaml
xafapp:
  build:
    context: .
    dockerfile: Dockerfile
    args:
      - DevExpress_License=${DevExpress_License}
```

**Behavior:**
- Local: Reads from `.env` file automatically
- Dokploy: Reads from environment variables configured in UI

### Component 4: Git Configuration

**Update `.gitignore`:**
```
# DevExpress License Files
DevExpress_License.txt
.config/DevExpress/
```

**Security:**
- `.env` already excluded from git
- License file explicitly excluded
- DevExpress config directory excluded

### Component 5: Documentation

**Update CLAUDE.md** with:
- DevExpress license setup instructions
- Reference to setup script
- Dokploy configuration steps

**Create docs/DEVEXPRESS-LICENSE-SETUP.md** with:
- How to obtain license from DevExpress
- Step-by-step setup for all environments
- Troubleshooting common issues

## Workflows

### Workflow 1: Initial Local Development Setup

```bash
# 1. Clone repository
git clone <repo-url>
cd XAFDocker

# 2. Configure license in .env (already done)
# DevExpress_License="your-key-here"

# 3. Run setup script
./scripts/setup-devexpress-license.sh

# 4. Build and verify
dotnet build XAFDocker.sln
# Should see no DX1000/DX1001 warnings
```

### Workflow 2: Docker Local Build

```bash
# Build with docker-compose
docker compose -f docker-compose.prod.yml build

# Verify no warnings in build output
docker compose -f docker-compose.prod.yml build 2>&1 | grep DX100
# Should return empty
```

### Workflow 3: Dokploy Deployment

1. Navigate to Dokploy project settings
2. Go to Environment Variables section
3. Add variable:
   - Name: `DevExpress_License`
   - Value: `<your-license-key>`
4. Save and redeploy
5. Dokploy automatically passes to build as ARG

## Testing & Verification

### Success Criteria
- No DX1000 warnings in native builds
- No DX1001 warnings in native builds
- No warnings in Docker build logs
- Application runs correctly in all environments

### Test Cases

**Test 1: Native Linux Build**
```bash
dotnet clean
dotnet build XAFDocker.sln 2>&1 | tee build.log
grep "DX100" build.log  # Should be empty
```

**Test 2: Docker Build**
```bash
docker compose -f docker-compose.prod.yml build --no-cache 2>&1 | tee docker-build.log
grep "DX100" docker-build.log  # Should be empty
```

**Test 3: Verify License File Exists**
```bash
# Native
cat ~/.config/DevExpress/DevExpress_License.txt

# Docker (during build)
docker compose -f docker-compose.prod.yml build
docker run --rm <image-id> cat /root/.config/DevExpress/DevExpress_License.txt
```

## Error Handling

### Missing .env File
Setup script checks and displays error:
```
Error: .env file not found
Please create .env file with DevExpress_License variable
```

### Empty License Variable
Setup script validates and displays error:
```
Error: DevExpress_License not found in .env
Please add: DevExpress_License="your-key-here"
```

### Invalid License Key
DevExpress build process will show specific error (not our handling)

### Docker Build Without License
Build succeeds with warnings (graceful degradation)

## Security Considerations

### Acceptable Risks
- **Build ARG visibility**: Docker image history shows build args
  - Acceptable: License is not a secret for trial/paid users
  - Anyone with valid DevExpress account can get a license
  - Alternative would require multi-stage secrets (complex, minimal benefit)

### Mitigations
- `.env` file never committed (in `.gitignore`)
- License file never committed (in `.gitignore`)
- Dokploy environment variables encrypted at rest
- No license in application logs or runtime environment

### Best Practices
- Developers should not share license keys
- Each developer should use their own DevExpress account
- Production deployments should use team/company license

## Implementation Checklist

1. Create `scripts/setup-devexpress-license.sh`
2. Make script executable (`chmod +x`)
3. Update `Dockerfile` with ARG and license file creation
4. Update `docker-compose.yml` with build args
5. Update `docker-compose.prod.yml` with build args
6. Update `.gitignore` with license file patterns
7. Update `CLAUDE.md` with license configuration section
8. Create `docs/DEVEXPRESS-LICENSE-SETUP.md`
9. Test native build (verify no warnings)
10. Test Docker build (verify no warnings)
11. Update BACKLOG.md (mark Step 1 as complete)
12. Commit all changes to git

## Future Considerations

### License Expiration
- Trial licenses expire after 30 days
- Paid licenses typically annual
- On expiration, warnings return
- Solution: Update license key in `.env` and re-run setup

### Team License Management
- For team/company licenses, consider:
  - Shared secret management (Vault, AWS Secrets Manager)
  - CI/CD integration for automated builds
  - License rotation procedures

### Alternative Approaches Considered

**Approach A: File-based (not chosen)**
- Store `DevExpress_License.txt` in repo root
- Mount as volume in Docker
- Pros: Simple, standard DevExpress approach
- Cons: Risk of committing to git, harder to manage across environments

**Approach B: Docker secrets (not chosen)**
- Use Docker secrets for license
- Pros: Most secure
- Cons: Complex setup, not supported in all environments, overkill for license key

**Approach C: Runtime generation (not chosen)**
- Create license file at container startup
- Pros: More dynamic
- Cons: License only needed at build time, adds runtime complexity

## References

- [DevExpress License Key Setup](https://docs.devexpress.com/GeneralInformation/405494/trial-register/set-up-your-dev-express-license-key)
- [Docker Build Arguments](https://docs.docker.com/engine/reference/builder/#arg)
- [Docker Compose Build Args](https://docs.docker.com/compose/compose-file/build/#args)
