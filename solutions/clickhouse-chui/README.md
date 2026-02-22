# ClickHouse + CH-UI

Deploy ClickHouse OLAP database with CH-UI web interface for SQL editing and database exploration.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/clickhouse-ch-ui-1?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Overview

This template deploys a two-service stack:

- **ClickHouse**: Column-oriented OLAP database for real-time analytics, processing billions of rows per second
- **CH-UI**: Modern web-based SQL editor and database explorer connected to ClickHouse over Railway's private network

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          Internet                                │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                       CH-UI (Public)                             │
│                       Port 3488                                  │
│                       SQL Editor + Database Explorer              │
└───────────────────────────────┬─────────────────────────────────┘
                                │ http://clickhouse.railway.internal:PORT
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     ClickHouse (Private)                         │
│                     Railway-assigned PORT (HTTP)                  │
│                     OLAP Database Engine                          │
│                                                                  │
│                ┌──────────────────────────────┐                  │
│                │  /var/lib/clickhouse Volume   │                  │
│                │  Database files & metadata    │                  │
│                └──────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

1. Click the **Deploy on Railway** button above
2. Set `CLICKHOUSE_PASSWORD` (or use the auto-generated one)
3. Wait for both services to deploy
4. Find the CH-UI public URL in **Settings > Networking**
5. Open CH-UI — the ClickHouse connection is pre-configured as "Railway ClickHouse"

## Services

| Service | Source | Description |
|---------|--------|-------------|
| ClickHouse | `clickhouse/Dockerfile` | OLAP database engine (private) |
| CH-UI | `ghcr.io/caioricciuti/ch-ui:latest` | Web SQL editor and database explorer (public) |

## Accessing CH-UI After Deployment

After deployment, click on the **CH-UI** service to find your URL:

1. **Deployments Tab**: The URL is displayed directly under the service name
2. **Settings > Networking**: Go to Settings tab → scroll to Networking → find Public Networking

CH-UI opens with a pre-configured connection named "Railway ClickHouse" pointing to the internal ClickHouse instance.

## Environment Variables

### ClickHouse — User-Configurable

| Variable | Default | Description |
|----------|---------|-------------|
| `CLICKHOUSE_PASSWORD` | `${{secret(32)}}` | Database password (auto-generated) |
| `CLICKHOUSE_USER` | `default` | Database username |
| `CLICKHOUSE_IMAGE_TAG` | `latest` | ClickHouse Docker image tag (see [Image Tags](#image-tags)) |
| `CLICKHOUSE_DB` | - | Optional: database to create on startup |
| `CLICKHOUSE_ACCESS_MANAGEMENT` | `0` | Enable SQL-driven access management (`1` to enable) |

### CH-UI — User-Configurable

| Variable | Default | Description |
|----------|---------|-------------|
| `CONNECTION_NAME` | `Railway ClickHouse` | Display name for the ClickHouse connection in CH-UI |

### Auto-Configured (Do Not Change)

| Variable | Service | Value | Description |
|----------|---------|-------|-------------|
| `CLICKHOUSE_URL` | CH-UI | `http://${{ClickHouse.RAILWAY_PRIVATE_DOMAIN}}:${{ClickHouse.PORT}}` | Internal connection to ClickHouse. Railway assigns the PORT dynamically. Changing breaks CH-UI connectivity. |

## Volume

| Service | Mount Path | Purpose |
|---------|------------|---------|
| ClickHouse | `/var/lib/clickhouse` | Database files, metadata, and table data |

Data persists across redeployments.

## Image Tags

The `CLICKHOUSE_IMAGE_TAG` variable controls the ClickHouse version:

| Tag | Description |
|-----|-------------|
| `latest` | Latest stable release (recommended) |
| `25.7.4.11` | Specific version |
| `25.7.4.11-alpine` | Alpine variant (smaller image) |
| `25.7` | Latest patch in a release branch |
| `head` | Development build (not for production) |

## Testing the Deployment

### Health Check

```bash
curl "https://your-clickhouse-url.railway.app/ping"
# Expected: Ok.
```

### Direct Query (if ClickHouse has a public domain)

```bash
curl -u "default:your_password" \
  "https://your-clickhouse-url.railway.app/" \
  -d "SELECT version()"
```

### Via CH-UI

1. Open the CH-UI public URL
2. The "Railway ClickHouse" connection should be available
3. Run `SELECT version()` in the SQL editor

## Troubleshooting

### CH-UI cannot connect to ClickHouse

1. Verify both services are running in the Railway dashboard
2. Check that `CLICKHOUSE_URL` in the CH-UI service points to the correct internal domain
3. Ensure ClickHouse health check is passing (check Deployments tab for green status)

### 502 Bad Gateway on ClickHouse

Ensure the `network.xml` configuration is properly applied. The custom Dockerfile copies this file to bind ClickHouse to `0.0.0.0` and use Railway's PORT variable.

### ClickHouse stderr "error" messages

ClickHouse outputs startup messages to stderr, which Railway may display as errors. This is normal — check the actual message content before assuming a problem.

### Data not persisting

Verify the `/var/lib/clickhouse` volume is mounted on the ClickHouse service in **Settings > Volumes**.

## Resources

- [ClickHouse Documentation](https://clickhouse.com/docs)
- [ClickHouse GitHub](https://github.com/ClickHouse/ClickHouse)
- [CH-UI GitHub](https://github.com/caioricciuti/ch-ui)
- [ClickHouse Docker Hub](https://hub.docker.com/r/clickhouse/clickhouse-server)
