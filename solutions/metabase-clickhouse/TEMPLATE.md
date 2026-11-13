# Deploy and Host Metabase + ClickHouse on Railway

Metabase is the open-source business intelligence tool: ask questions in a visual query builder or SQL, build dashboards, set up alerts and share results with your team. ClickHouse is the open-source columnar database for analytics, which scans billions of rows in seconds. Together they give you a self-hosted analytics stack: load events, logs or exports into ClickHouse and explore them in Metabase.

## About Hosting Metabase + ClickHouse

Self-hosted Metabase is one Java app that keeps its own settings, questions and dashboards in an application database (PostgreSQL for production; the built-in H2 file loses everything on a redeploy without a volume). A fresh Metabase opens a setup page where the first visitor becomes the admin, and every data source has to be added by hand. ClickHouse needs a volume, a password, a listener on Railway's IPv6 private network and smaller internal log tables to run well on a small service.

This template runs Metabase's official image with PostgreSQL and ClickHouse. It creates your admin account and the ClickHouse connection before Metabase is reachable, so the setup page is never public, and you can query ClickHouse right after deploy. Both databases are on volumes, and every version is pinned and tested.

## Common Use Cases

- Product, web or business analytics dashboards over large event tables in ClickHouse
- Exploring logs, metrics or IoT data with SQL and charts, without a SaaS BI tool
- Sharing dashboards and scheduled reports with a team, with your data on your own infrastructure
- A self-hosted alternative to Looker, Tableau or Mixpanel dashboards on top of ClickHouse
- A BI front end for data you already load into ClickHouse from other services

## Dependencies for Metabase + ClickHouse Hosting

- PostgreSQL 17 (Metabase application database)
- ClickHouse 26.8 LTS

### Deployment Dependencies

- Metabase: https://github.com/metabase/metabase
- Metabase docs: https://www.metabase.com/docs/latest/
- ClickHouse: https://clickhouse.com/docs

### Implementation Details

**What you set:** `METABASE_ADMIN_EMAIL`, the email you log in with (Metabase service).

**After deploy:**

1. Open the Metabase URL and log in with `METABASE_ADMIN_EMAIL` and the generated `METABASE_ADMIN_PASSWORD` (Metabase service → Variables).
2. The **ClickHouse** database is already connected. Load data into it with `CLICKHOUSE_PUBLIC_URL` (ClickHouse service → Variables) or from other Railway services over the private network.
3. Ask a question or write SQL against your ClickHouse tables, and save it to a dashboard.

**This template:**

- Creates the admin account and the ClickHouse connection on the first start, while Metabase listens only inside its container, so nobody can claim the setup page
- Stores Metabase's settings, questions and dashboards in PostgreSQL on a volume, and encrypts the stored connection details with a generated key
- Uses Metabase's built-in ClickHouse driver; no plugin to install
- Caps Metabase's Java heap at 2 GB, so it doesn't size itself from the host's RAM
- Runs ClickHouse with a volume, a generated password, IPv6 and IPv4 listeners and small internal log tables
- Gives ClickHouse a password-protected HTTPS domain for loading data; PostgreSQL stays private
- Pins Metabase 0.65.4.3, ClickHouse 26.8 LTS and PostgreSQL 17

**Notes:** the first start takes 2-4 minutes (Metabase starts twice while it sets itself up). The three services idle at about 3.2 GB of RAM together (Metabase's Java heap is capped at 2 GB with `JAVA_OPTS`).

## Why Deploy Metabase + ClickHouse on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Metabase + ClickHouse on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
