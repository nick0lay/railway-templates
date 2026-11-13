# Deploy and Host Lago on Railway

Lago is open-source billing and metering for usage-based, subscription and hybrid pricing, an alternative to Stripe Billing, Chargebee and Orb. It ingests usage events from your product, prices them with plans and charges (per unit, graduated, package, percentage, pay in advance), and issues invoices, credit notes, coupons and prepaid credits, with webhooks and integrations for Stripe, Adyen, GoCardless, HubSpot, Salesforce and accounting tools.

## About Hosting Lago

Self-hosted Lago is a web app, an API, background workers and a scheduler on PostgreSQL and Redis, plus a PDF renderer for invoices and file storage. Lago's standard self-hosted setup keeps usage events in Postgres, which slows down as volume grows; its high-volume pipeline (Kafka, an events processor and ClickHouse) isn't part of the standard setup. Every Lago service must share the same RSA signing key, and a fresh install lets anyone open the sign-up page and create an organization.

This template runs Lago's official images with the full high-volume pipeline: events go from the API through Kafka and Lago's events processor into ClickHouse, which computes usage and stores API and activity logs. It creates your organization and admin account at deploy, closes sign-up, generates a signing key per deploy, and keeps every database private on volumes. Invoice PDFs go to a Railway bucket, and every version is pinned and tested.

## Common Use Cases

- Usage-based billing for APIs, AI and infrastructure products: meter tokens, requests, compute or storage and bill per unit or by tier
- Subscriptions with usage add-ons, minimum commitments, prepaid credits and wallets
- Invoicing with taxes, coupons, credit notes and invoice PDFs, emailed to customers
- Real-time usage for customer dashboards and spending alerts through the API and webhooks
- A self-hosted Stripe Billing, Chargebee or Orb alternative with billing data on your own infrastructure

## Dependencies for Lago Hosting

- PostgreSQL 17 (with pg_partman)
- Redis 8
- ClickHouse 26.3
- Apache Kafka 4.4

### Deployment Dependencies

- Lago: https://github.com/getlago/lago
- Self-hosting docs: https://getlago.com/docs/guide/self-hosted/docker
- API reference and SDKs: https://getlago.com/docs/api-reference/intro

### Implementation Details

**What you set:** `LAGO_ORG_USER_EMAIL` (Lago API service), the email you log in with.

**After deploy:**

1. Open the Lago URL and log in with `LAGO_ORG_USER_EMAIL` and the generated `LAGO_ORG_USER_PASSWORD` (Lago API service → Variables).
2. Create a billable metric, a plan, a customer and a subscription.
3. Send usage events to `https://your-lago-api-domain/api/v1/events` with the organization's API key (`LAGO_ORG_API_KEY`).

**This template:**

- Runs Lago's high-volume event pipeline: API → Kafka → events processor → ClickHouse, with usage computed in ClickHouse
- Creates the organization and admin account at deploy and closes public sign-up
- Generates a signing key for logins and webhooks per deploy, shared by all Lago services through Postgres (no key baked into the template)
- Includes the worker, the scheduler (subscriptions bill on time), the PDF service and a Railway bucket for invoice files
- Keeps ClickHouse, Kafka, PostgreSQL, Redis and the PDF service private; the Sidekiq dashboard, which has no login, is off
- Runs on Railway's IPv6 private network
- Creates the Kafka topics and runs the Postgres and ClickHouse migrations on every start
- Pins Lago v1.57.0, ClickHouse 26.3 LTS, Kafka 4.4, PostgreSQL 17 and Redis 8.10

**Notes:** ten services and a bucket, so it needs more memory than a basic Lago setup; it is built for high event volumes. The first start takes a few minutes while the API runs the migrations. Invoice emails need SMTP settings; without them, everything else works.

## Why Deploy Lago on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Lago on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
