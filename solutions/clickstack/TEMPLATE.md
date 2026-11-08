# Deploy and Host ClickStack on Railway

ClickStack is ClickHouse's open-source observability stack: the HyperDX UI for logs, traces, metrics and session replays, an OpenTelemetry collector, and ClickHouse for storage. It is an alternative to Datadog, New Relic and Elastic, with fast full-text and SQL search over all your telemetry, and it is native to OpenTelemetry: any app instrumented with an OpenTelemetry SDK can send data to it.

## About Hosting ClickStack

ClickStack has four parts: HyperDX (UI, API and alerts), an OpenTelemetry collector that receives data and gets its pipeline from HyperDX over OpAMP, ClickHouse, which stores the data, and MongoDB for users, dashboards and alerts. A fresh HyperDX lets the first visitor create the admin account, and the databases need passwords and must stay off the public internet.

This template creates your admin account at deploy so sign-up is closed, turns on API-key authentication for the collector's OTLP endpoint, and keeps ClickHouse and MongoDB private and password-protected. Versions are pinned, the services listen on Railway's IPv6 private network, and ClickHouse keeps its own system logs small.

## Common Use Cases

- Centralized logs with fast search, filters and log-to-trace links
- Distributed tracing and APM for services on Railway or anywhere else
- Application metrics with dashboards and alerts
- Frontend session replay correlated with backend traces
- A self-hosted Datadog, New Relic or Elastic alternative on ClickHouse

## Dependencies for ClickStack Hosting

- ClickHouse 26.8 and MongoDB 7.0 (included, private)
- An app instrumented with OpenTelemetry to send data

### Deployment Dependencies

- HyperDX: https://github.com/hyperdxio/hyperdx
- ClickStack documentation: https://clickhouse.com/docs/use-cases/observability/clickstack
- OpenTelemetry instrumentation: https://opentelemetry.io/docs/languages/

### Implementation Details

**What you set:** `HYPERDX_ADMIN_EMAIL`, the email you log in with (default `admin@example.com`; change it to your own).

**After deploy:**

1. Open the HyperDX URL and log in with `HYPERDX_ADMIN_EMAIL` and the generated `HYPERDX_ADMIN_PASSWORD` (HyperDX service → Variables).
2. In HyperDX, open Team Settings and copy the ingestion API key.
3. In your app, set `OTEL_EXPORTER_OTLP_ENDPOINT` to the Collector's `OTEL_EXPORTER_OTLP_ENDPOINT` variable, `OTEL_EXPORTER_OTLP_HEADERS=authorization=<API key>` and `OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf`. Apps in the same Railway project can use the private endpoints in the Collector variables.

**This template:**

- Creates the admin at deploy; HyperDX allows one team, so nobody else can sign up
- Requires your team's API key on the OTLP endpoint (HTTP and gRPC); requests without it get 401
- Keeps ClickHouse and MongoDB private and password-protected
- Sets up the ClickHouse connection and the Logs, Traces, Metrics and Sessions sources on the first start
- Keeps ClickHouse system logs to 3 days and turns off the noisy ones
- Pins HyperDX 2.43.1, ClickHouse 26.8.36.3 and MongoDB 7.0.45, with healthchecks

**Notes:** the stack idles at about 1.5 GB of RAM; ClickHouse memory and the volume grow with the data you send. Telemetry is kept for 30 days by default.

## Why Deploy ClickStack on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying ClickStack on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
