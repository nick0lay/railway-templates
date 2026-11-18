# Metabase + Postgres

Self-hosted [Metabase](https://www.metabase.com) on Railway with a PostgreSQL application database. Metabase is open-source BI: a visual query builder, SQL editor, dashboards, alerts and sharing, with connectors for PostgreSQL, MySQL, BigQuery, Snowflake, ClickHouse and many more. This template creates your admin account before Metabase is reachable, so nobody can claim your instance. Metabase keeps its own data in a private PostgreSQL 18 on a volume, stored credentials are encrypted, the Java heap is capped, and every version is pinned and tested.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/metabase-065-postgres-18?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
            You (browser)
                 │ HTTPS
                 ▼
┌──────────────────────────────────────────────────────┐
│ Railway project                                      │
│                                                      │
│  Metabase :3000  public, login required              │
│      │                                               │
│      │ users, settings, questions, dashboards        │
│      ▼                                               │
│  Postgres :5432  private (no domain, no TCP proxy),  │
│                  volume                              │
└──────────────────────────────────────────────────────┘
          │
          ▼  your data sources (added in Admin → Databases):
             databases in this project over the private network,
             or any database Metabase can reach
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Metabase | `metabase/metabase:v0.65.5.1` | BI web app (public, login required) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Metabase application database: users, settings, questions, dashboards (private, volume) |

## What this template does differently

- **No one can claim your instance.** A fresh Metabase opens a setup page where the first visitor becomes the admin. Here Metabase first starts listening only inside its container; the start script creates the admin from `METABASE_ADMIN_EMAIL` and a generated `METABASE_ADMIN_PASSWORD`, and only then restarts Metabase on the public port. Railway's health check waits for that, so the setup page is never reachable.
- **Production application database, kept private.** Metabase stores everything in PostgreSQL 18 on a volume instead of the built-in H2 file. PostgreSQL has no public domain and no TCP proxy.
- **Stored credentials encrypted.** Connection details for the databases you add are encrypted with a generated `MB_ENCRYPTION_SECRET_KEY`. Without it, Metabase stores them in plain text in its application database.
- **Memory capped.** `JAVA_OPTS=-Xmx2g` limits the Java heap. Without it, Java sizes the heap from the host's RAM, which on Railway can be far more than Metabase needs.
- **Pinned versions.** Metabase 0.65.5.1 and PostgreSQL 18 instead of `latest`, so a redeploy never upgrades (and migrates) Metabase by surprise.
- **Health check and restarts.** Railway waits for `/api/health`, restarts Metabase on failure and gives both services time to shut down cleanly on redeploy.

## After deploy

1. Wait for the Metabase service to turn green. The first start takes 2-4 minutes: Metabase migrates its database, sets itself up, and restarts once.
2. Open the Metabase URL and log in with `METABASE_ADMIN_EMAIL` and the `METABASE_ADMIN_PASSWORD` variable (Metabase service → Variables). Change the password in your account settings.
3. Add your data in **Admin → Databases → Add a database**. A database in the same Railway project is reachable over the private network: use its `RAILWAY_PRIVATE_DOMAIN` (for example `my-db.railway.internal`) and its private port. Give Metabase a read-only user where you can.
4. Ask a question or write SQL and save it to a dashboard. The Sample Database that comes with Metabase lets you try it before connecting your own data.
5. Invite teammates in **Admin → People**. Invitation emails need SMTP (**Admin → Settings → Email**); without it, you can copy the invite link.

Keep the template's Postgres for Metabase itself. It holds Metabase's users and sessions, so don't add it as a data source for everyone; put your business data in a separate database.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Metabase | `METABASE_ADMIN_EMAIL` | `admin@example.com` | Email of the admin account. You log in with it; set your own before deploying |
| Metabase | `METABASE_ADMIN_PASSWORD` | generated | Read it after deploy. Used only on the first start; change the password in Metabase afterwards |
| Metabase | `METABASE_SITE_NAME` | `Metabase` | Instance name |
| Metabase | `MB_SITE_URL` | Railway domain | Change it when you add a custom domain |
| Metabase | `JAVA_OPTS` | `-Xmx2g` | Raise `-Xmx` for many users or large result sets |
| Metabase | `MB_ANON_TRACKING_ENABLED` | `false` | Anonymous usage statistics to Metabase |

Any other [Metabase environment variable](https://www.metabase.com/docs/latest/configuring-metabase/environment-variables) (`MB_EMAIL_SMTP_*`, `MB_REPORT_TIMEZONE`, `MB_PASSWORD_COMPLEXITY`, ...) can be added to the Metabase service.

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Metabase | `MB_DB_TYPE`, `MB_DB_HOST`, `MB_DB_PORT`, `MB_DB_DBNAME`, `MB_DB_USER`, `MB_DB_PASS` | from Postgres | Application database over the private network |
| Metabase | `MB_ENCRYPTION_SECRET_KEY` | generated | Encrypts stored connection details. Changing it makes them unreadable |
| Metabase | `MB_RUN_SH`, `PORT` | script, `3000` | Start script (admin setup on 127.0.0.1, then Metabase on `::`) |
| Postgres | `POSTGRES_PASSWORD` and `PG*`, `DATABASE_URL` | generated | Database credentials and private connection URL |
| Postgres | `PGDATA` | `/var/lib/postgresql/data/pgdata` | Data directory on the volume |

## Custom domain

Add the domain to the **Metabase** service, set `MB_SITE_URL=https://bi.example.com` and redeploy Metabase.

## Upgrading

Change the Metabase image tag (for example `metabase/metabase:v0.66.1`) and redeploy; Metabase migrates its database on start. Back up Postgres first: Metabase can't be downgraded after a migration. Read the [release notes](https://github.com/metabase/metabase/releases) before a new major version. Use the `metabase/metabase` image (open-source edition); `metabase/metabase-enterprise` needs a license token for paid features.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Metabase takes several minutes to turn green on the first deploy | Normal: database migrations, then the setup, then a restart on the public port |
| Login fails with the generated password | The admin is created on the first start only. If you changed `METABASE_ADMIN_PASSWORD` later, use the old value or reset it from another admin account |
| Too many failed logins | Metabase throttles login attempts per user for a short time; wait a minute and try again |
| A database in the project can't be reached | Use its private host (`RAILWAY_PRIVATE_DOMAIN`) and private port, not the public TCP proxy, and check its user and password |
| Saved connections fail after changing variables | `MB_ENCRYPTION_SECRET_KEY` was changed; set it back to the original value |
| Metabase restarts with out-of-memory errors | Raise `-Xmx` in `JAVA_OPTS` and the service's memory limit together |

## License

Metabase open-source edition is [AGPL-3.0](https://github.com/metabase/metabase/blob/master/LICENSE.txt). PostgreSQL is under the PostgreSQL License. You are responsible for using them under their licenses.

## Testing

Tested on 2026-11-18 with Metabase 0.65.5.1 and PostgreSQL 18 in a throwaway Railway project deployed from the template. Both services were healthy within two minutes of the deploy and stayed up. PostgreSQL had no public domain or TCP proxy. The setup page was closed (no setup token), a setup request with a made-up token was refused, anonymous API calls were refused and a wrong password was refused. The admin logged in as a superuser with the site URL set to the Railway domain. A native SQL query on the bundled Sample Database returned rows; a PostgreSQL database added over the private network was queried through a saved SQL question. After redeploying PostgreSQL and Metabase, the start script skipped the setup, and the admin (still the only user), the saved question and the stored, encrypted connection all worked (30/30 checks in the final run, including after the redeploy). At idle Metabase used about 2.2 GB of RAM and PostgreSQL about 0.1 GB. Not tested: the Metabase UI in a real browser, email, and upgrades.
