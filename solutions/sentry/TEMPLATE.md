# Deploy and Host Sentry (self-hosted) on Railway

Sentry is the open-source error tracking platform used by millions of developers. It groups crashes and exceptions from your apps into issues, with stack traces, breadcrumbs, release and environment tags, and alerts. Its SDKs cover JavaScript, Python, Go, Java, Ruby, PHP, .NET, mobile and more. This template runs Sentry's official self-hosted release in its errors-only mode.

## About Hosting Sentry (self-hosted)

Self-hosted Sentry is a stack of about 20 containers: the Django web app, Relay (which receives events), Kafka, Snuba (Sentry's query service) with several consumers, ClickHouse, Postgres, Redis, Taskbroker and background workers. The official install is a docker-compose script that needs bind-mounted config files, a generated Relay keypair and a setup wizard. None of that maps to Railway directly, and the first visitor to an unfinished install can create the admin account.

This template groups the stack into 9 Railway services. The Sentry web app, its consumers and task workers share one service, and the Snuba query API and its consumers share another. All config is generated from variables. On first start the database and ClickHouse are migrated, Kafka topics are created and your admin account is created from a generated password, with public sign-up turned off. Relay creates its own credentials and registers over the private network, so nothing has to be copied by hand.

## Common Use Cases

- Error and crash tracking for web, backend and mobile apps with Sentry's own SDKs
- A self-hosted alternative to sentry.io, without per-event pricing, with data in your own Railway project
- Alerts on new or regressed issues, grouped by release and environment
- Keeping error data in your own infrastructure for privacy or compliance

## Dependencies for Sentry (self-hosted) Hosting

- Postgres 17, Redis 8, Apache Kafka 4.4 and ClickHouse 26.8 (all included, private)
- An app with a Sentry SDK to send errors

### Deployment Dependencies

- Sentry self-hosted: https://github.com/getsentry/self-hosted
- Errors-only mode: https://develop.sentry.dev/self-hosted/optional-features/errors-only/
- Sentry SDKs: https://docs.sentry.io/platforms/

### Implementation Details

**What you set:** `SENTRY_ADMIN_EMAIL` on the Sentry service, the email you log in with (default `admin@example.com`; change it to your own).

**After deploy:**

1. The first start takes about 5 to 10 minutes while Sentry migrates its database. Then open the Gateway URL.
2. Log in with `SENTRY_ADMIN_EMAIL` and the generated `SENTRY_ADMIN_PASSWORD` (Sentry service → Variables).
3. Create a project and copy its DSN into your app's Sentry SDK.

**This template:**

- Creates the admin at first start and turns off public sign-up, so no visitor can claim your instance
- Generates Relay's credentials on every start and trusts Relays only on the private network; the public gateway blocks Relay registration
- Keeps Postgres, Redis, Kafka, ClickHouse, Snuba and the web app private; only the gateway is public
- Runs database and ClickHouse migrations and creates Kafka topics on every start, so upgrades apply them
- Deletes events older than `SENTRY_EVENT_RETENTION_DAYS` (default 90) every day
- Pins Sentry, Snuba, Relay and Taskbroker 26.10.1

**Notes:** errors-only mode leaves out performance tracing, session replay, profiling, uptime and cron monitoring. Sentry is a heavy stack: it settles at about 8 GB of RAM across 9 services, so expect roughly $80 to $100 a month on Railway before you send much data.

## Why Deploy Sentry (self-hosted) on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Sentry (self-hosted) on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
