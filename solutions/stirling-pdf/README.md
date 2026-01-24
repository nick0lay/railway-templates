# Stirling-PDF

A self-hosted PDF manipulation toolkit with 50+ tools, REST API, and built-in authentication.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/template/stirling-pdf?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Overview

This solution deploys Stirling-PDF as a single service with:
- **PDF Processing**: 50+ tools for merging, splitting, converting, OCR, and more
- **Built-in Authentication**: Native login system with configurable admin credentials
- **REST API**: Full API access with Swagger documentation
- **Persistent Storage**: Railway volume for configs, logs, and OCR language data

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          Internet                                │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Stirling-PDF (Public)                         │
│                    Port 8080                                     │
│                    Web UI + API + PDF Processing                 │
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
2. Wait for the service to deploy
3. Access Stirling-PDF via the generated Railway domain
4. Login with the default credentials (see below)

For local testing, run the official Docker image with the same environment variables.

## Service

| Service | Source | Description |
|---------|--------|-------------|
| Stirling-PDF | `app/Dockerfile` | Web UI, API, and PDF processing with authentication |

The custom Dockerfile wraps the official image to support Railway's single-volume requirement via symlinks.

## Accessing Stirling-PDF After Deployment

After deployment, click on the service to find your URL:

1. **Deployments Tab**: The URL is displayed directly under the service name
2. **Settings > Networking**: Go to Settings tab → scroll to Networking → find Public Networking

### Default Login Credentials

| Credential | Default Value |
|------------|---------------|
| Username | `admin` |
| Password | Value of `SECURITY_INITIALLOGIN_PASSWORD` in Variables |

To find or change your password:
1. Open your Railway project dashboard
2. Click on the **Stirling-PDF** service
3. Go to the **Variables** tab
4. Find `SECURITY_INITIALLOGIN_PASSWORD` - click the eye icon to reveal

**Important**: After first login, you can change your password in the Stirling-PDF settings. The initial password is only used for the first login.

## Environment Variables

### User-Configurable Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SECURITY_INITIALLOGIN_USERNAME` | `admin` | Initial admin username |
| `SECURITY_INITIALLOGIN_PASSWORD` | `${{secret(32)}}` | Initial admin password (auto-generated) |
| `SYSTEM_DEFAULTLOCALE` | `en-US` | Default UI language (40+ languages available) |
| `UI_APPNAME` | `Stirling-PDF` | Application name shown in UI |
| `UI_APPNAMENAVBAR` | `Stirling-PDF` | Application name in navbar |
| `SYSTEM_MAXFILESIZE` | `100` | Maximum file upload size in MB |
| `SECURITY_CUSTOMGLOBALAPIKEY` | - | Optional: Set a custom API key for REST API access |

### Auto-Configured (Do Not Change)

| Variable | Value | Description |
|----------|-------|-------------|
| `DOCKER_ENABLE_SECURITY` | `true` | Enables security features. Required for auth. |
| `SECURITY_ENABLELOGIN` | `true` | Enables login requirement. Required for auth. |
| `METRICS_ENABLED` | `true` | Enables application metrics endpoint. |

## Volume

| Mount Path | Purpose |
|------------|---------|
| `/data` | All persistent data |

The custom Dockerfile creates symlinks from `/data` subdirectories to expected paths:
- `/data/configs` → `/configs` (settings, database, encryption keys)
- `/data/pipeline` → `/pipeline` (automation workflows)
- `/data/logs` → `/logs` (application logs)
- `/data/tessdata` - Used directly via `TESSDATA_PREFIX` env var (OCR language files)

Data persists across redeployments.

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
https://your-url.railway.app/swagger-ui/index.html
```

### Authentication

For API access, you can either:
1. Use session-based auth (login via web UI first)
2. Set `SECURITY_CUSTOMGLOBALAPIKEY` and use the `X-API-Key` header

### Example API Call

```bash
# Merge two PDFs
curl -X POST "https://your-url.railway.app/api/v1/general/merge-pdfs" \
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
- Password-protected PDF operations available
- API key authentication for programmatic access

## Troubleshooting

### Cannot login with default credentials

1. Verify `DOCKER_ENABLE_SECURITY=true` and `SECURITY_ENABLELOGIN=true`
2. Check `SECURITY_INITIALLOGIN_PASSWORD` in the Variables tab
3. Initial credentials only work for first login; if you've already logged in and changed password, use that instead
4. Verify `/data` volume is mounted (stores user database in `/data/configs`)

### OCR not working

OCR requires Tesseract language data. The default image includes English. For additional languages:
1. Download additional language packs via the Stirling-PDF admin panel
2. Languages are stored in `/data/tessdata` and persist across redeploys

### File upload fails

Check `SYSTEM_MAXFILESIZE` setting. Default is 100MB. Increase if needed for larger files.

### API returns 401 Unauthorized

Either:
- Login via web UI first to establish a session
- Or set `SECURITY_CUSTOMGLOBALAPIKEY` and include `X-API-Key` header in requests

### Changes not persisting after redeploy

1. Verify `/data` volume is mounted
2. Check service logs for "Stirling-PDF Volume Setup" message on startup

## Resources

- [Stirling-PDF Documentation](https://docs.stirlingpdf.com)
- [Stirling-PDF GitHub](https://github.com/Stirling-Tools/Stirling-PDF)
- [API Documentation](https://registry.scalar.com/@stirlingpdf/apis/stirling-pdf-processing-api/)
- [Discord Community](https://discord.gg/HYmhKj45pU)
