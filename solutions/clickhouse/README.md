# ClickHouse

Deploy a single ClickHouse server on Railway, with persistent storage and ready-made connection URLs.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/clickhouse-1?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Overview

- **ClickHouse**: column-oriented OLAP database, from the official `clickhouse/clickhouse-server` image, pinned to a tested version
- **Volume** at `/var/lib/clickhouse`, so data survives redeploys and restarts
- HTTP interface on port 8123, reachable over the public domain (HTTPS) and the private network
- High-volume internal log tables disabled, so they don't fill the volume

For a web SQL editor on top, see [ClickHouse + CH-UI](../clickhouse-chui/).

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                        Internet                          │
└─────────────────────────────┬────────────────────────────┘
                              │ HTTPS (public domain)
                              ▼
┌──────────────────────────────────────────────────────────┐
│                  ClickHouse (public)                     │
│                                                          │
│   PORT=8123 → HTTP interface (queries, /ping)            │
│   Private network: clickhouse.railway.internal:8123      │
│                                                          │
│        ┌──────────────────────────────────┐              │
│        │  /var/lib/clickhouse  (volume)   │              │
│        └──────────────────────────────────┘              │
└──────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| ClickHouse | `clickhouse/Dockerfile` | OLAP database, HTTP interface (public) |

## Environment Variables

### User-Configurable

| Variable | Default | Description |
|----------|---------|-------------|
| `CLICKHOUSE_IMAGE_TAG` | `25.8` | Image tag from [Docker Hub](https://hub.docker.com/r/clickhouse/clickhouse-server/tags). Empty falls back to `25.8`. Test upgrades on a copy first: downgrading after ClickHouse has written data with a newer version is not supported. |
| `CLICKHOUSE_USER` | `clickhouse` | User created on first start |
| `CLICKHOUSE_PASSWORD` | generated | Password for that user |
| `CLICKHOUSE_DB` | `railway` | Database created on first start |
| `CLICKHOUSE_ACCESS_MANAGEMENT` | `0` | `1` lets the user manage users and grants with SQL |
| `CLICKHOUSE_SKIP_USER_SETUP` | `0` | `1` skips user setup. The default user then has no password; don't use with a public domain |

User, password and database are applied on the **first** start only. To change them later, use SQL.

### Auto-Configured (Do Not Change)

| Variable | Value | Why |
|----------|-------|-----|
| `PORT` | `8123` | ClickHouse binds its HTTP interface to `PORT`, and Railway routes the public domain and healthcheck to it |
| `CLICKHOUSE_URL` | `http://user:pass@${{RAILWAY_PRIVATE_DOMAIN}}:8123/db` | Use from other services in the project: `${{ClickHouse.CLICKHOUSE_URL}}` |
| `CLICKHOUSE_PUBLIC_URL` | `https://user:pass@${{RAILWAY_PUBLIC_DOMAIN}}:443/db` | Use from outside Railway |

## Connecting

```bash
# Health
curl https://<your-domain>/ping

# Query over HTTPS
curl -u "clickhouse:<password>" "https://<your-domain>/" --data-binary "SELECT version()"

# clickhouse-client
clickhouse-client --host <your-domain> --port 443 --secure --user clickhouse --password <password>
```

From another service in the same project, use `${{ClickHouse.CLICKHOUSE_URL}}`.

## Files

| File | Purpose |
|------|---------|
| `clickhouse/Dockerfile` | Official image + Railway config |
| `clickhouse/network.xml` | Listen on IPv6 and IPv4 (`::`), HTTP port from `PORT` |
| `clickhouse/system-logs.xml` | Disable high-volume system log tables; keep `query_log`, `part_log`, `error_log` for 7 days |
| `clickhouse/railway.json` | Dockerfile build, `/ping` healthcheck, restart on failure |

## Troubleshooting

- **Healthcheck fails**: make sure `PORT` is `8123`.
- **`Authentication failed`**: user and password are only applied on the first start. If you changed the variables later, the old credentials still apply.
- **Out of memory**: ClickHouse uses about 1 GiB when idle. Give the service at least 2 GB for real workloads.
- **Data gone after redeploy**: check the volume is attached at `/var/lib/clickhouse` in the service settings.

## History

Until November 2026 this template was built from a fork of the ClickHouse source repository (`nick0lay/ClickHouse`, branch `railway-deployment`) with no volume. Existing deployments still point there. That branch is kept unchanged so they keep working.
