# Apache Superset + ClickHouse

Self-hosted [Apache Superset](https://superset.apache.org) on Railway with a [ClickHouse](https://clickhouse.com) database already connected: open-source BI with dashboards, charts, a SQL editor and a semantic layer, on top of the fastest open-source analytics database. This template runs Superset 6.1 with its Celery worker, a Postgres metadata database, Redis and ClickHouse 26.8. The admin account is created at deploy, so nobody can claim your instance, the ClickHouse connection is registered on the first start, all databases are private, and every version is pinned and tested.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/apache-superset-61-clickhouse-268?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
                     You (browser, Superset REST API)
                                  │ HTTPS
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│ Railway project                                                  │
│                                                                  │
│  Superset :8088  public (login required)                         │
│    dashboards, charts, SQL Lab, REST API                         │
│                                                                  │
│  Superset Worker  (Celery + scheduler: async queries, alerts     │
│                    and reports, cache warm-up)                   │
│                                                                  │
│  ClickHouse :8123        Postgres :5432          Redis :6379     │
│  your analytics data     users, dashboards,      caches, query   │
│  volume                  charts; volume          results, queue  │
│  (all private)                                   volume          │
└──────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Superset | `superset/Dockerfile` (`apache/superset:6.1.0` + drivers) | Web UI and REST API (login required) |
| Superset Worker | same image | Celery worker and beat scheduler |
| ClickHouse | `solutions/clickhouse/clickhouse` (`clickhouse/clickhouse-server:26.8`) | Analytics database, registered in Superset as **ClickHouse** (private) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Superset metadata: users, dashboards, charts, saved queries (private) |
| Redis | `redis:8.10` | Caches, SQL Lab results, Celery queue (private) |

## What this template does differently

- **No one can claim your instance.** The admin is created from `ADMIN_USERNAME` and a generated `ADMIN_PASSWORD` before Superset accepts requests. Self-registration is off; you add users in **Settings > List Users**.
- **ClickHouse is connected.** The official Superset image ships without database drivers. Our image adds `clickhouse-connect` and `psycopg2`, and the **ClickHouse** connection is registered on the first start, so SQL Lab and charts work right after deploy.
- **Production setup, not the demo compose.** Postgres for metadata (not SQLite), Redis for caches and query results, a Celery worker with the scheduler, gunicorn behind Railway's HTTPS proxy (`ENABLE_PROXY_FIX`), and a generated `SUPERSET_SECRET_KEY`.
- **Works on Railway's IPv6 private network.** Superset listens on `[::]` (IPv6 and IPv4), and ClickHouse on `::`.
- **Private databases.** ClickHouse, Postgres and Redis have no public domain or TCP proxy.
- **Migrations on every start.** `superset db upgrade` and `superset init` run before the web server starts, so upgrades need no manual step.
- **ClickHouse tuned for a small service.** High-volume internal log tables are off or kept for a few days.
- **Pinned versions.** Superset 6.1.0, clickhouse-connect 0.15.1, ClickHouse 26.8 (LTS), PostgreSQL 18, Redis 8.10.

## After deploy

1. Open the Superset URL and log in with `ADMIN_USERNAME` (`admin`) and the `ADMIN_PASSWORD` variable (Superset service → Variables).
2. Open **SQL Lab**, pick the **ClickHouse** database and run a query, for example:

   ```sql
   CREATE TABLE events (ts DateTime, user_id UInt32, event String) ENGINE = MergeTree ORDER BY ts;
   ```

   DDL and inserts are off by default for the connection. To run them from SQL Lab, edit the connection (**Settings > Database Connections > ClickHouse > Advanced > SQL Lab**) and allow DML. Most data arrives from outside Superset anyway (see below).
3. Create a dataset from a table (**Datasets > + Dataset**), build charts and put them on a dashboard.
4. Change your password in **Settings > Info**.

## Getting data into ClickHouse

ClickHouse is private. Load data from other services in the same Railway project through `CLICKHOUSE_URL` (ClickHouse service → Variables), for example `INSERT ... FORMAT JSONEachRow` over HTTP or a ClickHouse client library. To load data from outside Railway, add a public domain to the ClickHouse service (Settings → Networking); it then answers HTTPS on port 443 with the same user and password.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Superset | `ADMIN_USERNAME` | `admin` | Admin login, created on the first start |
| Superset | `ADMIN_PASSWORD` | generated | Read it after deploy. Applied only when the admin is created; later, change it in Superset |
| Superset | `ADMIN_EMAIL` | `admin@example.com` | Admin email |
| Superset | `CLICKHOUSE_DATABASE_NAME` | `ClickHouse` | Name of the registered connection |
| Superset | `CLICKHOUSE_SQLALCHEMY_URI` | ClickHouse private URL | Registered on the first start if no connection with that name exists. Empty: register nothing |
| Superset | `SERVER_WORKER_AMOUNT` | `1` | Gunicorn processes, about 300 MB of RAM each |
| Superset | `GUNICORN_TIMEOUT` | `120` | Seconds a request (and a synchronous SQL Lab query) may take |
| Superset | `SUPERSET_CONFIG_EXTRA` | empty | Python appended to `superset_config.py` (feature flags, mail, ...). Redeploy Superset and Superset Worker after changing it |
| Superset Worker | `CELERYD_CONCURRENCY` | `2` | Parallel Celery tasks |
| ClickHouse | `CLICKHOUSE_IMAGE_TAG` | `26.8` | ClickHouse version. ClickHouse can't be downgraded |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Superset | `SUPERSET_SECRET_KEY` | generated | Signs sessions and encrypts saved connection passwords. Changing it breaks saved connections |
| Superset, Worker | `SUPERSET_DATABASE_URI`, `REDIS_URL` | from Postgres and Redis | Private network |
| Superset, Worker | `PG_HOST`, `REDIS_HOST`, `CLICKHOUSE_HOST` | private hosts | The start script waits for them |
| Superset, Worker | `SUPERSET_CONFIG_PY`, `SUPERSET_RUN_SH` | config, script | `superset_config.py` and the start script |
| Superset | `SUPERSET_PORT`, `PORT` | `8088` | Web port |
| Superset, Worker | `RAILWAY_RUN_UID` | `0` | The start script writes the config file |
| ClickHouse | `CLICKHOUSE_USER`, `CLICKHOUSE_PASSWORD`, `CLICKHOUSE_DB` | `superset`, generated, `default` | ClickHouse account and database |
| Postgres, Redis | `POSTGRES_PASSWORD`, `REDIS_PASSWORD` | generated | Database passwords |

## Feature flags, alerts and email

Superset's settings live in `superset_config.py`, which the start script writes from `SUPERSET_CONFIG_PY`. Add your own lines in `SUPERSET_CONFIG_EXTRA` instead of editing it, for example:

```python
FEATURE_FLAGS = {"DASHBOARD_RBAC": True, "ENABLE_TEMPLATE_PROCESSING": True}
```

Alerts and reports (`"ALERT_REPORTS": True`) run on the worker and need SMTP settings (`SMTP_HOST`, `SMTP_USER`, `SMTP_PASSWORD`, `EMAIL_NOTIFICATIONS = True`, ...). Reports with screenshots also need a headless browser, which this image doesn't include; text and CSV reports work without one.

## Connecting more databases

Our image has drivers for ClickHouse and PostgreSQL. To connect another database (MySQL, Snowflake, BigQuery, ...), add its driver to `superset/Dockerfile` in your fork (`uv pip install <driver>`, see [Superset's database list](https://superset.apache.org/docs/configuration/databases)) and point both Superset services at your fork.

## Upgrading

Change `FROM apache/superset:6.1.0` in `superset/Dockerfile` (in your fork) and check the driver ranges in Superset's `pyproject.toml` (the `postgres` and `clickhouse` extras). Redeploy both Superset services; migrations run on start. Back up Postgres first. ClickHouse: set `CLICKHOUSE_IMAGE_TAG` to a newer version and redeploy.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Superset deploy takes a few minutes | The first start migrates the metadata database and creates roles; later starts are faster |
| `ADMIN_PASSWORD` doesn't work after changing it | It is applied only when the admin is created. Reset it in a Railway shell: `superset fab reset-password --username admin --password <new>` |
| The ClickHouse connection is missing | It is registered only when no connection named `CLICKHOUSE_DATABASE_NAME` exists. Redeploy Superset to register it again |
| Saved connections fail with a decryption error | `SUPERSET_SECRET_KEY` was changed. Set the old value back |
| A long SQL Lab query times out | Raise `GUNICORN_TIMEOUT`, or turn on asynchronous execution for the connection (Advanced > Performance) so the worker runs it |
