# QuestDB Railway Template

## Template Overview

# Deploy and Host QuestDB on Railway

QuestDB is an open-source time-series database designed for fast ingestion and SQL queries over time-series data. It supports millions of rows per second ingestion via InfluxDB Line Protocol and delivers sub-second query performance on billions of rows — with a built-in web console for immediate SQL access.

## About Hosting QuestDB

This template deploys a production-ready QuestDB instance:

- **Built-in Web Console**: SQL editor with autocomplete, schema browser, and chart visualization — no extra UI service needed
- **Multi-Protocol Access**: PostgreSQL wire protocol (port 8812), InfluxDB Line Protocol (port 9009), and REST API — all from a single container
- **Persistent Storage**: Railway volume for database files and WAL (write-ahead log)
- **High Performance**: Columnar storage with SIMD-optimized queries for time-series analytics

## Getting Started After Deployment

### Accessing the Web Console

After deployment, click on the **QuestDB** service to find your URL:

1. **Deployments Tab**: The URL is displayed directly under the service name
2. **Settings > Networking**: Go to Settings tab → scroll to Networking → find Public Networking

Open the URL to access QuestDB's built-in web console — start writing SQL queries immediately.

### QuestDB Credentials

The PostgreSQL wire protocol password is auto-generated on deploy. To find it:

1. Open your Railway project dashboard
2. Click on the **QuestDB** service
3. Go to the **Variables** tab
4. Find `QDB_PG_PASSWORD` — click the eye icon to reveal

### Connecting from Your Application

Use any PostgreSQL client to connect via Railway's internal network:

```
Host: questdb.railway.internal
Port: 8812
User: admin
Password: (from QDB_PG_PASSWORD variable)
Database: qdb
```

### Ingesting Time-Series Data

Send data via InfluxDB Line Protocol from other Railway services:

```
Host: questdb.railway.internal
Port: 9009
```

## Common Use Cases

- IoT sensor data collection and real-time dashboards
- Application metrics and performance monitoring
- Financial market data analysis with microsecond precision
- Log analytics with fast full-text search over structured data
- Fleet tracking and geospatial time-series queries
- DevOps monitoring with Telegraf, Prometheus, or Grafana integration
- Clickstream and user behavior analytics at scale

## Dependencies for QuestDB Hosting

- Docker (runs as a single container)

### Deployment Dependencies

- [QuestDB Docker Image](https://hub.docker.com/r/questdb/questdb)

### Services

| Service | Source | Description |
|---------|--------|-------------|
| QuestDB | Custom Dockerfile | Time-series database with built-in web console (public) |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `QDB_PG_PASSWORD` | PostgreSQL wire protocol password (`${{secret(32)}}` auto-generates) |
| `QDB_PG_USER` | PostgreSQL wire protocol username (default: `admin`) |
| `QDB_HTTP_USER` | HTTP basic auth username for web console (optional) |
| `QDB_HTTP_PASSWORD` | HTTP basic auth password for web console (optional) |
| `QUESTDB_IMAGE_TAG` | Docker image tag for version control (default: `latest`) |

### Volume

| Service | Mount Path | Purpose |
|---------|------------|---------|
| QuestDB | `/var/lib/questdb` | Database files, WAL, configuration, and logs |

## Key Features

### Built-in Web Console
QuestDB includes a full-featured SQL editor with syntax highlighting, autocomplete, schema browsing, and chart visualization — accessible from your browser without deploying a separate UI service.

### Multi-Protocol Ingestion
Ingest data via InfluxDB Line Protocol (ILP) at millions of rows per second, query with standard SQL over PostgreSQL wire protocol, or use the REST API — all from a single deployment.

### Time-Series Optimized
Purpose-built columnar storage with SIMD-accelerated query engine. Designated timestamp columns, time-based partitioning, and specialized SQL extensions (`SAMPLE BY`, `LATEST ON`, `ASOF JOIN`) for time-series analytics.

### PostgreSQL Compatible
Connect with any PostgreSQL client, ORM, or driver. Works with psql, pgAdmin, DBeaver, and application frameworks like SQLAlchemy, JDBC, and node-postgres.

### Persistent Storage
Railway volume ensures database files and WAL survive redeployments. Your data persists across container restarts and updates.

## Why Deploy QuestDB on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying QuestDB on Railway, you get a high-performance time-series database with a built-in web console, multi-protocol access, and persistent storage — all configured and ready to use. Host your servers, databases, AI agents, and more on Railway.
