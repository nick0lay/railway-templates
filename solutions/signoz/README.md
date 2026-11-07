# SigNoz

Self-hosted [SigNoz](https://github.com/SigNoz/signoz) on Railway: open-source observability (an alternative to Datadog and New Relic) with traces, metrics, logs, dashboards and alerts in one app, built on OpenTelemetry and ClickHouse. The admin account is created at deploy and sign-up is off, the OTLP endpoint only accepts data that carries the generated token, and ClickHouse is reachable only over the private network. Versions are pinned and tested.

## Architecture

```
        You (browser)                    Your apps (OpenTelemetry SDKs)
             │ HTTPS                          │ OTLP/HTTP + Bearer token
             ▼                                ▼
┌────────────────────────────────────────────────────────────────────┐
│ Railway project                                                    │
│                                                                    │
│  SigNoz :8080 (public, login)     Collector :4318 (public, token)  │
│    UI, API, alerts, OpAMP :4320 ◄── pipeline settings              │
│    volume /var/lib/signoz           :4317 gRPC (private, token)    │
│    (users, dashboards, alerts)      runs schema migrations         │
│             │                                │                     │
│             ▼                                ▼                     │
│        ClickHouse :9000 / :8123 (private, password)                │
│          traces, metrics, logs, embedded Keeper                    │
│          volume /var/lib/clickhouse                                │
└────────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| SigNoz | `signoz/signoz:v0.149.0` | UI, query API, alerts and dashboards; SQLite metadata on a volume (public, login required) |
| Collector | `signoz/signoz-otel-collector:v0.144.15` | Receives OTLP traces, metrics and logs and writes them to ClickHouse; runs the schema migrations (public on OTLP/HTTP, token required) |
| ClickHouse | `clickhouse/clickhouse-server:25.12.11` | Telemetry storage with an embedded ClickHouse Keeper (private) |

## What this template does differently

- **No one can claim your instance.** On a fresh SigNoz, the first visitor to sign up becomes the admin. This template creates the admin from `SIGNOZ_USER_ROOT_EMAIL` and a generated `SIGNOZ_USER_ROOT_PASSWORD` (SigNoz's root user setting), which also turns off public sign-up. Other users join by invitation.
- **Ingest needs a token.** The collector's OTLP receiver (HTTP and gRPC) requires `Authorization: Bearer <SIGNOZ_INGEST_TOKEN>`. Requests without it get 401, so nobody can fill your ClickHouse or your bill with junk data. The public domain points at OTLP/HTTP (port 4318), so apps outside Railway can send data too.
- **ClickHouse has a password and no public endpoint.** SigNoz's own Railway files leave the ClickHouse `default` user without a password.
- **Three services instead of five.** ClickHouse runs the embedded Keeper that SigNoz's replicated tables need, and the collector runs the schema migrations before it starts, so there is no separate Keeper service and no one-off migrator that shows as stopped.
- **Upgrades migrate themselves.** The migrations are idempotent and run on every collector start, so a new collector image applies new tables automatically.
- **Pinned versions** instead of `latest`, and healthchecks on all three services.
- **Short ClickHouse system-log retention.** Internal ClickHouse logs (query, part and error logs) are kept for 3 days; the noisy ones (trace, text, metric logs) are off.

## After deploy

1. Open the SigNoz URL and log in with `SIGNOZ_USER_ROOT_EMAIL` and the `SIGNOZ_USER_ROOT_PASSWORD` variable (SigNoz service → Variables).
2. Point your apps at the collector. The Collector service's variables show the values to copy:

   | Your app's variable | Value |
   |---|---|
   | `OTEL_EXPORTER_OTLP_ENDPOINT` | `https://<collector domain>` (Collector → `OTEL_EXPORTER_OTLP_ENDPOINT`) |
   | `OTEL_EXPORTER_OTLP_HEADERS` | `Authorization=Bearer <token>` (Collector → `OTEL_EXPORTER_OTLP_HEADERS`) |
   | `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf` |
   | `OTEL_SERVICE_NAME` | your service name |

   Apps in the same Railway project can use the private endpoints instead (`OTLP_PRIVATE_HTTP_ENDPOINT`, or `OTLP_PRIVATE_GRPC_ENDPOINT` with `OTEL_EXPORTER_OTLP_PROTOCOL=grpc`). They need the same token. On Railway, reference it as `${{Collector.OTEL_EXPORTER_OTLP_HEADERS}}`.
3. Invite teammates from SigNoz's settings (members). Without SMTP, copy the invite link SigNoz shows.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| SigNoz | `SIGNOZ_USER_ROOT_EMAIL` | `admin@example.com` | Email of the admin account. You log in with it. Change it to your own before deploying |
| SigNoz | `SIGNOZ_USER_ROOT_PASSWORD` | generated | Read it after deploy. SigNoz applies it on every start, so changing it and redeploying resets the admin password |
| SigNoz | `SIGNOZ_GLOBAL_EXTERNAL__URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL used in links and invitations. Change it when you add a custom domain |
| SigNoz | `SIGNOZ_GLOBAL_INGESTION__URL` | `https://${{Collector.RAILWAY_PUBLIC_DOMAIN}}` | Endpoint shown in SigNoz's onboarding screens |
| Collector | `SIGNOZ_INGEST_TOKEN` | generated | Bearer token for OTLP. Change it and redeploy to rotate; update your apps |
| Collector | `COLLECTOR_CONFIG` | SigNoz pipeline | The collector's OpenTelemetry YAML. Edit to add receivers or processors |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| SigNoz | `SIGNOZ_USER_ROOT_ENABLED` | `true` | Creates the admin and turns off public sign-up. Setting it to `false` reopens sign-up only on an empty install |
| SigNoz | `SIGNOZ_USER_ROOT_ORG_NAME` | `default` | Organization of the admin. Don't change it after the first deploy |
| SigNoz | `SIGNOZ_SQLSTORE_PROVIDER`, `SIGNOZ_SQLSTORE_SQLITE_PATH` | `sqlite`, `/var/lib/signoz/signoz.db` | Users, dashboards and alerts on the volume |
| SigNoz, Collector | `SIGNOZ_TELEMETRYSTORE_CLICKHOUSE_DSN`, `SIGNOZ_OTEL_COLLECTOR_CLICKHOUSE_DSN` | `tcp://default:...@${{ClickHouse.RAILWAY_PRIVATE_DOMAIN}}:9000` | ClickHouse over the private network |
| Collector | `SIGNOZ_HOST` | `${{SigNoz.RAILWAY_PRIVATE_DOMAIN}}` | The collector gets pipeline settings (log pipelines, sampling) from SigNoz over OpAMP |
| Collector | `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_HEADERS`, `OTLP_PRIVATE_*` | | Values to copy into your apps |
| Collector | `PORT` | `13133` | Health check port; the public domain targets 4318 |
| Collector | `COLLECTOR_RUN_SH` | script | Runs the schema migrations, then the collector |
| ClickHouse | `CLICKHOUSE_PASSWORD` | generated | Password of the `default` user |
| ClickHouse | `CLICKHOUSE_RUN_SH` | script | Writes the ClickHouse config (password, embedded Keeper, `cluster` definition SigNoz expects), installs SigNoz's `histogramQuantile` function on the volume, starts ClickHouse |
| ClickHouse | `HISTOGRAM_QUANTILE_VERSION`, `CLICKHOUSE_SKIP_USER_SETUP`, `PORT` | | Function version, users from the config, HTTP port 8123 for the healthcheck |

## Retention and size

Retention for traces, logs and metrics is set in SigNoz's settings. ClickHouse grows with the data you send; watch the volume size in Railway and raise it before it fills.

## Upgrading

Change the image tags of SigNoz and the Collector together (see [SigNoz releases](https://github.com/SigNoz/signoz/releases) and [collector releases](https://github.com/SigNoz/signoz-otel-collector/releases)) and redeploy. The collector applies new ClickHouse migrations before it starts. ClickHouse can be moved to a newer version, but not back.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Your app gets 401 from the collector | The `Authorization: Bearer` header is missing or the token is wrong. Copy `OTEL_EXPORTER_OTLP_HEADERS` from the Collector service |
| SigNoz fails to start with a root password error | SigNoz needs 12+ characters with upper and lower case letters, a number and a symbol. The generated password has all of them; one you set must too |
| Login fails after changing `SIGNOZ_USER_ROOT_EMAIL` | The root user's email is updated on the next start. Log in with the new email and the current password |
| No data shows up | Check the Collector logs for ClickHouse errors, and that your app sends to `/v1/traces`, `/v1/metrics` or `/v1/logs` on the collector domain |
| Collector restarts on first deploy | It waits for ClickHouse and runs the migrations (about a minute); it becomes healthy once they finish |

## License

SigNoz is MIT-licensed except for the `ee` directory, which is under SigNoz's enterprise license; see the [license file](https://github.com/SigNoz/signoz/blob/main/LICENSE). ClickHouse is Apache-2.0.

## Testing

Tested on 2026-11-07 with SigNoz v0.149.0, collector v0.144.15 and ClickHouse 25.12.11 in a throwaway Railway project. All three services were healthy about a minute and a half after deploy; the collector ran the migrations in about 45 seconds. API requests without a login, a wrong password and a stranger's sign-up were refused, and the admin logged in. OTLP traces, logs and metrics sent without a token or with a wrong token got 401; with the token they were stored and read back through SigNoz's query API, and the service appeared in the services list. After redeploying all three services three times, earlier traces, logs, metrics and a dashboard were still there, and the admin still logged in. Idle memory: ClickHouse about 0.47 GB, Collector 0.04 to 0.13 GB, SigNoz about 0.06 GB. Not tested: the browser UI (only its API), alerts with notification channels, and email.
