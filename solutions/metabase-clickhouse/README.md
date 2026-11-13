# Metabase + ClickHouse

Self-hosted [Metabase](https://www.metabase.com) with a [ClickHouse](https://clickhouse.com) analytics database on Railway. Metabase is open-source BI: a visual query builder, SQL editor, dashboards, alerts and sharing. ClickHouse stores and scans large tables fast. This template creates your admin account and the ClickHouse connection before Metabase is reachable, so nobody can claim your instance and you can query ClickHouse right after deploy. Metabase keeps its own data in PostgreSQL, both databases are on volumes, and every version is pinned and tested.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/metabase-065-clickhouse-268?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
            You (browser)                     Your data loaders, scripts, apps
                 │ HTTPS                                 │ HTTPS (user + password)
                 ▼                                       ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Railway project                                                      │
│                                                                      │
│  Metabase :3000  public ──── SQL over HTTP ────►  ClickHouse :8123   │
│  login required                (private network)   public HTTPS for  │
│      │                                             loading data;     │
│      │ settings, questions, dashboards             volume            │
│      ▼                                                               │
│  Postgres :5432  (private, volume)                                   │
└──────────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Metabase | `metabase/metabase:v0.65.4.3` | BI web app (login required) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:17` | Metabase application database: users, settings, questions, dashboards (private) |
| ClickHouse | [`solutions/clickhouse/clickhouse`](../clickhouse/clickhouse) (official image 26.8 LTS) | Your analytics data. Password-protected HTTPS domain for loading data |

## What this template does differently

- **No one can claim your instance.** A fresh Metabase opens a setup page where the first visitor becomes the admin. Here Metabase first starts listening only inside its container; the start script creates the admin from `METABASE_ADMIN_EMAIL` and a generated `METABASE_ADMIN_PASSWORD`, adds ClickHouse as a database, and only then restarts Metabase on the public port. Railway's health check waits for that, so the setup page is never reachable.
- **ClickHouse is connected out of the box.** Metabase's built-in ClickHouse driver connects over Railway's private network to the database in `CLICKHOUSE_DB`. Nothing to install or type in.
- **Production application database.** Metabase stores everything in PostgreSQL on a volume instead of the built-in H2 file, which is lost on redeploy. Connection details Metabase stores are encrypted with a generated `MB_ENCRYPTION_SECRET_KEY`.
- **Memory capped.** `JAVA_OPTS=-Xmx2g` limits the Java heap. Without it, Java sizes the heap from the host's RAM, which on Railway can be far more than Metabase needs. With the cap, Metabase idles at about 2.2 GB.
- **ClickHouse tuned for a small service.** Our tested ClickHouse service: listens on IPv6 and IPv4, a generated password, high-volume internal log tables off and the rest kept for 7 days.
- **Pinned versions.** Metabase 0.65.4.3, ClickHouse 26.8 LTS and PostgreSQL 17 instead of `latest`.

## After deploy

1. Wait for the Metabase service to turn green. The first start takes 2-4 minutes: Metabase migrates its database, sets itself up, and restarts once.
2. Open the Metabase URL and log in with `METABASE_ADMIN_EMAIL` and the `METABASE_ADMIN_PASSWORD` variable (Metabase service → Variables). Change the password in your account settings.
3. Load data into ClickHouse. From your machine, use `CLICKHOUSE_PUBLIC_URL` (ClickHouse service → Variables):

   ```bash
   # create a table and insert rows over HTTPS
   curl "https://<clickhouse domain>/?database=railway" --user "clickhouse:<password>" \
     --data-binary "CREATE TABLE events (ts DateTime, kind String, value UInt32) ENGINE = MergeTree ORDER BY ts"
   curl "https://<clickhouse domain>/?database=railway&query=INSERT%20INTO%20events%20FORMAT%20CSV" \
     --user "clickhouse:<password>" --data-binary @events.csv
   ```

   Other Railway services in the project can use `${{ClickHouse.CLICKHOUSE_URL}}` over the private network.
4. In Metabase, open **Admin → Databases → ClickHouse → Sync database schema now** (Metabase also syncs every hour), then ask a question or write SQL against your tables and save it to a dashboard.
5. Invite teammates in **Admin → People**. Invitation emails need SMTP (**Admin → Settings → Email**); without it, you can copy the invite link.

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
| ClickHouse | `CLICKHOUSE_DB` | `railway` | Database created on first start and connected in Metabase |
| ClickHouse | `CLICKHOUSE_IMAGE_TAG` | `26.8` | ClickHouse version. ClickHouse can't be downgraded |

Any other [Metabase environment variable](https://www.metabase.com/docs/latest/configuring-metabase/environment-variables) (`MB_EMAIL_SMTP_*`, `MB_REPORT_TIMEZONE`, ...) can be added to the Metabase service.

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Metabase | `MB_DB_TYPE`, `MB_DB_HOST`, `MB_DB_PORT`, `MB_DB_DBNAME`, `MB_DB_USER`, `MB_DB_PASS` | from Postgres | Application database over the private network |
| Metabase | `MB_ENCRYPTION_SECRET_KEY` | generated | Encrypts stored connection details. Changing it makes them unreadable |
| Metabase | `CLICKHOUSE_HOST`, `CLICKHOUSE_PORT`, `CLICKHOUSE_DB`, `CLICKHOUSE_USER`, `CLICKHOUSE_PASSWORD` | from ClickHouse | The connection added on the first start |
| Metabase | `MB_RUN_SH`, `PORT` | script, `3000` | Start script (admin and ClickHouse connection, then Metabase on `::`) |
| ClickHouse | `CLICKHOUSE_USER`, `CLICKHOUSE_PASSWORD` | `clickhouse`, generated | ClickHouse account |
| ClickHouse | `CLICKHOUSE_URL`, `CLICKHOUSE_PUBLIC_URL`, `PORT` | derived | Connection URLs (private and public) |
| Postgres | `POSTGRES_PASSWORD` and `PG*` | generated | Database credentials |

## Custom domain

Add the domain to the **Metabase** service, set `MB_SITE_URL=https://bi.example.com` and redeploy Metabase.

## Upgrading

Change the Metabase image tag (for example `metabase/metabase:v0.66.1`) and redeploy; Metabase migrates its database on start. Back up Postgres first: Metabase can't be downgraded after a migration. Read the [release notes](https://github.com/metabase/metabase/releases) before a new major version. ClickHouse follows its LTS releases through `CLICKHOUSE_IMAGE_TAG`.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Metabase takes several minutes to turn green on the first deploy | Normal: database migrations, then the setup, then a restart on the public port |
| Login fails with the generated password | The admin is created on the first start only. If you changed `METABASE_ADMIN_PASSWORD` later, use the old value or reset it from another admin account |
| ClickHouse is missing in Metabase | The start script logs `[seed] could not add ClickHouse` (Metabase service → Deploy logs). Add it in **Admin → Databases**: host `clickhouse.railway.internal`, port `8123`, user, password and database from the ClickHouse variables |
| New ClickHouse tables don't appear | Run **Sync database schema now** in **Admin → Databases → ClickHouse** |
| Metabase restarts with out-of-memory errors | Raise `-Xmx` in `JAVA_OPTS` and the service's memory limit together |
| ClickHouse returns `Authentication failed` | Use `CLICKHOUSE_USER` and `CLICKHOUSE_PASSWORD`; the `default` user has no access |

## License

Metabase open-source edition is [AGPL-3.0](https://github.com/metabase/metabase/blob/master/LICENSE.txt). ClickHouse is Apache-2.0. PostgreSQL is under the PostgreSQL License.

## Testing

Tested on 2026-11-13 with Metabase 0.65.4.3 in a throwaway Railway project deployed from the template. All three services were healthy within four minutes of the deploy. On the first start Metabase listened only on 127.0.0.1 while it created the admin and the ClickHouse connection, then restarted on `::`. Afterwards the setup page was closed (no setup token), anonymous API calls were refused, and a wrong password was refused. The admin logged in as a superuser, with the ClickHouse database already connected and the site URL set to the Railway domain. Rows loaded into ClickHouse over its public HTTPS domain (anonymous queries refused) were returned by a native SQL query in Metabase, and the new table appeared after a schema sync. After redeploying Metabase, the start script skipped the setup, and the admin, the single ClickHouse connection and the data were still there (18/18 checks before and after). At idle the services used about 2.2 GB (Metabase), 0.7 GB (ClickHouse) and 0.3 GB (Postgres) of RAM. Not tested: the Metabase UI in a real browser, email, and upgrades.
