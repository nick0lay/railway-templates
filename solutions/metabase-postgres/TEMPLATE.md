# Deploy and Host Metabase + Postgres on Railway

Metabase is the open-source business intelligence tool: ask questions in a visual query builder or SQL, build dashboards, set up alerts and share results with your team. Connect it to PostgreSQL, MySQL, BigQuery, Snowflake, ClickHouse, MongoDB and many other databases, and give everyone in the company answers without writing code.

## About Hosting Metabase + Postgres

Self-hosted Metabase is one Java app that keeps its own users, settings, questions and dashboards in an application database. The built-in H2 file is not meant for production and is lost on a redeploy without a volume, so production installs use PostgreSQL. A fresh Metabase also opens a setup page where the first visitor becomes the admin, and Java sizes its heap from the host's RAM unless you cap it.

This template runs Metabase's official open-source image with a private PostgreSQL 18 on a volume. It creates your admin account before Metabase is reachable, so the setup page is never public, encrypts stored database credentials with a generated key, caps the Java heap, and pins every version.

## Common Use Cases

- Dashboards and reports over your app's production database or a read replica
- Self-serve analytics for non-technical teammates with the visual query builder
- Scheduled email or Slack reports and alerts on key metrics
- A self-hosted alternative to Looker, Tableau or Power BI, with your data on your own infrastructure
- Embedding charts and dashboards in internal tools

## Dependencies for Metabase + Postgres Hosting

- Metabase 0.65 (open-source edition)
- PostgreSQL 18 (Metabase application database)

### Deployment Dependencies

- Metabase: https://github.com/metabase/metabase
- Metabase docs: https://www.metabase.com/docs/latest/
- Environment variables: https://www.metabase.com/docs/latest/configuring-metabase/environment-variables

### Implementation Details

**What you set:** `METABASE_ADMIN_EMAIL`, the email you log in with (Metabase service).

**After deploy:**

1. Open the Metabase URL and log in with `METABASE_ADMIN_EMAIL` and the generated `METABASE_ADMIN_PASSWORD` (Metabase service, Variables). Change the password in your account settings.
2. Add your data in **Admin, Databases, Add a database**. A database in the same Railway project is reachable over the private network (for example `my-db.railway.internal`); others over their public host.
3. Ask a question or write SQL, and save it to a dashboard. The bundled Sample Database lets you try Metabase before connecting your own data.

**This template:**

- Creates the admin account on the first start, while Metabase listens only inside its container, so nobody can claim the setup page
- Stores Metabase's users, settings, questions and dashboards in PostgreSQL 18 on a volume; PostgreSQL has no public domain or TCP proxy
- Encrypts the connection details Metabase stores with a generated `MB_ENCRYPTION_SECRET_KEY`
- Caps Metabase's Java heap at 2 GB with `JAVA_OPTS`, so it doesn't size itself from the host's RAM
- Health check on `/api/health`, restart on failure and a clean shutdown on redeploy
- Sets the site URL to your Railway domain and turns anonymous usage tracking off
- Pins Metabase 0.65.6.2 and PostgreSQL 18 instead of `latest`

**Notes:** the first start takes 2-4 minutes (Metabase migrates its database, sets itself up and restarts once). Metabase idles at about 2 GB of RAM. Keep the app database for Metabase itself; connect your business data as separate databases. Metabase's open-source edition is AGPL-3.0; you are responsible for using it under its license.

## Why Deploy Metabase + Postgres on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Metabase + Postgres on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
