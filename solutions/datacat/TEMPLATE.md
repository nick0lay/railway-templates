# Deploy and Host DataCat on Railway

DataCat is Replit's open-source, self-hosted observability tool: metrics, searchable logs, distributed traces, dashboards, host maps and alerts in one app. It accepts OpenTelemetry (OTLP over HTTP) and Datadog-compatible agent and tracer traffic, so existing instrumentation can point at it.

## About Hosting DataCat

DataCat is one Node.js process that serves the web UI, the API and the telemetry intake. It keeps users, organizations, API keys, monitors and dashboards in PostgreSQL, and can store spans, logs and metrics in ClickHouse. A hosted instance needs strong secrets, an admin account created before anyone else can claim the instance, a way for hosts to send data with an API key, and persistent storage. Upstream publishes no Docker image or releases yet, so a template has to build it from source at a fixed commit.

This template builds DataCat from a pinned upstream commit (2026-11-23), creates the admin and organization at deploy, and stores telemetry in ClickHouse 26.8, with Postgres 18 for app data. Both databases are private, with volumes.

## Common Use Cases

- A self-hosted Datadog alternative for small and medium teams
- Collecting OpenTelemetry traces, logs and metrics from apps on Railway or anywhere else
- Host metrics and log collection with the DataCat Agent on your Linux servers
- Metric, log and trace monitors with webhook or Slack alerts
- Keeping telemetry in your own databases, with a retention you choose

## Dependencies for DataCat Hosting

- PostgreSQL 18 (included)
- ClickHouse 26.8 (included)
- Railway volumes for both databases (included)

### Deployment Dependencies

- DataCat: https://github.com/replit/datacat
- Self-hosting guide: https://github.com/replit/datacat/blob/main/docs/SELF_HOSTING.md

### Implementation Details

**What you set:** nothing is required. The admin email defaults to `admin@example.com` (change `ADMIN_EMAIL` before deploying if you like) and the password is generated.

**After deploy:**

1. Open the DataCat URL and sign in with `ADMIN_EMAIL` and the `ADMIN_PASSWORD` variable of the `DataCat` service (Variables tab).
2. Under Organization Settings, create an API key.
3. Send data. For OpenTelemetry set `OTEL_EXPORTER_OTLP_ENDPOINT` to the DataCat URL, `OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf` and `OTEL_EXPORTER_OTLP_HEADERS=DC-API-KEY=your-key`. For a Linux host, run the installer from `/install.sh` on your DataCat URL with `DATACAT_API_KEY` set.
4. Invite your team under Users. Invite links work once and expire after 30 days.

**This template:**

- Builds DataCat from a pinned upstream commit, not from the moving main branch
- Creates the admin and organization on the first boot through DataCat's setup API, with a generated setup token, so a fresh instance can't be claimed by someone else
- Invite-only: DataCat has no public sign-up, and setup is closed once the admin exists
- Stores telemetry in ClickHouse (upstream's choice for large volumes: far less disk, faster long-range queries) and app data in Postgres 18, both private
- Builds the DataCat Agent for Linux amd64 and arm64 into the image, so the one-line installer works out of the box and checks the binary's SHA-256
- Generates the session secret and setup token, trusts Railway's proxy for real client IPs, and waits for both databases before starting
- Checks `/api/healthz` before switching traffic, and runs as a non-root user

**Notes:** the first build takes about 5 minutes. All intake is HTTPS on the one public domain: OTLP over HTTP (protobuf or JSON) and the Datadog-compatible routes. OTLP gRPC is not exposed; use HTTP, or a local Collector or the DataCat Agent, which accept gRPC and forward over HTTPS. There is no password reset by email, so keep the admin password safe. Telemetry is kept for 15 days by default (`DATACAT_RETENTION_DAYS`). DataCat is Apache-2.0 licensed. This template is not affiliated with or endorsed by Replit. DataCat is not affiliated with Datadog; Datadog is a trademark of Datadog, Inc.

## Why Deploy DataCat on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying DataCat on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
