# Stirling-PDF Railway Deployment Guide

Step-by-step instructions for deploying Stirling-PDF with split architecture (separate backend + frontend services).

## Architecture Overview

```
Internet → Frontend (Public, UI) → Backend (Private, API + Processing)
                                         ↓
                                    Single Volume (/data)
```

Both services use the same base Docker image. Backend uses a custom Dockerfile wrapper to enable single-volume deployment.

---

## Step 1: Create Backend Service

### Service Settings

| Setting | Value |
|---------|-------|
| **Name** | `Backend` |
| **Source** | GitHub repo → `solutions/stirling-pdf/backend` directory |
| **Port** | `8080` |
| **Visibility** | Private (no public domain) |

**Note**: The Backend uses a custom Dockerfile that wraps the official image to support Railway's single-volume requirement.

### Environment Variables

Copy and paste these variables into the Backend service:

```
# Mode Configuration
MODE=BACKEND

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

Create **one volume** for the Backend service:

| Volume Name | Mount Path | Purpose |
|-------------|------------|---------|
| `data` | `/data` | All persistent data (configs, pipeline, logs, tessdata) |

The custom Dockerfile automatically creates symlinks:
- `/data/configs` → `/configs` (settings, database, encryption keys)
- `/data/pipeline` → `/pipeline` (automation workflows)
- `/data/logs` → `/logs` (application logs)
- `/data/tessdata` → `/usr/share/tessdata` (OCR language files)

**To create the volume in Railway:**
1. Click on the Backend service
2. Go to **Settings** tab
3. Scroll to **Volumes**
4. Click **+ New Volume**
5. Enter mount path: `/data`

---

## Step 2: Create Frontend Service

### Service Settings

| Setting | Value |
|---------|-------|
| **Name** | `Frontend` |
| **Image** | `stirlingtools/stirling-pdf:latest` |
| **Port** | `8080` |
| **Visibility** | Public (generate domain) |

### Environment Variables

Copy and paste these variables into the Frontend service:

```
# Mode Configuration
MODE=FRONTEND

# Backend Connection (Railway variable reference)
BACKEND_URL=http://${{Backend.RAILWAY_PRIVATE_DOMAIN}}:8080
```

**Note**: `${{Backend.RAILWAY_PRIVATE_DOMAIN}}` references the Backend service via Railway's private networking.

### No Volume Needed

The Frontend service serves only the React UI and does not require any persistent storage.

---

## Step 3: Generate Public Domain

1. Click on the **Frontend** service
2. Go to **Settings** tab
3. Scroll to **Networking**
4. Click **Generate Domain** under Public Networking

Your Stirling-PDF instance will be accessible at the generated URL.

---

## Step 4: Deploy and Verify

1. Click **Deploy** for both services
2. Wait for both services to show healthy status
3. Access the Frontend URL in your browser
4. Login with credentials:
   - **Username**: `admin` (or your configured username)
   - **Password**: Value of `SECURITY_INITIALLOGIN_PASSWORD` from Backend variables

---

## Verification Checklist

### Backend Health
Check the Backend service logs for:
```
Volume symlinks configured:
  /configs -> /data/configs
  /pipeline -> /data/pipeline
  /logs -> /data/logs
  /usr/share/tessdata -> /data/tessdata
Started StirlingPdfApplication
```

### Frontend Connection
The Frontend logs should show successful connection to Backend.

### Test PDF Operations
1. Login via the Frontend URL
2. Upload a test PDF
3. Try a basic operation (e.g., compress or split)
4. Verify the operation completes successfully

### Volume Persistence
1. Create a pipeline automation or change a setting
2. Redeploy the Backend service
3. Verify your changes persist

---

## Environment Variables Reference

### Backend Service (All Variables)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `MODE` | Yes | - | Must be `BACKEND` |
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

### Frontend Service (All Variables)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `MODE` | Yes | - | Must be `FRONTEND` |
| `BACKEND_URL` | Yes | - | Backend service URL |

---

## Troubleshooting

### Frontend shows "Cannot connect to backend"

1. Verify Backend service is running and healthy
2. Check `BACKEND_URL` uses correct reference: `http://${{Backend.RAILWAY_PRIVATE_DOMAIN}}:8080`
3. Ensure both services are in the same Railway project

### Login fails with correct credentials

1. Verify `DOCKER_ENABLE_SECURITY=true` on Backend
2. Verify `SECURITY_ENABLELOGIN=true` on Backend
3. Check `/data` volume is mounted (stores user database in `/data/configs`)
4. Initial credentials only work for first login

### Changes not persisting after redeploy

1. Verify volume is mounted at `/data` on Backend service
2. Check Backend logs show "Volume symlinks configured" on startup

### OCR not working

1. Default image includes English OCR data
2. For additional languages, download `.traineddata` files from [tessdata](https://github.com/tesseract-ocr/tessdata)
3. Upload to the `/data/tessdata` directory via Railway shell or volume access

### API returns 401 Unauthorized

1. Login via web UI to establish session, or
2. Set `SECURITY_CUSTOMGLOBALAPIKEY` on Backend
3. Include `X-API-Key: your-key` header in requests

---

## Scaling Considerations

The split architecture enables independent scaling:

- **Multiple Frontends**: Add more Frontend replicas for UI traffic
- **Single Backend**: Backend handles all processing (typically the bottleneck)
- **Vertical Scaling**: Increase Backend CPU/memory for heavier PDF operations

To scale Frontend replicas in Railway:
1. Go to Frontend service → Settings
2. Adjust replica count under Scaling
