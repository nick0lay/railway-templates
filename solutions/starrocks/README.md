# StarRocks

Deploy StarRocks — an MPP analytical database and ClickHouse alternative — on Railway, with a web UI, MySQL-protocol access, and HTTP data ingestion.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/starrocks?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Overview

This template deploys a single-service stack:

- **StarRocks**: A massively parallel analytical database with columnar storage, vectorized execution, and a cost-based optimizer. It speaks the **MySQL wire protocol**, so `mysql`, DBeaver, and most BI tools connect without any special driver.

The service runs the official all-in-one image, which packages the Frontend (FE, metadata and query planning) and Backend (BE, storage and execution) in one container along with an nginx front proxy.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          Internet                                │
└──────────────┬────────────────────────────────┬─────────────────┘
               │ HTTPS (public domain)          │ TCP Proxy (manual)
               ▼                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    StarRocks (Public)                            │
│                                                                  │
│   feproxy (nginx) → Railway PORT                                 │
│     └─► FE HTTP :8030 — web UI, REST API, Stream Load            │
│                                                                  │
│   FE query port :9030 — MySQL protocol ◄── Railway TCP Proxy     │
│                                                                  │
│   supervisord ─┬─ feservice  (Frontend)                          │
│                ├─ beservice  (Backend)                           │
│                ├─ feproxy    (nginx)                             │
│                └─ director   (registers BE with FE on boot)      │
│   All internal traffic stays on 127.0.0.1                        │
│                                                                  │
│                ┌──────────────────────────────┐                  │
│                │  /var/lib/starrocks Volume   │                  │
│                │    fe-meta/     (metadata)   │                  │
│                │    be-storage/  (table data) │                  │
│                └──────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────────┘
```

FE and BE communicate over `127.0.0.1` inside the container. That is what makes a single-service deployment the right shape here: Railway's private network is IPv6-only, while StarRocks registers backends with IPv4-style `host:port` addresses.

## Quick Start

1. Click the **Deploy on Railway** button above
2. Wait for the first boot — it pulls a ~1.9 GB image and bootstraps the cluster. The service is ready when the logs show `cluster initialization DONE!`
3. Find the public URL in **Settings → Networking** and open it. The FE web UI asks for credentials: user `root`, password from `STARROCKS_PASSWORD`
4. For SQL access, enable **TCP Proxy** on port `9030` in **Settings → Networking**. Railway returns a host and port to point your SQL client at

Step 4 is manual — a template cannot pre-configure TCP Proxy. Without it, port 9030 is not reachable from outside the project and SQL clients will time out.

## Services

| Service | Source | Role |
|---------|--------|------|
| StarRocks | `starrocks/Dockerfile` | FE + BE single-node cluster (public) |

## Connecting

### SQL clients (MySQL protocol)

Use the host and port shown in the TCP Proxy panel — not the HTTPS domain:

```bash
mysql -h <proxy-host> -P <proxy-port> -u root -p
```

```sql
SELECT current_version();
SHOW BACKENDS;
```

### BI tools and libraries

Any MySQL-compatible client works: DBeaver, TablePlus, Metabase, Superset, Grafana's MySQL data source, `mysql-connector-python`, `mysql2`. Point them at the TCP Proxy host/port with user `root` and the `STARROCKS_PASSWORD` value.

### Loading data over HTTP (Stream Load)

Stream Load goes to the public HTTPS domain:

```bash
curl --location-trusted -u root:<password> \
  -H "label:load-001" -H "Expect:100-continue" \
  -H "column_separator:," -H "columns: id, name, score" \
  -T data.csv -XPUT \
  https://<your-domain>/api/<database>/<table>/_stream_load
```

The bundled nginx proxy is what makes this work over a public domain. StarRocks' FE answers a Stream Load request with a 307 redirect to a BE address that is only valid inside the container; the proxy follows it internally so the client never sees it.

## Environment Variables

### User-Configurable

| Variable | Default | Description |
|----------|---------|-------------|
| `STARROCKS_PASSWORD` | `${{secret(32)}}` | Password for the `root` account. Railway generates it at install time — read it any time from the **Variables** tab. Applied on first boot |
| `STARROCKS_IMAGE_TAG` | `latest` | StarRocks image tag (see [Image Tags](#image-tags)) |
| `STARROCKS_BE_MEM_LIMIT` | `80%` | Memory ceiling for the Backend. Accepts a percentage (`80%`) or an absolute size (`4G`) |

### Auto-Configured (Do Not Change)

| Variable | Value | Description |
|----------|-------|-------------|
| `PORT` | Railway-assigned | The entrypoint binds the nginx proxy to this port so the FE web UI, REST API, and Stream Load are reachable on the public domain. Overriding it with a port the proxy is not listening on breaks all public HTTP access |

`MYSQL_PWD` is derived inside the container from `STARROCKS_PASSWORD` so the image's own bootstrap client can authenticate after the password is set. It is not a Railway variable and should not be added as one.

## Volume

| Service | Mount Path | Purpose |
|---------|------------|---------|
| StarRocks | `/var/lib/starrocks` | `fe-meta/` (catalog metadata), `be-storage/` (table data), `.root_password_set` (marker recording that the password has been applied) |

The image keeps FE metadata and BE storage inside its own install directory, which cannot be a Railway mount point — mounting there would hide the StarRocks binaries. The entrypoint symlinks both directories into the volume instead. Data persists across redeployments.

If you mount the volume somewhere other than `/var/lib/starrocks`, set `STARROCKS_DATA_DIR` to the same path so the symlinks follow it.

## Image Tags

The `STARROCKS_IMAGE_TAG` variable controls the StarRocks version:

| Tag | Description |
|-----|-------------|
| `latest` | Newest release line (recommended) |
| `3.5-latest` | LTS release line |
| `4.0-latest`, `4.1-latest` | Latest patch within a release line |
| `4.1.3`, `3.5.20` | Pinned versions |

Changing the tag triggers a rebuild. Downgrading across major versions against an existing volume is not supported by StarRocks — the FE refuses to start on metadata written by a newer release.

## Testing the Deployment

### Health check

```bash
curl https://<your-domain>/api/health
# {"online_backend_num":1,"total_backend_num":1,"status":"OK"}
```

### Cluster state

```sql
SELECT current_version();
SHOW BACKENDS\G   -- one backend, Alive: true
```

### Ingest round-trip

```sql
CREATE DATABASE IF NOT EXISTS demo;
CREATE TABLE demo.events (id INT, name VARCHAR(32), score INT)
  ENGINE=OLAP DUPLICATE KEY(id) DISTRIBUTED BY HASH(id) BUCKETS 1
  PROPERTIES ('replication_num' = '1');
```

```bash
printf '1,alpha,10\n2,beta,20\n' > example.csv
curl --location-trusted -u root:<password> \
  -H "label:test-1" -H "Expect:100-continue" \
  -H "column_separator:," -H "columns: id, name, score" \
  -T example.csv -XPUT \
  https://<your-domain>/api/demo/events/_stream_load
# "Status": "Success", "NumberLoadedRows": 2
```

```sql
SELECT count(*) FROM demo.events;  -- 2
```

## Troubleshooting

### Service restarts in a loop shortly after boot

Usually the Backend running out of memory. Lower `STARROCKS_BE_MEM_LIMIT` (for example to `70%` or an absolute `4G`), or increase the service's memory in Railway. StarRocks needs roughly 4 GB to run comfortably.

### `ERROR 1045 (28000): Access denied` after changing `STARROCKS_PASSWORD`

The password is applied to the `root` account exactly once, tracked by `.root_password_set` on the volume. Editing the variable afterwards changes what the container authenticates *with*, not what the account expects. To rotate it: connect with the current password, run

```sql
SET PASSWORD FOR 'root'@'%' = PASSWORD('new-password');
```

then update `STARROCKS_PASSWORD` to match and redeploy.

### Cannot connect on port 9030

TCP Proxy is not enabled. Add it in **Settings → Networking** with target port `9030`, and connect to the host/port Railway shows there — not the HTTPS domain.

### Public URL returns 401

Expected. The FE web UI requires credentials: user `root`, password from `STARROCKS_PASSWORD`.

### Data lost after redeploy

Check that a volume is mounted at `/var/lib/starrocks` in **Settings → Volumes**. Without it, FE metadata and BE storage live in the container's writable layer and are discarded on every deploy.

### `FE service hostname mismatch detected` in the logs

Should not occur on Railway. The image pins the FE to `127.0.0.1`, which makes the check short-circuit, so changing container hostnames across deploys do not invalidate persisted metadata. If it does appear, the volume holds metadata from a differently-configured StarRocks instance.

### First boot takes several minutes

Normal. The image is ~1.9 GB and cluster bootstrap registers the BE with the FE before the database accepts connections. Watch for `cluster initialization DONE!` in the deploy logs.

## Limitations

- **Single node.** One FE and one BE in one container. Scale vertically by increasing the service's resources; there is no high availability or horizontal scaling in this template.
- **Shared-nothing only.** `RUN_MODE=shared_data`, which separates storage from compute using S3-compatible object storage, is not configured here and needs its own storage volume setup.

## Resources

- [StarRocks Documentation](https://docs.starrocks.io/)
- [StarRocks GitHub](https://github.com/StarRocks/StarRocks)
- [All-in-one image HOWTO](https://github.com/StarRocks/starrocks/blob/main/docker/dockerfiles/allin1/allin1-HOWTO.md)
- [Docker Hub tags](https://hub.docker.com/r/starrocks/allin1-ubuntu/tags)
- [Stream Load reference](https://docs.starrocks.io/docs/loading/StreamLoad/)
