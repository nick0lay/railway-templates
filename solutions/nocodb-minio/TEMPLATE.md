# NocoDB Complete Stack Railway Template

## Template Overview

# Deploy and Host NocoDB Complete Stack on Railway

NocoDB is a powerful open-source Airtable alternative that turns any database into a smart spreadsheet. This complete stack template includes PostgreSQL for data storage, Redis for caching, and MinIO for persistent file attachments—everything you need for a production-ready deployment.

## About Hosting NocoDB Complete Stack

This template deploys six services: NocoDB as the core application, PostgreSQL for metadata and data storage, Redis for caching and session management, MinIO for S3-compatible file storage, MinIO Console for storage administration, and a MinIO Init sidecar that automatically creates required storage buckets. Unlike basic NocoDB deployments where file attachments can be lost on redeployment, this stack ensures all uploaded files persist permanently in MinIO. NocoDB's built-in authentication handles user management, so no additional auth layer is required.

## Getting Started After Deployment

### Accessing NocoDB

After deployment, click on the **NocoDB** service to find your URL:

1. **Deployments Tab**: The URL is displayed directly under the service name
2. **Settings > Networking**: Go to Settings tab → scroll to Networking → find Public Networking

### Creating Your Admin Account

On first visit, you'll be prompted to create a super admin account using the pre-configured credentials:

1. Navigate to your NocoDB URL
2. Use `NC_ADMIN_EMAIL` and `NC_ADMIN_PASSWORD` from the NocoDB service Variables tab
3. A secure 32-character password is auto-generated on deploy—you can change it to your own (minimum 8 characters)

### Accessing MinIO Console

The MinIO Console provides a web UI to manage buckets, view uploaded files, and monitor storage usage:

1. Click on the **Console** service in your Railway project
2. Find the URL in **Deployments Tab** or **Settings > Networking**
3. Login with `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD` from the MinIO service Variables tab

**Note**: The Console is for administration only. NocoDB connects to MinIO automatically via the private network.

### Inviting Team Members

NocoDB uses invite-only signup by default:

1. Go to **Workspace Settings** → **Members**
2. Click **Invite** and enter email addresses
3. Users receive invitation links to create their accounts

## Common Use Cases

- Team collaboration on structured data without complex database tools
- Project management with custom views (Grid, Kanban, Gallery, Form)
- CRM and customer tracking with relational data
- Inventory management with file attachments and images
- Survey and form collection with automated workflows
- API backend for mobile and web applications
- Replacing Airtable with a self-hosted, privacy-first alternative

## Dependencies for NocoDB Complete Stack Hosting

- Docker (NocoDB, MinIO, MinIO Init run as container images)
- PostgreSQL (Railway plugin for data storage)
- Redis (Railway plugin for caching)

### Deployment Dependencies

- [NocoDB GitHub Repository](https://github.com/nocodb/nocodb)
- [NocoDB Docker Image](https://hub.docker.com/r/nocodb/nocodb)
- [MinIO Docker Image](https://hub.docker.com/r/minio/minio)

### Environment Variables

| Variable | Description |
|----------|-------------|
| `NC_ADMIN_EMAIL` | Super admin email for first login |
| `NC_ADMIN_PASSWORD` | Super admin password (auto-generated 32 chars, changeable) |
| `NC_DB` | PostgreSQL connection string (auto-configured) |
| `NC_REDIS_URL` | Redis connection for caching (auto-configured) |
| `NC_S3_BUCKET_NAME` | MinIO bucket for file attachments |
| `NC_S3_ENDPOINT` | MinIO internal endpoint (auto-configured) |
| `NC_S3_ACCESS_KEY` | MinIO access credentials (auto-configured) |
| `NC_S3_ACCESS_SECRET` | MinIO secret credentials (auto-configured) |
| `NC_S3_FORCE_PATH_STYLE` | Set to `true` for MinIO path-style URLs |
| `NC_AUTH_JWT_SECRET` | JWT secret for authentication (auto-generated) |
| `MINIO_ROOT_USER` | MinIO Console login username (auto-generated) |
| `MINIO_ROOT_PASSWORD` | MinIO Console login password (auto-generated) |

## Why This Template?

### Persistent File Storage

Basic NocoDB deployments store files locally, which means attachments can be lost when containers redeploy. This template includes MinIO with automatic bucket initialization—the MinIO Init sidecar creates required storage buckets on first deployment and then auto-disables to save resources.

### Production-Ready Caching

Redis caching improves performance for teams with concurrent users, faster page loads, and better API response times.

### Complete Data Stack

PostgreSQL provides a robust, production-grade database for your NocoDB metadata and connected data sources.

## Why Deploy NocoDB Complete Stack on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying NocoDB Complete Stack on Railway, you get a fully managed Airtable alternative with persistent storage, caching, and database—all configured and connected automatically. Host your servers, databases, AI agents, and more on Railway.
