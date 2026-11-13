# Lago

Self-hosted [Lago](https://www.getlago.com) on Railway: open-source billing and metering, an alternative to Stripe Billing, Chargebee and Orb. It meters usage events, prices them with plans and charges (per unit, graduated, package, percentage, pay in advance), and issues invoices, credit notes, coupons and prepaid credits. This template runs Lago's official images with the high-volume event pipeline that the standard self-hosted setup leaves out: events go through Kafka and Lago's events processor into ClickHouse. The admin account is created at deploy and sign-up is closed, so nobody can claim your instance, each deploy gets its own signing key, and every version is pinned and tested.

## Architecture

```
       You (web app)                    Your backend (REST API, SDKs, webhooks)
             │ HTTPS                                    │ HTTPS
             ▼                                          ▼
┌───────────────────────────────────────────────────────────────────────┐
│ Railway project                                                       │
│                                                                       │
│  Lago (web app) :8080  public ─────────►  Lago API :3000  public      │
│                                             │  REST, GraphQL, events  │
│                                             ▼                         │
│                       Kafka :9092 ◄──── events_raw ────┐              │
│                         │    ▲                         │              │
│                         │    └── events_enriched ── Events Processor  │
│                         ▼                                             │
│                 ClickHouse :8123   events, usage, API/activity logs   │
│                                                                       │
│  Lago Worker  (Sidekiq jobs + Kafka consumer: invoices, webhooks,     │
│                pay-in-advance charges)                                │
│  Lago Clock   (scheduled billing runs)       PDF :3000 (invoice PDFs) │
│                                                                       │
│  Postgres :5432          Redis :6379           Bucket (S3)            │
│  customers, plans,       jobs and cache        invoice files          │
│  invoices; volume        volume                                       │
│  (everything except Lago and Lago API is private)                     │
└───────────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Lago | `getlago/front:v1.57.0` | Web app (login required), public |
| Lago API | `getlago/api:v1.57.0` | REST and GraphQL API, event ingestion, migrations on start, public |
| Lago Worker | `getlago/api:v1.57.0` | Sidekiq background jobs and the Kafka consumer for pay-in-advance charges |
| Lago Clock | `getlago/api:v1.57.0` | Scheduler: billing runs, subscription renewals, usage refresh |
| Events Processor | `getlago/lago-events-processor:v1.57.0` | Reads raw events from Kafka, matches them to subscriptions and charges, writes enriched events back for ClickHouse |
| PDF | `ghcr.io/getlago/lago-gotenberg:8.39` | Renders invoice PDFs (private) |
| ClickHouse | `solutions/clickhouse/clickhouse` (ClickHouse 26.3 LTS) | Event store, usage aggregation, API and activity logs (private, volume) |
| Kafka | `apache/kafka:4.4.0` | Event stream between the API, the events processor and ClickHouse (private, volume) |
| Postgres | `solutions/lago/postgres` (Railway's Postgres 17 image + pg_partman) | Customers, plans, subscriptions, invoices (private, volume) |
| Redis | `redis:8.10` | Job queues and cache (private, volume) |
| Bucket | Railway Bucket | Invoice PDFs and other files (S3) |

## What this template does differently

- **The high-volume event store.** Lago's standard self-hosted setup keeps events in Postgres, which slows down as usage grows. This template turns on the ClickHouse event store from Lago's own code base: the API writes events to Kafka, Lago's events processor enriches them, and ClickHouse consumes both topics directly. Current usage and invoices are computed in ClickHouse. API logs, activity logs and security logs are stored there too.
- **No one can claim your instance.** On a fresh Lago, anyone who opens the sign-up page can create an organization. This template creates the organization and the admin user from `LAGO_ORG_USER_EMAIL` and a generated `LAGO_ORG_USER_PASSWORD`, and closes sign-up (`LAGO_DISABLE_SIGNUP=true`).
- **Your own signing key.** Lago signs logins and webhooks with an RSA key. Other Lago templates ship one shared key in the template, so anyone can forge webhooks for every deploy. Here the first service to start generates a key and stores it in Postgres, and the API, worker and clock all read it from there. You can also set your own (`LAGO_RSA_PRIVATE_KEY`).
- **The whole application.** Background jobs (Worker), scheduled billing runs (Clock), invoice PDFs (PDF) and file storage (Bucket) are all included and wired up. Without the clock, subscriptions never bill; without the PDF service and storage, invoices have no PDF.
- **Works on Railway's IPv6 private network.** The API listens on `::` (IPv4 and IPv6), and Kafka advertises its private Railway hostname.
- **Postgres with pg_partman.** Lago's database schema needs the pg_partman extension, which Railway's Postgres image doesn't include; this template adds it to Railway's Postgres 17 image.
- **Private databases.** ClickHouse, Kafka, Postgres, Redis and the PDF service have no public domain or TCP proxy. The Sidekiq dashboard, which has no login, is off.
- **Migrations on every start.** The API creates the Kafka topics and runs the Postgres and ClickHouse migrations before it starts, so upgrades need no manual step.
- **Pinned versions.** Lago v1.57.0 for all Lago images, ClickHouse 26.3 LTS (ClickHouse 26.8 rejects some of the tables Lago creates), Kafka 4.4, PostgreSQL 17, Redis 8.10. Usage analytics sent to Lago are off.

## After deploy

1. Open the **Lago** service URL and log in with `LAGO_ORG_USER_EMAIL` and the `LAGO_ORG_USER_PASSWORD` variable (Lago API service → Variables). The API takes a few minutes on the first start while it runs the migrations.
2. Change your password in your profile. Add teammates in **Settings → Members**.
3. Create a billable metric, a plan with a charge for it, a customer and a subscription (in the web app or with the API).
4. Send usage events from your backend with the organization's API key (`LAGO_ORG_API_KEY`, also under **Developers → API keys**):

   ```bash
   curl -X POST "https://<your Lago API domain>/api/v1/events" \
     -H "Authorization: Bearer $LAGO_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"event": {"transaction_id": "tx_0001", "external_subscription_id": "sub_123",
                    "code": "api_calls", "properties": {"count": 3}}}'
   ```

   SDKs for Node.js, Python, Ruby, Go and PHP are listed in the [API docs](https://getlago.com/docs/api-reference/intro). Use `https://<your Lago API domain>` as the API URL.
5. Add a webhook endpoint under **Developers → Webhooks** to receive invoices and alerts. Webhooks are signed with your deploy's RSA key; the public key is at `GET /api/v1/webhooks/public_key`.

## Email (optional)

Lago emails invoices and credit notes to customers when SMTP is set. Set `LAGO_FROM_EMAIL`, `LAGO_SMTP_ADDRESS`, `LAGO_SMTP_PORT`, `LAGO_SMTP_USERNAME` and `LAGO_SMTP_PASSWORD` on Lago API and redeploy Lago API, Lago Worker and Lago Clock. Without them, everything else works.

## Variables

The Lago API service holds the settings. Lago Worker and Lago Clock reference them (`${{Lago API.…}}`), so change a value on Lago API and redeploy all three.

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Lago API | `LAGO_ORG_NAME` | `Lago` | Name of the organization created on the first start |
| Lago API | `LAGO_ORG_USER_EMAIL` | `admin@example.com` | Admin login. Set your own before deploy |
| Lago API | `LAGO_ORG_USER_PASSWORD` | generated | Read it after deploy. Applied only when the user is created on the first start |
| Lago API | `LAGO_ORG_API_KEY` | generated | API key of the organization |
| Lago API | `LAGO_DISABLE_SIGNUP` | `true` | `false` lets anyone create an organization |
| Lago API | `LAGO_FROM_EMAIL`, `LAGO_SMTP_*` | empty | Email, optional |
| Lago API | `LAGO_RSA_PRIVATE_KEY` | empty | Base64 PEM RSA key. Empty = generated on the first start and stored in Postgres (`railway.template_secrets`) |
| Lago API | `LAGO_API_URL`, `LAGO_FRONT_URL` | Railway domains | Change for custom domains (below) |
| Lago API | `LAGO_DISABLE_PDF_GENERATION` | `false` | `true` skips invoice PDFs |
| Lago API | `LAGO_DEFAULT_EVENT_STORE` | `clickhouse` | Event store for organizations created later. `postgres` uses Lago's standard store |
| Lago Worker | `SIDEKIQ_CONCURRENCY` | `10` | Background job threads |
| Kafka | `KAFKA_LOG_RETENTION_HOURS` | `168` | How long Kafka keeps events (ClickHouse keeps them for good) |
| ClickHouse | `CLICKHOUSE_IMAGE_TAG` | `26.3` | ClickHouse version. Lago v1.57 migrations fail on 26.8, and ClickHouse can't be downgraded

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Lago API | `SECRET_KEY_BASE`, `LAGO_ENCRYPTION_*` | generated | Rails secret and database encryption keys. Changing the encryption keys makes stored secrets (integration credentials) unreadable |
| Lago API | `DATABASE_URL`, `REDIS_URL`, `LAGO_REDIS_CACHE_URL` | from Postgres and Redis | Private network |
| Lago API | `LAGO_CLICKHOUSE_*` | from ClickHouse | ClickHouse event store and migrations |
| Lago API | `LAGO_KAFKA_BOOTSTRAP_SERVERS`, `LAGO_KAFKA_*_TOPIC`, `LAGO_KAFKA_CLICKHOUSE_CONSUMER_GROUP` | from Kafka, topic names | ClickHouse tables are created with these names. Changing a topic after the first start breaks the pipeline |
| Lago API | `LAGO_AWS_S3_*`, `LAGO_USE_AWS_S3` | from the Bucket | File storage |
| Lago API | `LAGO_PDF_URL` | PDF private host | Invoice PDFs |
| Lago API | `LAGO_SIDEKIQ_WEB` | `false` | The Sidekiq dashboard has no login |
| Lago API, Worker, Clock | `LAGO_ROLE`, `LAGO_RUN_SH` | `api`/`worker`/`clock`, script | Start script: signing key, topics, migrations, organization, process |
| Lago | `API_URL`, `PORT` | Lago API domain, `8080` | Where the web app sends requests |
| Events Processor | `LAGO_KAFKA_*`, `LAGO_REDIS_*`, `DATABASE_URL` | from Lago API and Redis | Same topics and databases as the API |
| ClickHouse | `CLICKHOUSE_USER`, `CLICKHOUSE_PASSWORD`, `CLICKHOUSE_DB` | `lago`, generated, `lago` | ClickHouse account and database |
| Kafka | `KAFKA_RUN_SH`, `KAFKA_BOOTSTRAP_SERVERS` | script, private host | Single-node KRaft broker on the private network |
| Postgres, Redis | `POSTGRES_PASSWORD`, `REDIS_PASSWORD` | generated | Database passwords |

## Custom domain

Add the domain for the web app to the **Lago** service and one for the API to **Lago API** (for example `billing.example.com` and `billing-api.example.com`). Then set `LAGO_FRONT_URL=https://billing.example.com` and `LAGO_API_URL=https://billing-api.example.com` on Lago API, `API_URL=https://billing-api.example.com` on Lago, and redeploy Lago, Lago API, Lago Worker and Lago Clock.

## Upgrading

Change the tag on all five Lago services together (Lago, Lago API, Lago Worker, Lago Clock and Events Processor use `v1.57.0`), for example to `v1.58.0`, and redeploy; the API runs the Postgres and ClickHouse migrations on start. Read the [release notes](https://github.com/getlago/lago/releases) first, and back up Postgres and ClickHouse before upgrading.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Lago API is still deploying after a few minutes | The first start waits for Postgres, Kafka and ClickHouse, then runs several hundred migrations. Watch its logs; `lago-api: waiting for …` names what it waits for |
| Login fails with the generated password | The admin is created on the first start only. If you changed `LAGO_ORG_USER_PASSWORD` later, use the old value |
| Current usage stays at 0 after sending events | Check that Events Processor and Kafka are running. Events reach ClickHouse through Kafka within a few seconds; the events processor drops events whose `external_subscription_id` or `code` doesn't match an active subscription and billable metric (they go to the `events_dead_letter` topic) |
| Webhook signatures don't verify after a redeploy | The signing key is in Postgres (`railway.template_secrets`). If you set `LAGO_RSA_PRIVATE_KEY`, every Lago service must see the same value |
| Invoices have no PDF | Check the PDF service and the Bucket variables on Lago API |
| `signup_disabled` on the sign-up page | Sign-up is closed on purpose. Add people under Settings → Members, or set `LAGO_DISABLE_SIGNUP=false` on Lago API and Lago |

## License

Lago is [AGPL-3.0](https://github.com/getlago/lago/blob/main/LICENSE). ClickHouse, Kafka and Gotenberg are Apache-2.0, PostgreSQL is the PostgreSQL License, Redis is RSALv2/SSPLv1/AGPLv3.

## Testing

Tested on 2026-11-13 with Lago v1.57.0 in a throwaway Railway project deployed from the template (Postgres with pg_partman installed at start, the same Railway Postgres 17 image as `solutions/lago/postgres`). All ten services were healthy about seven minutes after deploy; the API created the Kafka topics, ran the Postgres and ClickHouse migrations and seeded the organization on the first start. The web app pointed at the API and hid sign-up; a stranger's sign-up and a wrong password were refused, and the admin logged in. With the organization's API key, a billable metric, a plan with a usage charge, a customer and a subscription were created; two events went through Kafka and the events processor into ClickHouse within seconds, and current usage showed 7 units and $3.50. Terminating the subscription produced a finalized $3.50 invoice whose PDF was rendered and stored in the bucket. The Sidekiq dashboard returned 404, and only Lago and Lago API had public domains. After redeploying Lago API, Worker, Clock, Events Processor, ClickHouse, Kafka and Postgres, the admin still logged in, the webhook signing key was unchanged, and the full flow passed again (23/23 checks). ClickHouse 26.8 was also tried: it refuses one of Lago's ClickHouse migrations, so the template pins 26.3 LTS. Not tested: email, payment provider integrations, webhooks to an external endpoint, and the web app UI in a real browser (only its pages and API).
