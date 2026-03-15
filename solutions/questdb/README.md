# QuestDB

Deploy QuestDB time-series database with built-in web console on Railway.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/AdmJg1?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Overview

This template deploys a single-service stack:

- **QuestDB**: High-performance time-series database with built-in web console, REST API, PostgreSQL wire protocol, and InfluxDB Line Protocol (ILP) ingestion

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          Internet                                │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      QuestDB (Public)                            │
│                                                                  │
│   Railway PORT → Web Console + REST API (HTTP)                   │
│   Port 8812   → PostgreSQL Wire Protocol (internal)              │
│   Port 9009   → InfluxDB Line Protocol (internal)                │
│   Port 9003   → Health Check (internal)                          │
│                                                                  │
│                ┌──────────────────────────────┐                  │
│                │  /var/lib/questdb Volume     │                  │
│                │  Database files & WAL        │                  │
│                └──────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

1. Click the **Deploy on Railway** button above
2. Set `QDB_PG_PASSWORD` and optionally `QDB_HTTP_PASSWORD` / `QDB_HTTP_USER`
3. Wait for the service to deploy
4. Find the public URL in **Settings > Networking**
5. Open the URL — the QuestDB Web Console loads immediately

## Services

| Service | Source | Description |
|---------|--------|-------------|
| QuestDB | `questdb/Dockerfile` | Time-series database with web console (public) |

## Accessing QuestDB After Deployment

### Web Console

Open the public URL from **Settings > Networking**. The built-in web console provides:

- SQL editor with syntax highlighting and autocomplete
- Table schema browser
- Query result visualization with charts
- Import CSV/JSON data via drag-and-drop

### PostgreSQL Wire Protocol

Connect from your application using any PostgreSQL client on the internal network:

```
Host: questdb.railway.internal
Port: 8812
User: admin (or QDB_PG_USER value)
Password: your QDB_PG_PASSWORD value
Database: qdb
```

### InfluxDB Line Protocol (ILP)

Send time-series data via ILP on the internal network:

```
Host: questdb.railway.internal
Port: 9009
```

### REST API

Query via HTTP from the public URL:

```bash
curl -G "https://your-questdb-url.railway.app/exec" \
  --data-urlencode "query=SELECT * FROM my_table LIMIT 10"
```

## Environment Variables

### User-Configurable

| Variable | Default | Description |
|----------|---------|-------------|
| `QDB_PG_PASSWORD` | `${{secret(32)}}` | PostgreSQL wire protocol password (auto-generated) |
| `QDB_PG_USER` | `admin` | PostgreSQL wire protocol username |
| `QDB_HTTP_USER` | - | HTTP basic auth username for web console (disabled if empty) |
| `QDB_HTTP_PASSWORD` | - | HTTP basic auth password for web console (disabled if empty) |
| `QUESTDB_IMAGE_TAG` | `latest` | QuestDB Docker image tag (see [Image Tags](#image-tags)) |

### Auto-Configured (Do Not Change)

| Variable | Value | Description |
|----------|-------|-------------|
| `QDB_HTTP_NET_BIND_TO` | `0.0.0.0:$PORT` | Set by entrypoint script. Maps Railway's dynamic PORT to QuestDB's HTTP server. Changing breaks public access. |

## Protocols and Ports

| Protocol | Port | Access | Use Case |
|----------|------|--------|----------|
| HTTP (Console + REST) | Railway PORT | Public | Web console, SQL queries, CSV import |
| PostgreSQL Wire | 8812 | Internal | Application queries via any PG client |
| InfluxDB Line Protocol | 9009 | Internal | High-throughput time-series ingestion |
| Health Check | 9003 | Internal | `/status` endpoint for monitoring |

## Volume

| Service | Mount Path | Purpose |
|---------|------------|---------|
| QuestDB | `/var/lib/questdb` | Database files, WAL, configuration, and logs |

Data persists across redeployments.

## Image Tags

The `QUESTDB_IMAGE_TAG` variable controls the QuestDB version:

| Tag | Description |
|-----|-------------|
| `latest` | Latest stable release (recommended) |
| `8.3.3` | Specific version |
| `8.3` | Latest patch in a release branch |

## Testing the Deployment

### Health Check

```bash
# Via internal health endpoint (from another Railway service)
curl "http://questdb.railway.internal:9003/status"
```

### Web Console Query

1. Open the QuestDB public URL
2. Run in the SQL editor:
   ```sql
   SELECT version();
   ```

### REST API Query

```bash
curl -G "https://your-questdb-url.railway.app/exec" \
  --data-urlencode "query=SELECT version()"
```

### PostgreSQL Wire Protocol

```bash
psql -h questdb.railway.internal -p 8812 -U admin -d qdb
```

## Troubleshooting

### Web console not loading

1. Verify the service is running in the Railway dashboard
2. Check that a public domain is assigned in **Settings > Networking**
3. Check deployment logs for startup errors

### Cannot connect via PostgreSQL wire

1. Ensure you're connecting from another Railway service on the same project (port 8812 is internal)
2. Verify credentials match `QDB_PG_USER` and `QDB_PG_PASSWORD`
3. Use `questdb.railway.internal` as the hostname

### Data not persisting

Verify the `/var/lib/questdb` volume is mounted on the QuestDB service in **Settings > Volumes**.

### Warning: vm.max_map_count limit is too low

QuestDB uses memory-mapped files and recommends `vm.max_map_count=1048576` (default is 65530). The entrypoint script attempts to set this automatically via `sysctl`, but it may not have sufficient privileges on Railway. If the warning persists in the web console, it can be safely ignored for light workloads — QuestDB will still function correctly, but heavy workloads with many tables may encounter out-of-memory exceptions.

### Out of memory errors

QuestDB recommends 8-16GB RAM for production workloads. Scale the service in **Settings > Resources**.

## Resources

- [QuestDB Documentation](https://questdb.io/docs/)
- [QuestDB GitHub](https://github.com/questdb/questdb)
- [QuestDB Docker Hub](https://hub.docker.com/r/questdb/questdb)
- [SQL Reference](https://questdb.io/docs/reference/sql/overview/)
- [InfluxDB Line Protocol Guide](https://questdb.io/docs/reference/api/ilp/overview/)
