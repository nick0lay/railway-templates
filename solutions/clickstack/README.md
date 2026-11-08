# ClickStack

Self-hosted [ClickStack](https://clickhouse.com/use-cases/observability) on Railway: ClickHouse's open-source observability stack, with the [HyperDX](https://github.com/hyperdxio/hyperdx) UI for logs, traces, metrics and session replays, an OpenTelemetry collector, ClickHouse and MongoDB. The admin account is created at deploy and nobody else can sign up, the OTLP endpoint only accepts data that carries your team's API key, and ClickHouse and MongoDB are reachable only over the private network. Versions are pinned and tested.

## Architecture

```
        You (browser)                    Your apps (OpenTelemetry SDKs)
             │ HTTPS                          │ OTLP/HTTP + API key
             ▼                                ▼
┌────────────────────────────────────────────────────────────────────┐
│ Railway project                                                    │
│                                                                    │
│  HyperDX :8080 (public, login)    Collector :4318 (public, API key)│
│    UI, API, alerts                  :4317 gRPC (private, API key)  │
│    OpAMP :4320 ───────────────────► pipeline + accepted API keys   │
│        │            │                         │                    │
│        ▼            ▼                         ▼                    │
│   MongoDB :27017   ClickHouse :8123 / :9000 (private, password)    │
│   users, dashboards,  logs, traces, metrics, sessions              │
│   alerts (volume)     volume /var/lib/clickhouse                   │
└────────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| HyperDX | `hyperdx/hyperdx:2.43.1` | UI, API, alert checks and the OpAMP server that configures the collector (public, login required) |
| Collector | `hyperdx/hyperdx-otel-collector:2.43.1` | Receives OTLP logs, traces and metrics and writes them to ClickHouse (public on OTLP/HTTP, API key required) |
| ClickHouse | `clickhouse/clickhouse-server:26.8.36.3-alpine` | Telemetry storage (private, password) |
| MongoDB | `mongo:7.0.45` | Users, teams, dashboards, saved searches and alerts (private, password) |

## What this template does differently

- **No one can claim your instance.** On a fresh HyperDX, the first visitor to open the URL creates the admin account. This template creates the admin from `HYPERDX_ADMIN_EMAIL` and a generated `HYPERDX_ADMIN_PASSWORD` on the first start. HyperDX allows one team, so after that sign-up is closed; teammates join by invitation.
- **Ingest needs an API key.** Creating the team turns on API-key authentication on the collector. OTLP requests without your team's ingestion API key get 401, so nobody can fill your ClickHouse or your bill with junk data. The key is in HyperDX under Team Settings.
- **Databases are private and password-protected.** The other ClickStack templates on Railway expose MongoDB through a public TCP proxy, and one also gives ClickHouse a public domain.
- **Pinned versions** (HyperDX 2.43.1, ClickHouse 26.8.36.3, MongoDB 7.0.45) instead of `latest` or a floating `:2`, and healthchecks on HyperDX, the collector and ClickHouse.
- **Short ClickHouse system-log retention.** ClickHouse's own query and part logs are kept for 3 days; the noisy ones (trace, text, metric logs) are off, so the volume holds your telemetry, not ClickHouse's.
- **Works on Railway's IPv6 private network.** ClickHouse, MongoDB and the HyperDX UI listen on IPv6 and IPv4, so the services and your other Railway apps can reach each other over `*.railway.internal`.

## After deploy

1. Open the HyperDX URL and log in with `HYPERDX_ADMIN_EMAIL` and the `HYPERDX_ADMIN_PASSWORD` variable (HyperDX service → Variables).
2. In HyperDX, open **Team Settings** and copy the **ingestion API key**.
3. Point your apps at the collector:

   | Your app's variable | Value |
   |---|---|
   | `OTEL_EXPORTER_OTLP_ENDPOINT` | `https://<collector domain>` (Collector → `OTEL_EXPORTER_OTLP_ENDPOINT`) |
   | `OTEL_EXPORTER_OTLP_HEADERS` | `authorization=<ingestion API key>` |
   | `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf` |
   | `OTEL_SERVICE_NAME` | your service name |

   Apps in the same Railway project can use the private endpoints instead (`OTLP_PRIVATE_HTTP_ENDPOINT`, or `OTLP_PRIVATE_GRPC_ENDPOINT` with `OTEL_EXPORTER_OTLP_PROTOCOL=grpc`), with the same key. Both `<key>` and `Bearer <key>` are accepted.
4. Open **Search** in HyperDX and pick the Logs or Traces source. The four sources (Logs, Traces, Metrics, Sessions) and the ClickHouse connection are set up on the first start.
5. Invite teammates from Team Settings. Without email settings, copy the invite link HyperDX shows.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| HyperDX | `HYPERDX_ADMIN_EMAIL` | `admin@example.com` | Email of the admin account, created on the first start. Change it to your own before deploying |
| HyperDX | `HYPERDX_ADMIN_PASSWORD` | generated | Read it after deploy. Used only on the first start; change the password in HyperDX afterwards |
| HyperDX | `FRONTEND_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL used in links and invitations. Change it when you add a custom domain |
| HyperDX | `USAGE_STATS_ENABLED` | `false` | Anonymous usage statistics to HyperDX |
| Collector | `HYPERDX_OTEL_EXPORTER_TABLES_TTL` | `720h` | How long logs, traces, metrics and sessions are kept (30 days). Applies when the tables are created |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| HyperDX | `HYPERDX_APP_URL` | `${{FRONTEND_URL}}` | Same public URL |
| HyperDX | `HYPERDX_APP_PORT`, `PORT`, `HYPERDX_API_PORT`, `HYPERDX_OPAMP_PORT` | `8080`, `8080`, `8000`, `4320` | UI (public), API (inside the container, the UI proxies `/api` to it), OpAMP (private, for the collector) |
| HyperDX | `HYPERDX_APP_LISTEN_HOSTNAME` | `::` | UI listens on IPv6 and IPv4 |
| HyperDX | `MONGO_URI` | `mongodb://...@${{MongoDB.RAILWAY_PRIVATE_DOMAIN}}:27017/hyperdx?authSource=admin` | MongoDB over the private network |
| HyperDX | `EXPRESS_SESSION_SECRET`, `TOKEN_ENCRYPTION_KEY` | generated | Session signing and encryption of stored Slack/OAuth tokens |
| HyperDX | `DEFAULT_CONNECTIONS`, `DEFAULT_SOURCES` | ClickHouse connection and the four sources | Created for the team on the first start (from the upstream compose file) |
| HyperDX | `HYPERDX_RUN_SH` | script | Starts HyperDX and creates the admin on the first start |
| Collector | `OPAMP_SERVER_URL` | `http://${{HyperDX.RAILWAY_PRIVATE_DOMAIN}}:4320` | The collector gets its pipeline and the accepted API keys from HyperDX |
| Collector | `CLICKHOUSE_ENDPOINT`, `CLICKHOUSE_USER`, `CLICKHOUSE_PASSWORD` | native protocol over the private network | Where telemetry is written |
| Collector | `HYPERDX_OTEL_EXPORTER_CLICKHOUSE_DATABASE`, `HYPERDX_OTEL_EXPORTER_CREATE_LEGACY_SCHEMA` | `default`, `true` | The exporter creates the tables, as in the upstream compose file |
| Collector | `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTLP_PRIVATE_*` | | Values to copy into your apps |
| Collector | `PORT` | `13133` | Health check port; the public domain targets 4318 |
| ClickHouse | `CLICKHOUSE_USER`, `CLICKHOUSE_PASSWORD`, `CLICKHOUSE_DB` | `hyperdx`, generated, `default` | Created by the ClickHouse image on the first start |
| ClickHouse | `CLICKHOUSE_RUN_SH` | script | Shorter system-log retention and IPv6 listening, then the official entrypoint |
| MongoDB | `MONGO_INITDB_ROOT_USERNAME`, `MONGO_INITDB_ROOT_PASSWORD` | `hyperdx`, generated | Root user, created on the first start |

## Retention and size

The collector creates the tables with a 30-day TTL (`HYPERDX_OTEL_EXPORTER_TABLES_TTL`). ClickHouse grows with the data you send; watch the volume size in Railway and raise it before it fills. To change retention on existing tables, run `ALTER TABLE ... MODIFY TTL` in ClickHouse.

## Upgrading

Change the image tags of HyperDX and the Collector together (see [HyperDX releases](https://github.com/hyperdxio/hyperdx/releases)) and redeploy. ClickHouse can be moved to a newer version, but not back. Moving MongoDB more than one major version at a time is not supported by MongoDB.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Your app gets 401 from the collector | The `authorization` header is missing or the key is wrong. Copy the ingestion API key from HyperDX → Team Settings |
| Login fails after changing `HYPERDX_ADMIN_PASSWORD` | The variable is used only on the first start. Use the password you set in HyperDX, or the original value |
| HyperDX logs "admin creation failed" | The password must have 12+ characters with upper and lower case letters, a number and a symbol. The generated one has all of them; one you set must too |
| No data shows up | Check the Collector logs for ClickHouse errors, and that your app sends to `/v1/traces`, `/v1/metrics` or `/v1/logs` on the collector domain |
| HyperDX logs "OpenTelemetry SDK initialization skipped" | HyperDX's own telemetry is off. This is expected and harmless |

## License

HyperDX is MIT-licensed. ClickHouse is Apache-2.0. MongoDB Community Server is under the SSPL.

## Testing

Tested on 2026-11-08 with HyperDX 2.43.1, the HyperDX collector 2.43.1, ClickHouse 26.8.36.3 and MongoDB 7.0.45 in a throwaway Railway project. All four services were healthy within a minute of deploy, and the admin was created a second after the API started. API requests without a login, a wrong password and a stranger's sign-up were refused; the admin logged in and saw the four default sources and the ClickHouse connection. OTLP requests without an API key or with a wrong key got 401; a trace and a log sent with the team's key were stored in ClickHouse and read back through HyperDX's ClickHouse proxy. A service in the same project reached the collector's private endpoint: 401 without the key, 200 with it. After redeploying all four services, earlier traces, the admin and the sources were still there, sign-up stayed closed and new data was ingested. Idle memory: ClickHouse about 0.8 GB, HyperDX 0.4 to 0.55 GB, MongoDB 0.24 GB, Collector 0.05 GB. Not tested: the browser UI beyond its API, alerts, session replay and email.
