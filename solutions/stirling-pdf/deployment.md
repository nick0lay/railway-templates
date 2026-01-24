# Stirling-PDF Railway Deployment Guide

Step-by-step instructions for deploying Stirling-PDF on Railway.

## Architecture Overview

```
Internet → Stirling-PDF (Public) → Volume (/data)
```

Single service handles both UI and PDF processing with built-in authentication.

---

## Step 1: Create Service

### Service Settings

| Setting | Value |
|---------|-------|
| **Name** | `Stirling-PDF` |
| **Source** | GitHub repo → `solutions/stirling-pdf/app` directory |
| **Port** | `8080` |
| **Visibility** | Public (generate domain) |

**Note**: The service uses a custom Dockerfile that wraps the official image to support Railway's single-volume requirement.

### Environment Variables

Copy and paste these variables into the service:

```
# Security (Required)
DOCKER_ENABLE_SECURITY=true
SECURITY_ENABLELOGIN=true
SECURITY_INITIALLOGIN_USERNAME=admin
SECURITY_INITIALLOGIN_PASSWORD=${{secret(32)}}

# System Settings
SYSTEM_DEFAULTLOCALE=en-US
SYSTEM_MAXFILESIZE=100
METRICS_ENABLED=true

# UI Branding (Optional)
UI_APPNAME=Stirling-PDF
UI_APPNAMENAVBAR=Stirling-PDF

# Optional: API Key for external API access
# SECURITY_CUSTOMGLOBALAPIKEY=your-secure-api-key
```

**Note**: `${{secret(32)}}` is a Railway template function that auto-generates a secure 32-character password on deploy.

### Volume Mount

Create **one volume** for persistent data:

| Volume Name | Mount Path | Purpose |
|-------------|------------|---------|
| `data` | `/data` | All persistent data (configs, pipeline, logs, tessdata) |

The custom Dockerfile automatically creates symlinks:
- `/data/configs` → `/configs` (settings, database, encryption keys)
- `/data/pipeline` → `/pipeline` (automation workflows)
- `/data/logs` → `/logs` (application logs)
- `/data/tessdata` - Used via TESSDATA_PREFIX (OCR language files)

**To create the volume in Railway:**
1. Click on the service
2. Go to **Settings** tab
3. Scroll to **Volumes**
4. Click **+ New Volume**
5. Enter mount path: `/data`

---

## Step 2: Generate Public Domain

1. Click on the **Stirling-PDF** service
2. Go to **Settings** tab
3. Scroll to **Networking**
4. Click **Generate Domain** under Public Networking

Your Stirling-PDF instance will be accessible at the generated URL.

---

## Step 3: Deploy and Verify

1. Click **Deploy**
2. Wait for the service to show healthy status
3. Access the public URL in your browser
4. Login with credentials:
   - **Username**: `admin` (or your configured username)
   - **Password**: Value of `SECURITY_INITIALLOGIN_PASSWORD` from Variables tab

---

## Verification Checklist

### Service Health
Check the service logs for:
```
=== Stirling-PDF Volume Setup ===
Configuration:
  TESSDATA_PREFIX=/data/tessdata
  Contents: X files
  Permissions: 777
Started StirlingPdfApplication
```

### Test PDF Operations
1. Login via the URL
2. Upload a test PDF
3. Try a basic operation (e.g., compress or split)
4. Verify the operation completes successfully

### Volume Persistence
1. Create a pipeline automation or change a setting
2. Redeploy the service
3. Verify your changes persist

---

## Environment Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOCKER_ENABLE_SECURITY` | Yes | - | Must be `true` for auth |
| `SECURITY_ENABLELOGIN` | Yes | - | Must be `true` for login |
| `SECURITY_INITIALLOGIN_USERNAME` | Yes | `admin` | Initial admin username |
| `SECURITY_INITIALLOGIN_PASSWORD` | Yes | `${{secret(32)}}` | Initial admin password (auto-generated) |
| `SYSTEM_DEFAULTLOCALE` | No | `en-US` | Default UI language |
| `SYSTEM_MAXFILESIZE` | No | `100` | Max upload size (MB) |
| `METRICS_ENABLED` | No | `false` | Enable metrics endpoint |
| `UI_APPNAME` | No | `Stirling-PDF` | App name in UI |
| `UI_APPNAMENAVBAR` | No | `Stirling-PDF` | App name in navbar |
| `SECURITY_CUSTOMGLOBALAPIKEY` | No | - | API key for REST access |

---

## Troubleshooting

### Login fails with correct credentials

1. Verify `DOCKER_ENABLE_SECURITY=true`
2. Verify `SECURITY_ENABLELOGIN=true`
3. Check `/data` volume is mounted (stores user database in `/data/configs`)
4. Initial credentials only work for first login

### Changes not persisting after redeploy

1. Verify volume is mounted at `/data`
2. Check logs show "Stirling-PDF Volume Setup" on startup

### OCR not working

1. Default image includes English OCR data
2. Download additional language packs via the admin panel
3. Languages are stored in `/data/tessdata` and persist across redeploys

### API returns 401 Unauthorized

1. Login via web UI to establish session, or
2. Set `SECURITY_CUSTOMGLOBALAPIKEY`
3. Include `X-API-Key: your-key` header in requests

---

## Scaling Considerations

To scale for higher load:
- **Vertical Scaling**: Increase CPU/memory for heavier PDF operations
- **Replica Scaling**: Add replicas for higher throughput (requires shared volume or external storage for configs)

To adjust resources in Railway:
1. Go to service → Settings
2. Adjust resources under Scaling
