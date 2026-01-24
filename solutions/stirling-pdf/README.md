# Stirling-PDF

A self-hosted PDF manipulation toolkit with 50+ tools, REST API, and built-in authentication—deployed with split architecture for scalability.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/template/stirling-pdf?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Overview

This solution deploys Stirling-PDF using split architecture:
- **Backend**: API server, PDF processing engine, authentication, and storage
- **Frontend**: React web UI served separately
- **Built-in Authentication**: Native login system with configurable admin credentials
- **Persistent Storage**: Railway volumes for configs, pipeline, logs, and OCR data

Split architecture enables independent scaling—add frontend replicas for UI traffic while the backend handles processing.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          Internet                                │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Frontend (Public)                             │
│                    Port 8080                                     │
│                    React Web UI                                  │
│                    No volumes needed                             │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                │ BACKEND_URL (internal)
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Backend (Private)                             │
│                    Port 8080                                     │
│                    API + PDF Processing                          │
│                    Built-in Auth                                 │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
                ┌───────────────────────────────┐
                │         /data Volume          │
                │  ┌─────────┬─────────┐       │
                │  │ configs │ pipeline│       │
                │  ├─────────┼─────────┤       │
                │  │  logs   │tessdata │       │
                │  └─────────┴─────────┘       │
                └───────────────────────────────┘
```

## Quick Start

1. Click the **Deploy on Railway** button above
2. Wait for both services to deploy
3. Access Stirling-PDF via the Frontend's generated Railway domain
4. Login with the default credentials (see below)

For manual deployment, see [deployment.md](./deployment.md).

## Services Included

| Service | Source | Mode | Visibility |
|---------|--------|------|------------|
| Backend | `backend/Dockerfile` (custom wrapper) | `BACKEND` | Private |
| Frontend | `stirlingtools/stirling-pdf:latest` | `FRONTEND` | Public |

The Backend uses a custom Dockerfile that wraps the official image to support Railway's single-volume requirement via symlinks.

## Accessing Stirling-PDF After Deployment

After deployment, click on the **Frontend** service to find your URL:

1. **Deployments Tab**: The URL is displayed directly under the service name
2. **Settings > Networking**: Go to Settings tab → scroll to Networking → find Public Networking

### Default Login Credentials

| Credential | Default Value |
|------------|---------------|
| Username | `admin` |
| Password | Value of `SECURITY_INITIALLOGIN_PASSWORD` in Backend variables |

To find or change your password:
1. Open your Railway project dashboard
2. Click on the **Backend** service
3. Go to the **Variables** tab
4. Find `SECURITY_INITIALLOGIN_PASSWORD` - click the eye icon to reveal

**Important**: After first login, you can change your password in the Stirling-PDF settings. The initial password is only used for the first login.

## Environment Variables

### Backend Service

#### User-Configurable Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SECURITY_INITIALLOGIN_USERNAME` | `admin` | Initial admin username |
| `SECURITY_INITIALLOGIN_PASSWORD` | `${{secret(32)}}` | Initial admin password (auto-generated) |
| `SYSTEM_DEFAULTLOCALE` | `en-US` | Default UI language (40+ languages available) |
| `UI_APPNAME` | `Stirling-PDF` | Application name shown in UI |
| `UI_APPNAMENAVBAR` | `Stirling-PDF` | Application name in navbar |
| `SYSTEM_MAXFILESIZE` | `100` | Maximum file upload size in MB |
| `SECURITY_CUSTOMGLOBALAPIKEY` | - | Optional: Set a custom API key for REST API access |

#### Auto-Configured (Do Not Change)

| Variable | Value | Description |
|----------|-------|-------------|
| `MODE` | `BACKEND` | Service mode. Enables API and processing. |
| `DOCKER_ENABLE_SECURITY` | `true` | Enables security features. Required for auth. |
| `SECURITY_ENABLELOGIN` | `true` | Enables login requirement. Required for auth. |
| `METRICS_ENABLED` | `true` | Enables application metrics endpoint. |

### Frontend Service

| Variable | Value | Description |
|----------|-------|-------------|
| `MODE` | `FRONTEND` | Service mode. Serves UI only. |
| `BACKEND_URL` | `http://${{Backend.RAILWAY_PRIVATE_DOMAIN}}:8080` | Backend service URL via Railway internal networking. |

## Volume (Backend Only)

| Mount Path | Purpose |
|------------|---------|
| `/data` | All persistent data |

The custom Dockerfile creates symlinks from `/data` subdirectories to expected paths:
- `/data/configs` → `/configs` (settings, database, encryption keys)
- `/data/pipeline` → `/pipeline` (automation workflows)
- `/data/logs` → `/logs` (application logs)
- `/data/tessdata` → `/usr/share/tessdata` (OCR language files)

Data persists across redeployments. The Frontend service requires no volumes.

## PDF Tools Available

Stirling-PDF includes 50+ tools organized by category:

### Convert & Export
- PDF to/from images (PNG, JPEG, TIFF, WebP)
- PDF to/from Word, Excel, PowerPoint
- HTML/URL to PDF
- Markdown to PDF

### Organize Pages
- Merge multiple PDFs
- Split PDFs (by pages, size, bookmarks)
- Rotate, reorder, remove pages
- Extract pages

### Edit & Modify
- Add/remove watermarks
- Add page numbers
- Add images, text overlays
- Flatten annotations

### Security
- Add/remove passwords
- Change permissions
- Redact sensitive content
- Sanitize metadata

### OCR & Text
- OCR scanned documents
- Extract text from PDFs
- Add selectable text layer

### Advanced
- Compress PDFs
- Repair corrupted PDFs
- Compare two PDFs
- Auto-split by blank pages

## REST API

Stirling-PDF provides a comprehensive REST API for automation.

### API Documentation

Access the built-in Swagger documentation at:
```
https://your-frontend-url.railway.app/swagger-ui/index.html
```

### Authentication

For API access, you can either:
1. Use session-based auth (login via web UI first)
2. Set `SECURITY_CUSTOMGLOBALAPIKEY` on Backend and use the `X-API-Key` header

### Example API Call

```bash
# Merge two PDFs
curl -X POST "https://your-frontend-url.railway.app/api/v1/general/merge-pdfs" \
  -H "X-API-Key: your-api-key" \
  -F "fileInput=@file1.pdf" \
  -F "fileInput=@file2.pdf" \
  -o merged.pdf
```

## User Management

Stirling-PDF includes built-in user management:

- **Admin User**: Created on first startup with initial credentials
- **Additional Users**: Admin can create additional user accounts
- **Roles**: Admin and standard user roles available
- **Session Management**: Automatic session handling with configurable timeouts

## Security

- Authentication required to access all features
- No documents sent to external services—all processing is local
- Backend runs on private network (not directly accessible from internet)
- Frontend is the only public-facing service
- Password-protected PDF operations available
- API key authentication for programmatic access

## Scaling

Split architecture enables flexible scaling:

| Scenario | Action |
|----------|--------|
| High UI traffic | Add Frontend replicas |
| Heavy PDF processing | Increase Backend CPU/memory |
| Large file uploads | Increase `SYSTEM_MAXFILESIZE` and Backend resources |

## Troubleshooting

### Frontend shows "Cannot connect to backend"

1. Verify Backend service is running and healthy
2. Check `BACKEND_URL` in Frontend uses correct format: `http://${{Backend.RAILWAY_PRIVATE_DOMAIN}}:8080`
3. Ensure both services are in the same Railway project

### Cannot login with default credentials

1. Verify `DOCKER_ENABLE_SECURITY=true` and `SECURITY_ENABLELOGIN=true` on Backend
2. Check `SECURITY_INITIALLOGIN_PASSWORD` in Backend's Variables tab
3. Initial credentials only work for first login; if you've already logged in and changed password, use that instead
4. Verify `/data` volume is mounted on Backend (stores user database in `/data/configs`)

### OCR not working

OCR requires Tesseract language data. The default image includes English. For additional languages:
1. Download `.traineddata` files from [tessdata repository](https://github.com/tesseract-ocr/tessdata)
2. Upload to `/data/tessdata` on Backend (symlinked to `/usr/share/tessdata`)

### File upload fails

Check `SYSTEM_MAXFILESIZE` setting on Backend. Default is 100MB. Increase if needed for larger files.

### API returns 401 Unauthorized

Either:
- Login via web UI first to establish a session
- Or set `SECURITY_CUSTOMGLOBALAPIKEY` on Backend and include `X-API-Key` header in requests

### Changes not persisting after redeploy

1. Verify `/data` volume is mounted on Backend
2. Check Backend logs show "Volume symlinks configured" on startup

## Resources

- [Stirling-PDF Documentation](https://docs.stirlingpdf.com)
- [Stirling-PDF GitHub](https://github.com/Stirling-Tools/Stirling-PDF)
- [API Documentation](https://registry.scalar.com/@stirlingpdf/apis/stirling-pdf-processing-api/)
- [Discord Community](https://discord.gg/HYmhKj45pU)
