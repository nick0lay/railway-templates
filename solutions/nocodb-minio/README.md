# NocoDB Complete Stack

A production-ready NocoDB deployment with PostgreSQL, Redis caching, and MinIO for persistent file storage.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/nocodb-minio-console-and-storage?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Overview

This solution combines:
- **NocoDB**: Open-source Airtable alternative with spreadsheet UI for databases
- **PostgreSQL**: Primary database for metadata and application data
- **Redis**: Caching layer for improved performance
- **MinIO**: S3-compatible object storage for file attachments

Unlike basic NocoDB deployments, this template includes MinIO to ensure file attachments persist across redeployments.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          Internet                                │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      NocoDB (Public)                             │
│                      Port 8080                                   │
│                      Built-in Authentication                     │
└───────────┬───────────────────┬───────────────────┬─────────────┘
            │                   │                   │
            ▼                   ▼                   ▼
┌───────────────────┐ ┌───────────────────┐ ┌───────────────────┐
│    PostgreSQL     │ │      Redis        │ │      MinIO        │
│    (Private)      │ │    (Private)      │ │    (Private)      │
│    Port 5432      │ │    Port 6379      │ │    Port 9000      │
│                   │ │                   │ │                   │
│  Metadata & Data  │ │  Session Cache    │ │  File Attachments │
└───────────────────┘ └───────────────────┘ └─────────┬─────────┘
                                                      │
                                            ┌─────────▼─────────┐
                                            │   MinIO Init      │
                                            │   (Sidecar)       │
                                            │  Auto-disables    │
                                            └───────────────────┘
```

## Quick Start

1. Click the **Deploy on Railway** button above
2. Wait for all services to deploy
3. Access NocoDB via the generated Railway domain
4. Create your super admin account on first visit

## Accessing Services After Deployment

### Accessing NocoDB

After deployment, click on the **NocoDB** service to find your URL:

1. **Deployments Tab**: The URL is displayed directly under the service name
2. **Settings > Networking**: Go to Settings tab → scroll to Networking → find Public Networking

On first visit, you'll be prompted to create a super admin account using `NC_ADMIN_EMAIL` and `NC_ADMIN_PASSWORD`.

### Accessing MinIO Console

The MinIO Console allows you to manage buckets, view files, and monitor storage. Click on the **Console** service:

1. **Deployments Tab**: The URL is displayed directly under the service name
2. **Settings > Networking**: Go to Settings tab → scroll to Networking → find Public Networking

**Login credentials:**
- **Username**: Find `MINIO_ROOT_USER` in the MinIO service Variables tab
- **Password**: Find `MINIO_ROOT_PASSWORD` in the MinIO service Variables tab

**Note**: The Console service is separate from the MinIO API service. NocoDB connects to MinIO internally via the private network, while the Console provides a web UI for administration.

## Environment Variables

### NocoDB Service

#### User-Configurable Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NC_ADMIN_EMAIL` | - | Super admin email (set on first run) |
| `NC_ADMIN_PASSWORD` | Auto-generated (32 chars) | Super admin password. A secure random password is generated on deploy. You can change it to your own (minimum 8 characters). |
| `NC_PUBLIC_URL` | Auto-detected | Public URL of your NocoDB instance |

#### Auto-Configured (Do Not Change)

| Variable | Description |
|----------|-------------|
| `NC_DB` | PostgreSQL connection string. Routes to PostgreSQL via Railway's private network. |
| `NC_REDIS_URL` | Redis connection string for caching. |
| `NC_S3_BUCKET_NAME` | MinIO bucket name for attachments. |
| `NC_S3_REGION` | S3 region (set to `us-east-1` for MinIO compatibility). |
| `NC_S3_ENDPOINT` | MinIO internal endpoint URL. |
| `NC_S3_ACCESS_KEY` | MinIO access key for authentication. |
| `NC_S3_ACCESS_SECRET` | MinIO secret key for authentication. |
| `NC_S3_FORCE_PATH_STYLE` | Must be `true` for MinIO compatibility. Uses path-style URLs instead of virtual-hosted. |
| `NC_AUTH_JWT_SECRET` | Secret for JWT token generation. Auto-generated. |

### PostgreSQL Service

| Variable | Description |
|----------|-------------|
| `POSTGRES_USER` | Database username |
| `POSTGRES_PASSWORD` | Database password (auto-generated) |
| `POSTGRES_DB` | Database name |

### Redis Service

No configuration required. Uses Railway's Redis plugin defaults.

### MinIO Service

| Variable | Default | Description |
|----------|---------|-------------|
| `MINIO_ROOT_USER` | Auto-generated | MinIO admin username |
| `MINIO_ROOT_PASSWORD` | Auto-generated | MinIO admin password |

### MinIO Init Service (Sidecar)

This service automatically creates required MinIO buckets on deployment and then auto-disables to save resources.

| Variable | Default | Description |
|----------|---------|-------------|
| `MINIO_ENDPOINT` | - | MinIO API endpoint (e.g., `minio.railway.internal:9000`) |
| `MINIO_ACCESS_KEY` | - | MinIO access key (`${{MinIO.MINIO_ROOT_USER}}`) |
| `MINIO_SECRET_KEY` | - | MinIO secret key (`${{MinIO.MINIO_ROOT_PASSWORD}}`) |
| `MINIO_BUCKET` | - | Bucket name to create (e.g., `nocodb`) |
| `IS_ACTIVE` | `true` | Enable/disable the controller |
| `AUTO_DISABLE` | `true` | Auto-disable after successful initialization |
| `CHECK_INTERVAL` | `1` | Minutes between initialization checks |
| `HEALTHY_CYCLES_THRESHOLD` | `3` | Successful cycles before auto-disable |

## Services Included

| Service | Source | Role |
|---------|--------|------|
| NocoDB | `nocodb/nocodb:latest` | Spreadsheet database UI (public) |
| PostgreSQL | Railway Plugin | Primary database (private) |
| Redis | Railway Plugin | Caching layer (private) |
| MinIO | `minio/minio:latest` | S3-compatible file storage (private) |
| MinIO Init | `minio-init/Dockerfile` | Bucket initialization sidecar (auto-disables) |

## User Management

NocoDB includes built-in user management:

- **Super Admin**: First user to access the instance becomes super admin
- **User Signup**: Disabled by default (invite-only)
- **Invitations**: Super admin can invite users via email
- **Workspaces**: Create multiple workspaces with different team members
- **Roles**: Owner, Creator, Editor, Commenter, Viewer

No additional authentication layer (like Caddy) is required.

## File Storage

This template uses MinIO for S3-compatible file storage:

- **Attachments**: Images, documents, and files uploaded to NocoDB tables
- **Persistence**: Files survive container redeployments
- **Private Access**: MinIO is not exposed to the internet; NocoDB manages all file operations

### Why MinIO Instead of Local Storage?

| Local Storage | MinIO Storage |
|---------------|---------------|
| Files lost on redeploy | Files persist permanently |
| Limited by container disk | Scalable object storage |
| No redundancy | Production-grade durability |

## Connecting External Databases

NocoDB can connect to external databases in addition to its internal PostgreSQL:

1. Go to **Integrations** in NocoDB
2. Add a new database connection
3. Supported: MySQL, PostgreSQL, SQL Server, SQLite, MariaDB

The internal PostgreSQL is used for NocoDB metadata. External databases appear as bases you can manage through the spreadsheet UI.

## Security

- PostgreSQL, Redis, and MinIO are not exposed to the internet
- All internal traffic uses Railway's private networking
- NocoDB handles authentication with email/password
- JWT tokens secure API access
- File uploads go through NocoDB (not directly to MinIO)

## Backup Considerations

- **PostgreSQL**: Use `pg_dump` or Railway's backup features
- **MinIO**: Data stored in Railway volume; consider S3 replication for critical data
- **NocoDB metadata**: Stored in PostgreSQL, backed up with database

## Troubleshooting

### Files not persisting after redeploy

Verify MinIO environment variables are correctly set:
- `NC_S3_ENDPOINT` should point to MinIO's internal Railway URL
- `NC_S3_ACCESS_KEY` and `NC_S3_ACCESS_SECRET` must match MinIO credentials

### Cannot connect to database

Check that `NC_DB` connection string uses Railway's internal hostname for PostgreSQL.

### Redis connection errors

Verify `NC_REDIS_URL` points to the correct Redis internal URL.

### MinIO Init not creating buckets

1. Check MinIO Init logs for connection errors
2. Verify `MINIO_ENDPOINT` uses the correct private network hostname
3. Ensure `MINIO_ACCESS_KEY` and `MINIO_SECRET_KEY` match MinIO credentials
4. The service auto-disables after 3 successful cycles; redeploy to re-run

### MinIO Init keeps running

If you want to manually disable the sidecar:

1. Set `IS_ACTIVE=false` in the service variables
2. Or set `AUTO_DISABLE=true` (default) to let it stop automatically

## Resources

- [NocoDB Documentation](https://docs.nocodb.com/)
- [NocoDB GitHub](https://github.com/nocodb/nocodb)
- [NocoDB Environment Variables](https://nocodb.com/docs/self-hosting/environment-variables)
- [MinIO Documentation](https://min.io/docs/minio/container/index.html)
