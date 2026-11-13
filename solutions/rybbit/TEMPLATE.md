# Deploy and Host Rybbit on Railway

Rybbit is open-source, privacy-friendly web and product analytics, an alternative to Google Analytics. It shows real-time visitors, pages, sources, countries and devices, plus custom events, goals, funnels, user journeys, retention, session replay and web vitals. It uses no cookies by default, and one script tag (about 2 KB) adds a site.

## About Hosting Rybbit

Self-hosted Rybbit is a Node.js backend that ingests events and serves the API, a Next.js dashboard, and three databases: ClickHouse for events, PostgreSQL for users, organizations and sites, and Redis for sessions and bot detection. The dashboard expects the API on the same domain under `/api`, the prebuilt images listen on IPv4 only, and a fresh install lets the first visitor sign up and take over.

This template runs Rybbit's official images behind one public Caddy proxy. It creates your admin account at deploy and keeps sign-up closed, makes the backend and dashboard work on Railway's IPv6 private network, and keeps all three databases private on volumes. ClickHouse uses our tested settings (small internal log tables) and every version is pinned.

## Common Use Cases

- Privacy-friendly web analytics for websites, blogs and docs, without a cookie banner
- Product analytics for SaaS apps: custom events, goals, funnels, retention and user journeys
- Session replay and web vitals to see how visitors use a page and how fast it loads
- One dashboard for many sites, with teammates per organization and public or private dashboards
- A self-hosted Google Analytics or Plausible alternative with your data on your own infrastructure

## Dependencies for Rybbit Hosting

- ClickHouse 26.8
- PostgreSQL 17
- Redis 8

### Deployment Dependencies

- Rybbit: https://github.com/rybbit-io/rybbit
- Self-hosting docs: https://rybbit.com/docs/self-hosting
- Tracking script docs: https://rybbit.com/docs/script

### Implementation Details

**What you set:** `ADMIN_EMAIL` on the Backend service, the email you sign in with.

**After deploy:**

1. Open the Rybbit URL and sign in with `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD` (Backend service → Variables).
2. Create an organization, add your site's domain, and copy the tracking snippet.
3. Paste the snippet into the head of your site. It loads `https://your-rybbit-domain/api/script.js` with your site id.

**This template:**

- Creates the admin account at deploy on a private port and keeps public sign-up closed; you add teammates in the organization settings
- Serves the dashboard and API on one domain, as Rybbit expects, and keeps the visitor's real IP for countries and cities
- Runs on Railway's IPv6 private network (backend and dashboard on `::`, Redis client with IPv6 lookup)
- Keeps ClickHouse, PostgreSQL and Redis private, with no public domain or TCP proxy
- Runs the Postgres migrations on every start, so upgrades need no manual step
- Tunes ClickHouse for a small service: high-volume internal logs off, async inserts as Rybbit recommends
- Pins Rybbit 2.9.2, ClickHouse 26.8, PostgreSQL 17, Redis 8.10 and Caddy 2.11

**Notes:** the six services idle at about 1.7 GB of RAM together. The globe map needs a free Mapbox token (`MAPBOX_TOKEN` on the Backend); everything else works without it. For a custom domain, update `BASE_URL` (see the README).

## Why Deploy Rybbit on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Rybbit on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
