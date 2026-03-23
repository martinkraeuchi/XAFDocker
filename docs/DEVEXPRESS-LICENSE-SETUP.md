# DevExpress License Setup Guide

This guide explains how to configure your DevExpress license key for the XAFDocker application in both local development and production environments.

## Why Configure the License?

Without a properly configured license, you'll see these warnings during builds:
- **DX1000**: "For evaluation purposes only. Redistribution prohibited."
- **DX1001**: Instructions to place license file in specific locations

These warnings are harmless but clutter build output and indicate the license isn't properly configured.

## Obtaining Your License Key

### For Trial Users

1. Visit [devexpress.com](https://devexpress.com)
2. Click "Free Trial" and register for a 30-day trial
3. After registration, login to your account
4. Navigate to **My Account** → **License Keys**
5. Copy your license key (it will look like: `tqK2i3V7YlJP3A6XmOrF...`)

### For Licensed Users

1. Login to [devexpress.com](https://devexpress.com)
2. Navigate to **My Account** → **License Keys**
3. Copy your license key

## Local Development Setup (Native Linux/WSL)

### Step 1: Add License to .env File

The `.env` file should already exist in your project root. Add or update this line:

```bash
DevExpress_License="your-license-key-here"
```

**Example:**
```bash
DevExpress_License="tqK2i3V7YlJP3A6XmOrF2AfXn6FaUkvXocaCNwBqHPMuoUmt4Z"
```

### Step 2: Run the Setup Script

Execute the provided setup script to create the license file in the correct location:

```bash
cd /path/to/XAFDocker
./scripts/setup-devexpress-license.sh
```

**What the script does:**
- Reads the `DevExpress_License` from `.env`
- Creates `~/.config/DevExpress/` directory
- Writes the license key to `DevExpress_License.txt`
- Sets appropriate file permissions

### Step 3: Verify the Setup

Build the project and check for warnings:

```bash
dotnet build XAFDocker.sln
```

**Success:** No DX1000 or DX1001 warnings in the output.

**If you still see warnings:**
- Verify the license file exists: `cat ~/.config/DevExpress/DevExpress_License.txt`
- Check the license key in `.env` is correct (no extra quotes or spaces)
- Re-run the setup script

## Docker Development/Testing

The Docker setup automatically reads the license from your `.env` file.

### Build Docker Image

```bash
# Development build
docker compose build

# Production build
docker compose -f docker-compose.prod.yml build
```

### Verify No Warnings

Check the build output for DX1000/DX1001 warnings:

```bash
docker compose build 2>&1 | grep "DX100"
```

**Success:** Command returns empty (no matches).

## Dokploy Production Deployment

For production deployments using Dokploy:

### Step 1: Configure Environment Variable in Dokploy

1. Login to your Dokploy dashboard
2. Navigate to your XAFDocker project
3. Go to **Settings** → **Environment Variables**
4. Add a new environment variable:
   - **Name**: `DevExpress_License`
   - **Value**: `your-license-key-here`
5. Click **Save**

### Step 2: Redeploy the Application

1. Click **Deploy** or **Redeploy** in Dokploy
2. Monitor the build logs
3. Verify no DX1000/DX1001 warnings appear

### Step 3: Verify Deployment

Check the deployment logs in Dokploy:
- Build phase should complete without license warnings
- Application should start successfully

## Troubleshooting

### Problem: Still seeing DX1000/DX1001 warnings

**Solution 1: Verify license file exists**
```bash
# Native Linux
cat ~/.config/DevExpress/DevExpress_License.txt

# Docker (during build)
docker compose build --progress=plain 2>&1 | grep "DevExpress license"
```

**Solution 2: Check .env file**
```bash
grep "DevExpress_License" .env
```

Make sure:
- The line starts with `DevExpress_License=`
- The value is in quotes
- There are no extra spaces or newlines
- The file is in the project root

**Solution 3: Re-run setup script**
```bash
./scripts/setup-devexpress-license.sh
```

### Problem: Script fails with "DevExpress_License not found"

**Solution:**
The `.env` file doesn't contain the license variable. Add it:
```bash
echo 'DevExpress_License="your-key-here"' >> .env
```

### Problem: Docker build doesn't pick up license

**Solution:**
Ensure the build args are configured in docker-compose files:
```yaml
xafapp:
  build:
    context: .
    dockerfile: Dockerfile
    args:
      - DevExpress_License=${DevExpress_License}
```

### Problem: License expired (trial or paid)

**Solution:**
1. Obtain a new license key from devexpress.com
2. Update the `.env` file with the new key
3. For native builds: Re-run `./scripts/setup-devexpress-license.sh`
4. For Docker: Rebuild the image

### Problem: Different license key for different developers

**Solution:**
Each developer should:
1. Use their own DevExpress account
2. Get their own license key
3. Configure their local `.env` file
4. NOT commit `.env` to git (it's already in `.gitignore`)

## Security Best Practices

### ✅ DO:
- Keep your license key private
- Use your own DevExpress account and license
- Store the license in `.env` (which is git-ignored)
- Configure Dokploy environment variables securely

### ❌ DON'T:
- Share license keys between developers
- Commit `.env` file to git
- Commit `DevExpress_License.txt` file to git
- Include license key in public repositories or logs

## File Locations

| Environment | License File Location |
|-------------|----------------------|
| Native Linux/WSL | `~/.config/DevExpress/DevExpress_License.txt` |
| Docker Build | `/root/.config/DevExpress/DevExpress_License.txt` |
| Source | `.env` file (git-ignored) |

## License Renewal

### Trial License (30 days)
When your trial expires:
1. Purchase a DevExpress license OR
2. Request an extension (sometimes available)
3. Update your license key in `.env`
4. Re-run setup script

### Paid License (Annual)
When your paid license renews:
1. Login to devexpress.com
2. Download the new license key
3. Update `.env` file
4. Re-run setup script
5. Rebuild Docker images

## Additional Resources

- [DevExpress License Documentation](https://docs.devexpress.com/GeneralInformation/405494/trial-register/set-up-your-dev-express-license-key)
- [Project Design Document](plans/2026-03-23-devexpress-license-configuration-design.md)
- [Main Documentation](../CLAUDE.md)

## Support

If you continue to experience issues:
1. Check DevExpress support forums
2. Verify your DevExpress subscription is active
3. Contact DevExpress support with your account details
