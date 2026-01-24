# Stirling-PDF Railway Template

## Template Overview

# Deploy and Host Stirling-PDF on Railway

Stirling-PDF is a powerful open-source PDF manipulation platform with 50+ tools for merging, splitting, converting, OCR, signing, and more. All processing happens on your server—no documents are sent to external services. This template deploys with built-in authentication to protect your instance.

## About Hosting Stirling-PDF

This template deploys Stirling-PDF as a single service with:

- **PDF Processing**: 50+ tools for all your PDF manipulation needs
- **REST API**: Full API access with Swagger documentation for automation
- **Built-in Authentication**: Native login system with configurable admin credentials
- **Persistent Storage**: Railway volume for configs, logs, and OCR language data

Railway volumes ensure your configuration, pipelines, logs, and OCR data persist across redeployments.

## Getting Started After Deployment

### Accessing Stirling-PDF

After deployment, click on the **Stirling-PDF** service to find your URL:

1. **Deployments Tab**: The URL is displayed directly under the service name
2. **Settings > Networking**: Go to Settings tab → scroll to Networking → find Public Networking

### Finding Your Login Credentials

Default login credentials:

1. **Username**: `admin` (or value of `SECURITY_INITIALLOGIN_USERNAME`)
2. **Password**: Found in the service's **Variables** tab under `SECURITY_INITIALLOGIN_PASSWORD`

A secure 32-character password is auto-generated on deploy using Railway's `${{secret(32)}}` template function. After first login, you can change your password in the application settings.

### Using the REST API

Access the API documentation at `https://your-url/swagger-ui/index.html`. For programmatic access:

1. Set `SECURITY_CUSTOMGLOBALAPIKEY` in service Variables
2. Include `X-API-Key: your-key` header in API requests

## Common Use Cases

- Self-hosted PDF toolkit for teams needing merge, split, compress, and convert capabilities
- Automated document processing workflows via REST API
- OCR processing for scanned documents while keeping data on-premises
- Secure PDF signing and redaction for sensitive documents
- Converting Office documents (Word, Excel, PowerPoint) to PDF
- Batch processing PDFs without uploading to cloud services
- Internal company tool with access control

## Dependencies for Stirling-PDF Hosting

- Docker (Stirling-PDF runs as a container image)

### Deployment Dependencies

- [Stirling-PDF GitHub Repository](https://github.com/Stirling-Tools/Stirling-PDF)
- [Stirling-PDF Docker Image](https://hub.docker.com/r/stirlingtools/stirling-pdf)

### Service

| Service | Source | Description |
|---------|--------|-------------|
| Stirling-PDF | Custom Dockerfile | Web UI, API, and PDF processing with authentication |

The custom Dockerfile wraps the official image to support Railway's single-volume requirement.

### Environment Variables

| Variable | Description |
|----------|-------------|
| `SECURITY_INITIALLOGIN_USERNAME` | Admin username (default: `admin`) |
| `SECURITY_INITIALLOGIN_PASSWORD` | Admin password (`${{secret(32)}}` auto-generates) |
| `DOCKER_ENABLE_SECURITY` | Enable security features (auto-configured: `true`) |
| `SECURITY_ENABLELOGIN` | Require login (auto-configured: `true`) |
| `SYSTEM_DEFAULTLOCALE` | Default language (default: `en-US`) |
| `UI_APPNAME` | Application name shown in UI |
| `SYSTEM_MAXFILESIZE` | Max upload size in MB (default: `100`) |
| `SECURITY_CUSTOMGLOBALAPIKEY` | Optional API key for REST API access |

### Volume

| Mount Path | Purpose |
|------------|---------|
| `/data` | All persistent data (configs, pipeline, logs, tessdata) |

The custom Dockerfile creates symlinks to map subdirectories to expected paths.

## Key Features

### 50+ PDF Tools
Merge, split, rotate, compress, convert, OCR, watermark, sign, redact, and more—all in one application.

### REST API
Full API access for automation. Every UI operation is available via API endpoints with Swagger documentation.

### Privacy-First
All document processing happens on your server. No files are sent to external services.

### Built-in Authentication
Native user management with admin and standard user roles. No additional auth proxy required.

### Multi-Language
Interface available in 40+ languages with configurable default locale.

### OCR Support
Built-in Tesseract OCR for extracting text from scanned documents. Download additional language packs via the admin panel.

## Why Deploy Stirling-PDF on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Stirling-PDF on Railway, you get a fully managed PDF processing platform with authentication, persistent storage, and automatic deployments—all configured and ready to use. Host your servers, databases, AI agents, and more on Railway.
