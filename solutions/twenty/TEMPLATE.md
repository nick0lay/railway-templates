# Deploy and Host Twenty on Railway

Twenty is an open-source CRM, a modern alternative to Salesforce and HubSpot. It tracks companies, people and opportunities, syncs email and calendars, and lets you add custom objects, fields, views and workflows. Everything is available through GraphQL and REST APIs.

## About Hosting Twenty

Twenty runs as a web server plus a background worker. It stores records in PostgreSQL, uses Redis for cache and job queues, and keeps uploaded files in storage that both processes can reach. In production it needs fixed secrets, Redis that never evicts queued jobs, and a pinned version, because Twenty migrates the database on start. On a fresh install, whoever opens the URL first creates the workspace and becomes admin.

This template creates your owner account and workspace at deploy, and runs Twenty with a worker, PostgreSQL, Redis and a Railway Bucket on Railway's private network.

## Common Use Cases

- Sales pipeline and deal tracking for small and mid-size teams
- Customer and contact database with custom objects and fields
- Email and calendar sync with Gmail or Microsoft 365
- Workflow automation on record changes and schedules
- A CRM backend for your own apps through the GraphQL and REST APIs

## Dependencies for Twenty Hosting

- PostgreSQL 18
- Redis 8
- Railway Bucket for files

### Deployment Dependencies

- Twenty: https://github.com/twentyhq/twenty
- Documentation: https://twenty.com/developers/section/self-hosting
- Image: https://hub.docker.com/r/twentycrm/twenty

### Implementation Details

**What you set:** `ADMIN_EMAIL`, the email you log in with. Everything else is generated.

**After deploy:**

1. Open the Twenty URL and log in with `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD`.
2. Invite your team under Settings → Members (set the SMTP variables to send invitation emails).
3. Create an API key under Settings → Developers for integrations.

**This template:**

- Creates the owner account and workspace on first start, so nobody else can claim your instance; other sign-ups need an invitation
- Runs a separate worker for background jobs and scheduled tasks
- Generates `APP_SECRET` and `ENCRYPTION_KEY` and shares them with the worker
- Configures Redis with `noeviction` and an append-only file on a volume, with no public port
- Stores files in a Railway Bucket shared by the server and worker
- Pins Twenty 2.57.1, PostgreSQL 18 and Redis 8.10, and turns off telemetry
- Checks health on `/healthz`

**Notes:** don't change `APP_SECRET` or `ENCRYPTION_KEY` after the first deploy. Upgrade by changing the image tag on both `twenty` and `twenty-worker`; Twenty migrates the database on start. Set `SERVER_URL` when you add a custom domain.

## Why Deploy Twenty on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Twenty on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
