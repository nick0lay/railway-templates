# BentoPDF + Auth Railway Template

## Template Overview

# Deploy and Host BentoPDF + Auth on Railway

BentoPDF is a powerful, privacy-first PDF toolkit that runs entirely in your browser. It offers 50+ tools for merging, splitting, compressing, editing, and converting PDFs without uploading files to external servers. This template adds Caddy-based password authentication to protect your instance.

## About Hosting BentoPDF + Auth

This template deploys two services: BentoPDF as the core PDF processing application and Caddy as a reverse proxy with HTTP Basic Authentication. BentoPDF runs client-side, meaning all PDF operations happen in users' browsers—no documents are uploaded or stored on the server. The Caddy proxy intercepts all incoming requests and requires valid credentials before granting access, making it ideal for teams or organizations that need a shared, protected PDF toolkit.

## Getting Started After Deployment

### Finding Your Public URL

After deployment, click on the **Caddy** service (not BentoPDF) to find your URL:

1. **Deployments Tab**: The URL is displayed directly under the service name
2. **Settings > Networking**: Go to Settings tab → scroll to Networking → find Public Networking

**Note**: Only the Caddy service has a public URL. BentoPDF is internal-only and accessed through Caddy.

### Finding Your Login Credentials

To find your username and password:

1. Open your Railway project dashboard
2. Click on the **Caddy** service
3. Go to the **Variables** tab
4. Find `USERNAME` and `PASSWORD` - click the eye icon to reveal or use "Copy value"

A secure 32-character password is auto-generated on deploy. You can change both `USERNAME` and `PASSWORD` in the Variables tab if needed.

## Common Use Cases

- Self-hosted PDF toolkit for teams needing merge, split, compress, and convert capabilities
- Private document processing where files must never leave the browser
- Internal company tool for PDF manipulation with access control
- Converting images, Word, Excel, and PowerPoint files to PDF securely
- Adding watermarks, page numbers, or annotations to PDFs without cloud services

## Dependencies for BentoPDF + Auth Hosting

- Docker (BentoPDF runs as a container image)
- Caddy reverse proxy (handles authentication)

### Deployment Dependencies

- [BentoPDF GitHub Repository](https://github.com/alam00000/bentopdf)
- [BentoPDF Docker Image](https://hub.docker.com/r/bentopdf/bentopdf)
- [Caddy Password Auth](https://github.com/iliab1/caddy-password-auth)

### Environment Variables

| Variable | Description |
|----------|-------------|
| `USERNAME` | Login username to access BentoPDF |
| `PASSWORD` | Login password to access BentoPDF |
| `BASIC_AUTH` | Combined credentials in `username:password` format (auto-generated) |
| `ORIGIN` | Internal URL of BentoPDF service (auto-configured) |

## Why Deploy BentoPDF + Auth on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying BentoPDF + Auth on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
