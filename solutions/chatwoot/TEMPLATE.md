# Deploy and Host Chatwoot on Railway

Chatwoot is an open-source customer support inbox, an alternative to Intercom and Zendesk. It brings website live chat, email, WhatsApp, Facebook, Instagram, Telegram, SMS and API channels into one shared inbox, with agents, teams, canned replies, automations, a help center and reports.

## About Hosting Chatwoot

Chatwoot is a Rails app with a Sidekiq background worker, PostgreSQL with the pgvector extension, and Redis. The database schema has to be loaded on the first start and migrated after every upgrade. A fresh install also opens a public setup page where the first visitor creates the super admin, so the admin account should exist before the URL is shared. Attachments stored on disk must be visible to both the web server and the worker: if each has its own volume, files that the worker saves (incoming email and messaging attachments) can't be served.

This template prepares the database on every start, creates your admin account at deploy and closes the setup page, keeps sign-up off, and runs Rails and Sidekiq in one service so they share the attachments volume. PostgreSQL and Redis are private, on volumes, and every version is pinned and tested.

## Common Use Cases

- Live chat on your website, with replies from a shared team inbox
- One inbox for support email, WhatsApp, Instagram, Facebook and Telegram
- A self-hosted Intercom or Zendesk alternative with no per-agent fees
- A help center (knowledge base) on your own domain
- An inbox for AI or bot replies through Chatwoot's API and webhooks

## Dependencies for Chatwoot Hosting

- PostgreSQL 16 with pgvector
- Redis 8

### Deployment Dependencies

- Chatwoot: https://github.com/chatwoot/chatwoot
- Self-hosting docs: https://developers.chatwoot.com/self-hosted
- Environment variables: https://developers.chatwoot.com/self-hosted/configuration/environment-variables

### Implementation Details

**What you set:** `ADMIN_EMAIL`, the email you sign in with. Optionally `ACCOUNT_NAME` (your company or team) and `ADMIN_NAME`.

**After deploy:**

1. Open the Chatwoot URL and sign in with `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD` (Chatwoot service → Variables).
2. Add an inbox under Settings → Inboxes. For website chat, choose Website and paste the script into your site.
3. Invite agents under Settings → Agents. To send invitations and notifications by email, add SMTP variables (see the README).

**This template:**

- Creates the admin account at deploy and closes the public first-run setup page, so no visitor can claim your instance
- Keeps sign-up off: new agents join only by invitation
- Loads the schema on the first start and runs migrations after every image upgrade
- Runs Rails and Sidekiq in one service, so both see the attachments volume
- Keeps PostgreSQL and Redis private, with no public TCP proxy
- Generates the Rails secret and the encryption keys that two-factor sign-in needs
- Pins Chatwoot v4.19.1 (Community Edition), pgvector 0.8.7 on PostgreSQL 16 and Redis 8.2, with a healthcheck on `/api`

**Notes:** the three services idle at about 1.3 GB of RAM together. Email needs an SMTP provider; without one, everything else works, but invitations and password-reset emails are not sent.

## Why Deploy Chatwoot on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Chatwoot on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
