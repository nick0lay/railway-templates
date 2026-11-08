# Deploy and Host SigNoz on Railway

SigNoz is an open-source observability platform, an alternative to Datadog, New Relic and Grafana's LGTM stack. It shows traces, metrics and logs in one app, with service maps, dashboards, alerts and exception tracking, and it is native to OpenTelemetry: any app instrumented with an OpenTelemetry SDK can send data to it.

## About Hosting SigNoz

SigNoz has three parts: the SigNoz app (UI, query API and alerts), an OpenTelemetry collector that receives data, and ClickHouse, which stores it. ClickHouse needs a Keeper for SigNoz's replicated tables and SigNoz's histogram function, and the ClickHouse schema has to be created on the first start and migrated after upgrades. A fresh SigNoz lets the first visitor sign up as admin, and a public collector accepts data from anyone who finds the URL.

This template creates your admin account at deploy and turns off sign-up, protects the collector's OTLP endpoint with a generated token, and gives ClickHouse a password and no public endpoint. ClickHouse runs an embedded Keeper and the collector runs the schema migrations on every start, so the stack is three services, all on volumes or stateless, with pinned versions and healthchecks.

## Common Use Cases

- Distributed tracing and APM for services deployed on Railway or anywhere else
- Centralized logs with search, filters and log-to-trace links
- Application and infrastructure metrics with dashboards and alerts
- A self-hosted Datadog or New Relic alternative without per-host pricing
- Monitoring LLM and AI agent calls instrumented with OpenTelemetry

## Dependencies for SigNoz Hosting

- ClickHouse 25.12 (included, private)
- An app instrumented with OpenTelemetry to send data

### Deployment Dependencies

- SigNoz: https://github.com/SigNoz/signoz
- SigNoz OpenTelemetry collector: https://github.com/SigNoz/signoz-otel-collector
- Instrumentation guides: https://signoz.io/docs/instrumentation/

### Implementation Details

**What you set:** `SIGNOZ_USER_ROOT_EMAIL`, the email you log in with (default `admin@example.com`; change it to your own).

**After deploy:**

1. Open the SigNoz URL and log in with `SIGNOZ_USER_ROOT_EMAIL` and the generated `SIGNOZ_USER_ROOT_PASSWORD` (SigNoz service → Variables).
2. In your app, set `OTEL_EXPORTER_OTLP_ENDPOINT` and `OTEL_EXPORTER_OTLP_HEADERS` to the values in the Collector service's variables, and `OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf`.
3. Apps in the same Railway project can use the private gRPC or HTTP endpoint shown in the Collector variables, with the same token.

**This template:**

- Creates the admin at deploy and turns off public sign-up, so no visitor can claim your instance
- Requires a bearer token on the OTLP endpoint (HTTP and gRPC); requests without it get 401
- Keeps ClickHouse private and password-protected
- Runs ClickHouse with an embedded Keeper and installs SigNoz's histogram function
- Runs the ClickHouse schema migrations on every collector start, so upgrades apply them automatically
- Pins SigNoz v0.149.0, collector v0.144.15 and ClickHouse 25.12.11, with healthchecks on all three services

**Notes:** the stack idles at about 0.7 GB of RAM; ClickHouse memory and the volume grow with the data you send. SigNoz's default retention is set under Settings.

## Why Deploy SigNoz on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying SigNoz on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
