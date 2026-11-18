# Deploy and Host Sure on Railway

Sure is an open-source personal finance app, the community successor of Maybe Finance. Track bank, investment, crypto, property and loan accounts in one place, see your net worth, set budgets and goals, categorise transactions with rules or AI, and import CSV files. Your financial data stays on your own server.

## About Hosting Sure

Sure is a Rails app that runs as a web server plus a Sidekiq worker. It keeps data in PostgreSQL, queues jobs in Redis and stores receipts and imports as files that both processes must reach. In production it needs fixed secrets shared by web and worker, HTTPS behind the proxy and a pinned version, because Sure migrates the database on start. On a fresh install, the first person to sign up becomes the admin.

This template creates your owner account at deploy, keeps sign-ups closed, and runs Sure with its worker, PostgreSQL, Redis and a Railway Bucket on Railway's private network, with every secret generated for you.

## Common Use Cases

- Household budgeting and spending tracking across several banks and currencies
- Net worth tracking with investments, crypto, property and loans
- A private replacement for Mint, YNAB or the discontinued Maybe Finance app
- AI-assisted categorisation and a finance chat assistant with your own OpenAI key
- Sharing one finance workspace with your partner or family

## Dependencies for Sure Hosting

- PostgreSQL 18
- Redis 8
- Railway Bucket for uploaded files

### Deployment Dependencies

- Sure: https://github.com/we-promise/sure
- Self-hosting guide: https://github.com/we-promise/sure/blob/main/docs/hosting/docker.md
- Image: https://github.com/we-promise/sure/pkgs/container/sure

### Implementation Details

**What you set:** `OWNER_EMAIL`, the email you log in with (default `admin@example.com`). `OWNER_PASSWORD` is generated. Optional: `OPENAI_ACCESS_TOKEN` for AI features, SMTP variables for password reset and invitation emails, `ONBOARDING_STATE` (`closed` by default, `invite_only` or `open`).

**After deploy:**

1. Open the Sure URL and log in with `OWNER_EMAIL` and the generated `OWNER_PASSWORD` (Variables tab of the Sure service).
2. Finish onboarding (name, household, currency).
3. To let family members join, switch Settings → Self-Hosting → Onboarding to Invite-only (or Open).
4. Add accounts and transactions, or import CSV files.

**This template:**

- Creates the owner (super admin) account on first start and keeps sign-ups closed, so nobody else can claim your instance
- Includes the Sidekiq worker that Sure needs for syncs, imports, exchange rates and scheduled jobs
- Generates `SECRET_KEY_BASE` and all three Active Record encryption keys once and shares them with the worker, so the worker can read the API keys the web app encrypted
- Pins Sure 0.7.6-hotfix.1, PostgreSQL 18 and Redis 8.10 instead of `latest`
- Keeps PostgreSQL and Redis on volumes, private, with no public TCP proxy
- Stores receipts, statements and imports in a Railway Bucket shared by web and worker
- Turns on HTTPS redirects and secure cookies behind Railway's proxy
- Checks health on `/up` and restarts crashed services
- Uses Yahoo Finance for exchange rates and prices (no key needed) and turns off Sure's anonymous product monitoring
- The Sidekiq dashboard at `/sidekiq` is visible only to the admin

**Notes:** never change `SECRET_KEY_BASE` or the `ACTIVE_RECORD_ENCRYPTION_*` keys after the first deploy, or encrypted data becomes unreadable. Upgrade by changing the image tag on both Sure and Sure Worker; back up Postgres first. Set `APP_DOMAIN` when you add a custom domain. Sure is licensed under AGPL-3.0: if you modify it and offer it to others over a network, you must share your source. Sure is not affiliated with Maybe Finance, Inc. You are responsible for your instance and the data in it.

## Why Deploy Sure on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Sure on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
