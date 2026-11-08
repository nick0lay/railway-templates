# Deploy and Host Teable on Railway

Teable is an open-source, no-code database with a spreadsheet interface, an alternative to Airtable. You build tables with grid, form, kanban, gallery and calendar views, link records between tables, add formulas, lookups and rollups, and work on the same base with your team in real time. Everything is available through a REST API, and the data lives in PostgreSQL.

## About Hosting Teable

Teable is a single Node.js service that stores every table in PostgreSQL and uses Redis for cache, sessions and queues. It keeps attachments on disk, so it needs a volume. It also needs several secrets: if they aren't set, Teable starts with publicly known default keys and warns about it in the logs. On a fresh install, the first person to sign up becomes the instance admin, and anyone can sign up after that.

This template creates your admin account at deploy, turns off public sign-up, generates every secret, and runs Teable with PostgreSQL and Redis on Railway's private network.

It uses Teable's official image, which includes the paid features. **Paid features stay locked until you add a license**; tables, views, forms, collaboration and the API work without one. For the open-source build only, deploy the Teable Community template instead.

## Common Use Cases

- Airtable replacement you host yourself, with your data in your own Postgres
- Project trackers, CRMs, inventories and content calendars for small teams
- Forms that collect data straight into a table
- A Postgres-backed database with a spreadsheet UI for non-developers
- A backend for internal tools and automations through the REST API

## Dependencies for Teable Hosting

- PostgreSQL 18
- Redis 8

### Deployment Dependencies

- Teable: https://github.com/teableio/teable
- Documentation: https://help.teable.ai/en/deploy/docker
- Image: https://github.com/teableio/teable/pkgs/container/teable

### Implementation Details

**What you set:** `ADMIN_EMAIL`, the email you log in with. Everything else is generated.

**After deploy:**

1. Open the Teable URL and log in with `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD`.
2. Create a base in the first space and start a table, or import a CSV or Excel file.
3. Invite your team by email from the space (set the email variables first), or turn sign-up back on under System Admin → Instance settings while they register.

**This template:**

- Creates the admin account and a first space on first start, then turns off public sign-up, so nobody else can claim your instance
- Generates `SECRET_KEY` and every encryption key and IV, so nothing runs on Teable's public default keys
- Keeps attachments on a volume
- Uses Redis for cache, sessions and queues, with an append-only file on a volume and no public port
- Pins the Teable release, PostgreSQL 18 and Redis 8.10, and turns off the self-hosted telemetry report
- Checks health on `/health`

**License:** Teable licenses aren't set through a variable. Open System Admin → Self-hosted license, copy the Instance ID, subscribe on Teable's self-hosted pricing page (https://app.teable.ai/public/pricing?host=self-hosted), then paste the License Key there. Without a license the instance runs the free feature set; an expired license falls back to it and keeps your data.

**Notes:** don't change `SECRET_KEY` or the encryption keys after the first deploy. Upgrade by changing the image tag; Teable migrates the database on start. Teable uses about 1.7 GB of RAM while idle.

## Why Deploy Teable on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Teable on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
