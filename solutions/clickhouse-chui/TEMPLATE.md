# ClickHouse + CH-UI Railway Template

## Template Overview

# Deploy and Host ClickHouse with CH-UI on Railway

ClickHouse is an open-source column-oriented database for real-time analytics, processing billions of rows per second with 100-1000x faster query performance than traditional databases. This template pairs it with CH-UI, a modern web-based SQL editor and database explorer, connected over Railway's private network.

## About Hosting ClickHouse + CH-UI

This template deploys a two-service stack:

- **ClickHouse**: High-performance OLAP database engine for analytical workloads
- **CH-UI**: Web-based SQL editor with multi-tab queries, database browsing, and query persistence
- **Private Networking**: CH-UI connects to ClickHouse over Railway's internal network — no database exposed to the internet
- **Persistent Storage**: Railway volume for database files and metadata

## Getting Started After Deployment

### Accessing CH-UI

After deployment, click on the **CH-UI** service to find your URL:

1. **Deployments Tab**: The URL is displayed directly under the service name
2. **Settings > Networking**: Go to Settings tab → scroll to Networking → find Public Networking

### Using CH-UI

CH-UI comes pre-configured with a connection named "Railway ClickHouse" pointing to your ClickHouse instance. Open CH-UI and start writing SQL queries immediately.

### ClickHouse Credentials

The ClickHouse password is auto-generated on deploy. To find it:

1. Open your Railway project dashboard
2. Click on the **ClickHouse** service
3. Go to the **Variables** tab
4. Find `CLICKHOUSE_PASSWORD` — click the eye icon to reveal

### Direct ClickHouse Access

If you need direct API access to ClickHouse (outside of CH-UI), you can add a public domain to the ClickHouse service in **Settings > Networking**. Use HTTP basic auth with your configured credentials.

## Common Use Cases

- Real-time analytics dashboards processing billions of events
- Log and event storage with fast aggregation queries
- Business intelligence with sub-second query responses on large datasets
- Time-series analysis for metrics, IoT data, and monitoring
- Data warehousing replacing traditional RDBMS for analytical workloads
- Clickstream and user behavior analysis
- Ad-tech analytics with high-cardinality dimensions

## Dependencies for ClickHouse + CH-UI Hosting

- Docker (both services run as containers)

### Deployment Dependencies

- [ClickHouse Docker Image](https://hub.docker.com/r/clickhouse/clickhouse-server)
- [CH-UI Docker Image](https://github.com/caioricciuti/ch-ui/pkgs/container/ch-ui)

### Services

| Service | Source | Description |
|---------|--------|-------------|
| ClickHouse | Custom Dockerfile | OLAP database engine (private) |
| CH-UI | `ghcr.io/caioricciuti/ch-ui:latest` | Web SQL editor and database explorer (public) |

### Environment Variables

#### ClickHouse

| Variable | Description |
|----------|-------------|
| `CLICKHOUSE_PASSWORD` | Database password (`${{secret(32)}}` auto-generates) |
| `CLICKHOUSE_USER` | Database username (default: `default`) |
| `CLICKHOUSE_IMAGE_TAG` | Docker image tag for version control (default: `latest`) |
| `CLICKHOUSE_DB` | Optional database to create on startup |
| `CLICKHOUSE_ACCESS_MANAGEMENT` | SQL-driven access management (default: `0`) |

#### CH-UI

| Variable | Description |
|----------|-------------|
| `CLICKHOUSE_URL` | Internal connection URL using Railway-assigned port (auto-configured) |
| `CONNECTION_NAME` | Display name for the connection (default: `Railway ClickHouse`) |

### Volume

| Service | Mount Path | Purpose |
|---------|------------|---------|
| ClickHouse | `/var/lib/clickhouse` | Database files, metadata, and table data |

## Key Features

### Real-Time Analytics
ClickHouse processes billions of rows per second with columnar storage and vectorized query execution. Ideal for OLAP workloads where traditional databases struggle.

### Web SQL Editor
CH-UI provides a multi-tab SQL editor with syntax highlighting, database/table browsing, and query persistence — all accessible from your browser.

### Private Networking
ClickHouse runs on Railway's private network, accessible only to CH-UI internally. No database port exposed to the internet by default.

### Version Flexibility
Switch ClickHouse versions without code changes by updating the `CLICKHOUSE_IMAGE_TAG` variable. Supports latest stable, specific versions, and Alpine variants.

### Persistent Storage
Railway volume ensures database files survive redeployments. Your data persists across container restarts and updates.

## Why Deploy ClickHouse + CH-UI on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying ClickHouse + CH-UI on Railway, you get a fully managed analytical database with a web interface, private networking, and persistent storage — all configured and ready to use. Host your servers, databases, AI agents, and more on Railway.
