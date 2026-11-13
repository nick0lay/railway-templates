# Deploy and Host Apache Superset + ClickHouse on Railway

Apache Superset is open-source business intelligence: dashboards, 40+ chart types, a SQL editor (SQL Lab), datasets with metrics, and a REST API, as an alternative to Tableau, Looker and Power BI. ClickHouse is the open-source columnar database for analytics, which answers aggregate queries over billions of rows in milliseconds. Together they give you a self-hosted analytics stack: store your events and metrics in ClickHouse and explore them in Superset.

## About Hosting Apache Superset + ClickHouse

Self-hosted Superset is a web app and a Celery worker with a metadata database (Postgres) and Redis for caches, query results and the task queue; ClickHouse holds the data you analyze. The official Superset image ships without database drivers, so neither Postgres nor ClickHouse works out of the box, the default setup uses SQLite and a known secret key, and nothing is connected until you add a database by hand. Superset also has to migrate its metadata database and create the first admin before anyone can log in.

This template builds Superset 6.1 with the Postgres and ClickHouse drivers, generates the secret key and the admin password, creates the admin at deploy and registers the ClickHouse connection, so SQL Lab works right after the first start. All databases are private on volumes, and every version is pinned and tested.

## Common Use Cases

- Dashboards over product events, logs or IoT data stored in ClickHouse
- A self-hosted Tableau, Looker or Power BI alternative with your data on your own infrastructure
- Ad-hoc SQL exploration of large tables in SQL Lab, with charts from any query
- Embedding Superset dashboards in your own app through the REST API
- A shared BI workspace for a team, with roles and row-level security

## Dependencies for Apache Superset + ClickHouse Hosting

- ClickHouse 26.8
- PostgreSQL 18
- Redis 8

### Deployment Dependencies

- Apache Superset: https://github.com/apache/superset
- Superset documentation: https://superset.apache.org/docs/intro
- ClickHouse connector for Superset: https://clickhouse.com/docs/integrations/superset

### Implementation Details

**What you set:** nothing. Defaults work.

**After deploy:**

1. Open the Superset URL and log in as `admin` with the generated `ADMIN_PASSWORD` (Superset service → Variables).
2. Open SQL Lab, pick the **ClickHouse** database and run a query.
3. Create datasets from your ClickHouse tables, then charts and dashboards.

**This template:**

- Creates the admin at deploy (no first-visitor takeover); self-registration is off
- Adds the `clickhouse-connect` and `psycopg2` drivers to Superset's official image and registers the ClickHouse connection on the first start
- Uses Postgres for metadata, Redis for caches and query results, and a Celery worker with the scheduler for async queries, alerts and reports
- Generates `SUPERSET_SECRET_KEY` and all database passwords
- Runs Superset on `[::]` and ClickHouse on `::`, for Railway's IPv6 private network
- Keeps ClickHouse, Postgres and Redis private, with no public domain or TCP proxy
- Runs the metadata migrations on every start, so upgrades need no manual step
- Tunes ClickHouse for a small service: high-volume internal logs off or kept for a few days
- Pins Superset 6.1.0, ClickHouse 26.8 (LTS), PostgreSQL 18 and Redis 8.10

**Notes:** extra settings (feature flags, email for alerts and reports) go in `SUPERSET_CONFIG_EXTRA`. To load data from outside Railway, add a public domain to the ClickHouse service.

## Why Deploy Apache Superset + ClickHouse on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Apache Superset + ClickHouse on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
