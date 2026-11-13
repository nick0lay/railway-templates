# Grafana + ClickHouse

[Grafana](https://github.com/grafana/grafana) dashboards on top of a [ClickHouse](https://github.com/ClickHouse/ClickHouse) analytics database, on Railway. The official ClickHouse data source plugin is installed and connected when the template deploys, a starter dashboard shows what is in ClickHouse, and both services keep their data on volumes. Grafana's admin password is generated, sign-up is off, and every version is pinned and tested.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/grafana-133-clickhouse-268?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
   You (dashboards)                  Your apps / scripts (load data)
          │ HTTPS                              │ HTTPS, user + password
          ▼                                    ▼
┌──────────────────────────────────────────────────────────────────┐
│ Railway project                                                  │
│                                                                  │
│  Grafana :3000                       ClickHouse :8123            │
│    public, login required  ───────▶    HTTPS domain, password    │
│    ClickHouse data source  private     required                  │
│    "ClickHouse overview"   network     volume /var/lib/clickhouse│
│    volume /var/lib/grafana                                       │
└──────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Grafana | `grafana/grafana:13.3.1` + `grafana-clickhouse-datasource` 4.23.5 | Dashboards, alerts and Explore (public, login required) |
| ClickHouse | `solutions/clickhouse/clickhouse` (official image, newest tested LTS: 26.8) | Analytics database (HTTPS domain with password, private network for Grafana) |

## What this template does differently

- **The data source is already connected.** Grafana installs the official ClickHouse plugin (pinned) before it starts, and the ClickHouse data source is provisioned from the ClickHouse service's variables. It talks to ClickHouse over Railway's private network. There's nothing to fill in after deploy.
- **A starter dashboard.** "ClickHouse overview" (folder *ClickHouse*) shows the version, uptime, data on disk, rows stored, queries and failed queries per minute, the largest tables and the slowest queries. It reads ClickHouse's own system tables, so it works on an empty database.
- **Nobody can claim your Grafana.** The admin password is generated at deploy (not `admin`/`admin`), sign-up is off and anonymous access is off.
- **Data on volumes.** Grafana's database (users, dashboards, alerts) and ClickHouse's data survive redeploys.
- **ClickHouse tuned for a small service.** It listens on IPv6 and IPv4 for Railway's private network, and the high-volume internal log tables are off. The query log is kept for 7 days, which is what the starter dashboard reads.
- **Pinned versions.** Grafana 13.3.1, plugin 4.23.5 and the newest ClickHouse LTS tested with the template, instead of `latest`.

## After deploy

1. Open the Grafana URL and log in as `admin` with the `GF_SECURITY_ADMIN_PASSWORD` variable (Grafana service → Variables).
2. Open **Dashboards → ClickHouse → ClickHouse overview** to see the server's state.
3. Load your data into ClickHouse. From outside Railway use `CLICKHOUSE_PUBLIC_URL` (ClickHouse service → Variables), for example:
   ```sh
   curl --user 'clickhouse:PASSWORD' https://YOUR-CLICKHOUSE-DOMAIN/ \
     --data-binary 'CREATE TABLE events (ts DateTime, name String) ENGINE = MergeTree ORDER BY ts'
   ```
   Apps in the same Railway project use `CLICKHOUSE_URL` over the private network.
4. Build panels: **Dashboards → New → Add visualization**, pick the **ClickHouse** data source and write SQL. Use `$__timeFilter(ts)` to follow the dashboard's time range.
5. Add users under **Administration → Users and access**. Change the admin password under your profile.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Grafana | `GF_SECURITY_ADMIN_USER` | `admin` | Applied on the first start only |
| Grafana | `GF_SECURITY_ADMIN_PASSWORD` | generated | Read it after deploy. Applied on the first start only; change it later in Grafana |
| Grafana | `GF_USERS_ALLOW_SIGN_UP` | `false` | `true` lets anyone with the URL create an account |
| Grafana | `GF_AUTH_ANONYMOUS_ENABLED` | `false` | `true` shows dashboards without login |
| Grafana | `GF_SERVER_ROOT_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Change it when you add a custom domain |
| Grafana | `GF_PLUGINS_PREINSTALL_SYNC` | `grafana-clickhouse-datasource@4.23.5` | Add more plugins as a comma-separated list (`id@version`) |
| ClickHouse | `CLICKHOUSE_IMAGE_TAG` | empty (newest tested LTS, 26.8) | ClickHouse can't be downgraded; read the release notes before moving up |
| ClickHouse | `CLICKHOUSE_DB` | `default` | Database created on start; also Grafana's default database |

Any other Grafana setting can be set with a `GF_<SECTION>_<KEY>` variable, for example SMTP for alert emails (`GF_SMTP_ENABLED`, `GF_SMTP_HOST`, `GF_SMTP_USER`, `GF_SMTP_PASSWORD`, `GF_SMTP_FROM_ADDRESS`). See [Grafana's configuration docs](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/).

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Grafana | `CLICKHOUSE_HOST`, `CLICKHOUSE_PORT`, `CLICKHOUSE_USER`, `CLICKHOUSE_PASSWORD`, `CLICKHOUSE_DB` | from the ClickHouse service | The provisioned data source connects over the private network |
| Grafana | `GRAFANA_RUN_SH` | script | Start script: writes the data source and dashboard provisioning, then starts Grafana |
| Grafana | `GRAFANA_DASHBOARD_JSON` | dashboard | The starter dashboard |
| Grafana | `PORT`, `GF_SERVER_HTTP_PORT` | `3000` | Port Grafana listens on and Railway routes to |
| Grafana | `RAILWAY_RUN_UID` | `0` | Grafana runs as root so it can write to the Railway volume |
| Grafana | `GF_ANALYTICS_REPORTING_ENABLED`, `GF_LOG_MODE` | `false`, `console` | No usage reporting; logs in Railway |
| ClickHouse | `CLICKHOUSE_USER`, `CLICKHOUSE_PASSWORD` | `clickhouse`, generated | ClickHouse account (replaces the passwordless `default` user) |
| ClickHouse | `CLICKHOUSE_URL`, `CLICKHOUSE_PUBLIC_URL` | built from the above | Connection URLs for the private network and for outside Railway |
| ClickHouse | `PORT` | `8123` | HTTP port |

## Upgrading

- **Grafana:** change the image tag (for example `grafana/grafana:13.4.0`) and redeploy; the database migrates on start. Read the [release notes](https://github.com/grafana/grafana/releases) first.
- **ClickHouse plugin:** change the version in `GF_PLUGINS_PREINSTALL_SYNC` and redeploy. [Releases](https://github.com/grafana/clickhouse-datasource/releases).
- **ClickHouse:** set `CLICKHOUSE_IMAGE_TAG` to a newer version and redeploy. Upgrades can't be undone, so back up first.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Login fails with the generated password | The admin is created on the first start. If you changed `GF_SECURITY_ADMIN_PASSWORD` later, use the old one, or reset it in the Grafana service shell: `grafana cli admin reset-admin-password NEW` |
| The data source can't be edited in the UI | It is provisioned from variables and re-applied on every start. Change the `CLICKHOUSE_*` variables and redeploy, or add a second data source by hand |
| The starter dashboard can't be saved | It is provisioned and read-only. Use **Save as** to make an editable copy |
| "Queries per minute" is empty | ClickHouse writes its query log a few seconds after each query, and keeps it for 7 days. Run a few queries and refresh |
| Grafana restarts while deploying | The plugin downloads before Grafana starts; if grafana.com is unreachable the start fails and Railway retries |
| Links in alert emails point to the Railway domain | Set `GF_SERVER_ROOT_URL` to your custom domain and redeploy |

## License

Grafana is [AGPL-3.0](https://github.com/grafana/grafana/blob/main/LICENSE). The ClickHouse data source plugin and ClickHouse are Apache-2.0.

## Testing

Tested on 2026-11-13 with Grafana 13.3.1, plugin 4.23.5 and ClickHouse 26.8 in a throwaway Railway project deployed from the template. Both services were healthy about two minutes after deploy. Without a login, and with a wrong password, the Grafana API refused requests; sign-up and anonymous access were off, and ClickHouse refused a wrong password. The admin logged in with the generated password, the plugin was installed at the pinned version, and the provisioned data source passed Grafana's health check. A table created and filled through ClickHouse's public URL was queried through Grafana as a table and as a time series with `$__timeFilter`. Every panel of the starter dashboard returned data without errors. After redeploying Grafana, a folder created before the redeploy was still there and the data source still worked. Not tested: alerting, email and the browser UI (only its HTTP API).
