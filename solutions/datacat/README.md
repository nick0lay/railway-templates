# DataCat (Replit observability)

Self-hosted [DataCat](https://github.com/replit/datacat) on Railway: Replit's open-source observability tool for metrics, logs, distributed traces, dashboards, host maps and alerts. It accepts OpenTelemetry (OTLP/HTTP) and Datadog-compatible agent and tracer traffic. This template stores telemetry in ClickHouse, and users, keys, monitors and dashboards in Postgres 18.

Upstream publishes no Docker image or releases yet, so this template builds DataCat from a pinned upstream commit (`6c6c985`, 2026-11-23). The admin account and organization are created at deploy, and DataCat is invite-only from then on.

DataCat is Apache-2.0 licensed. This template is not affiliated with or endorsed by Replit. DataCat is not affiliated with Datadog; Datadog is a trademark of Datadog, Inc.

## Architecture

```
   Browser (UI)      OTel SDKs / Collector      Datadog Agent / tracers      DataCat Agent on your hosts
        │ HTTPS             │ OTLP/HTTP + API key        │ HTTPS + API key            │ HTTPS + API key
        ▼                   ▼                            ▼                            ▼
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ Railway project                                                                              │
│                                                                                              │
│  DataCat :3000 (public)                                                                      │
│    UI, API, intake (/v1/traces, /v1/logs, /v1/metrics, Datadog routes), /install.sh           │
│    built from commit 6c6c985, healthcheck /api/healthz                                       │
│        │                                      │                                              │
│        ▼                                      ▼                                              │
│  Postgres 18 (private, volume)          ClickHouse 26.8 (private, volume)                    │
│    users, orgs, API keys, monitors,       spans, logs, metric points, APM rollups            │
│    dashboards, events                     TTL = DATACAT_RETENTION_DAYS                       │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| DataCat | `datacat/` in this folder: Dockerfile that builds upstream commit `6c6c985` | UI, API and telemetry intake (public, healthcheck `/api/healthz`) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | App database (private, volume) |
| ClickHouse | `clickhouse/clickhouse-server:26.8` | Telemetry storage (private, volume) |

The upstream `datacat-agent` container is not included. On Railway it would only measure its own container. Install the agent on the hosts you want to watch instead (see below); this DataCat serves the installer and the Linux binaries.

## What this template does differently

- **Pinned commit.** The Dockerfile fetches commit `6c6c985` and mirrors upstream's own Dockerfile. Deploys don't change when upstream's main branch moves.
- **Admin at deploy, invite-only.** `ADMIN_PASSWORD` and `DATACAT_SETUP_TOKEN` are generated. On the first boot the start script creates the admin and the organization through DataCat's setup API, so nobody can claim a fresh instance. DataCat has no public sign-up: after setup, new members join only through invite links that an admin creates.
- **ClickHouse for telemetry.** Upstream's default keeps telemetry in Postgres. ClickHouse is upstream's choice for larger volumes: about 14 times less disk and much faster long-range aggregations. It stays on the private network.
- **Agent installer that works.** The image builds the DataCat Agent for Linux amd64 and arm64, so `https://your-domain/install.sh` installs the agent on your servers and checks its SHA-256.
- **Postgres 18**, generated secrets, `DATACAT_TRUST_PROXY=1` (real client IPs behind Railway's proxy, so login throttling works per user), and a start script that waits for Postgres and ClickHouse so the first deploy doesn't crash on migrations.

## After deploy

1. The first build takes about 5 minutes.
2. Open the DataCat URL and sign in with `ADMIN_EMAIL` (default `admin@example.com`) and the `ADMIN_PASSWORD` variable of the `DataCat` service.
3. Under **Organization Settings → API Keys**, create an API key for your apps and agents.
4. Under **Users**, invite your team. Copy the invite link and share it privately. Links work once and expire after 30 days.

There is no password reset by email. Keep the admin password safe.

## Sending data

All intake is HTTPS on the public domain. Every request needs an API key, sent as the `DC-API-KEY` or `DD-API-KEY` header, or as `Authorization: Bearer`.

**OpenTelemetry (OTLP/HTTP).** Point any OTel SDK or Collector at the DataCat URL:

```sh
OTEL_EXPORTER_OTLP_ENDPOINT=https://your-domain
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_EXPORTER_OTLP_HEADERS=DC-API-KEY=your-api-key
```

Both protobuf and JSON work, on `/v1/traces`, `/v1/logs` and `/v1/metrics` (also under `/otlp/v1/...`).

**OTLP gRPC** (port 4317) is not exposed: DataCat's server only accepts OTLP over HTTP. Use HTTP, or run an OTel Collector or the DataCat Agent next to your app. Both accept gRPC locally and forward over HTTPS.

**DataCat Agent on a Linux host:**

```sh
curl -fsSL https://your-domain/install.sh -o /tmp/datacat-install.sh
DATACAT_API_KEY=your-api-key sh /tmp/datacat-install.sh
```

**Datadog Agent:** set `dd_url` and `apm_config.apm_dd_url` to the DataCat URL, and `logs_config.logs_dd_url` to `your-domain:443`. The exact snippet is on the in-app **Docs** page.

**Reading data from scripts:** the Datadog-style query APIs (`/api/v2/logs/events`, `/api/v2/spans/events`, `/api/v1/query`) take an API key plus an application key (`DD-API-KEY` and `DD-APPLICATION-KEY`). Admins create application keys under Organization Settings.

## Variables

### User-configurable

| Variable | Default | Notes |
|---|---|---|
| `ADMIN_EMAIL` | `admin@example.com` | First admin, created on the first boot |
| `ADMIN_PASSWORD` | generated | First admin's password. Used only on the first boot |
| `ORG_NAME` | `My Organization` | First organization |
| `DATACAT_RETENTION_DAYS` | `15` | Days of telemetry kept (ClickHouse TTLs) |
| `PUBLIC_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Set to your custom domain if you add one. Invite links and the installer use it |

Other upstream settings (redaction, body limits, private webhooks) are listed in upstream's [self-hosting guide](https://github.com/replit/datacat/blob/main/docs/SELF_HOSTING.md) and can be added as variables.

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `SESSION_SECRET` | generated | Signs session cookies. Changing it signs everyone out |
| `DATACAT_SETUP_TOKEN` | generated | Needed by the setup API. Used once at deploy |
| `DATABASE_URL` | from the Postgres variables | App database |
| `DATACAT_STORAGE` | `clickhouse` | Telemetry storage. Switching later starts with empty telemetry |
| `DATACAT_CLICKHOUSE_URL`, `_USER`, `_PASSWORD`, `_DB` | from the ClickHouse variables | Private ClickHouse connection |
| `DATACAT_TRUST_PROXY` | `1` | One proxy (Railway's edge) in front |
| `PORT` | `3000` | |

## Upgrading

Back up first (Postgres and ClickHouse). Then change `ARG DATACAT_REF` in `datacat/Dockerfile` to a newer upstream commit, compare upstream's `Dockerfile` and `agent/release.sh` with this one, and redeploy. Migrations run on startup and are additive.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Admin login fails | Use the `ADMIN_PASSWORD` from the first deploy. Changing the variable later doesn't change an existing account |
| Intake returns 403 | The API key is missing, wrong or revoked. Send it as `DC-API-KEY`, `DD-API-KEY` or a Bearer token |
| Query API returns 403 | The query APIs need both an API key and an application key from the same organization |
| Invite links show the Railway domain | Set `PUBLIC_URL` to your custom domain and redeploy |
| No data after a gRPC exporter is set up | Only OTLP/HTTP is exposed. Switch the exporter to `http/protobuf` |

## Testing

Tested on Railway on 2026-11-26 with DataCat commit `6c6c985` (2026-11-23), ClickHouse 26.8 and Postgres 18. The build took about 8 minutes, and idle memory was about 0.12 GB for DataCat, 0.17 GB for ClickHouse and 0.1 GB for Postgres. The admin and organization were created at deploy and the setup token was not printed. Without a session or key, the UI and query APIs returned 401, and intake without a key or with a wrong key returned 403. A wrong password was refused, and the admin signed in with the generated password. Setup was closed: a wrong token returned 403, the real token returned 409, and a made-up invite was refused. With a new API key, OTLP/HTTP logs, traces and metrics were sent through the public domain and read back through the logs, spans and metrics query APIs; the trace view showed the span with its log. The agent installer and the Linux agent binaries were served. After redeploying ClickHouse, Postgres and DataCat, the admin login, the API key and all the earlier logs, spans and metric points were still there. Not tested: the Datadog Agent, the DataCat Agent on a real host, monitors and notifications.

## License

DataCat is licensed under the [Apache License 2.0](https://github.com/replit/datacat/blob/main/LICENSE). This template is not affiliated with or endorsed by Replit or Datadog.
