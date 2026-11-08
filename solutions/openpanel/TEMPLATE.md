# Deploy and Host OpenPanel on Railway

OpenPanel is open-source product and web analytics, an alternative to Mixpanel, Amplitude and Google Analytics. It tracks events from websites, apps and backends, and shows real-time dashboards, funnels, retention, user profiles and sessions. It can run without cookies, and its SDKs cover JavaScript, React, Next.js, React Native, iOS, Android and server-side languages.

## About Hosting OpenPanel

Self-hosted OpenPanel is three apps (an API that ingests events and serves the dashboard's backend, a web dashboard, and a worker that batches events into ClickHouse) with three databases: ClickHouse for events and profiles, PostgreSQL for users and projects, and Redis for queues. The apps need the Postgres and ClickHouse migrations run before they start, OpenPanel's defaults expect an IPv4 network, its login cookie is set for the parent domain (which browsers reject on shared hosting domains), and a fresh install lets the first visitor sign up as the admin.

This template runs OpenPanel's official images behind one public Caddy proxy. It creates your admin account at deploy, closes sign-up, pins the login cookie to your domain, and keeps all three databases private on volumes. The API runs migrations on every start, ClickHouse runs with small internal log tables, and every version is pinned and tested.

## Common Use Cases

- Product analytics for SaaS apps: events, funnels, retention and user profiles, without sending data to a third party
- Privacy-friendly web analytics for sites and blogs, with real-time visitors, pages, sources and countries
- Mobile app analytics with the React Native, iOS and Android SDKs
- Server-side event tracking from your backend with a client secret
- A self-hosted Mixpanel or Google Analytics alternative with your data on your own infrastructure

## Dependencies for OpenPanel Hosting

- ClickHouse 25.10
- PostgreSQL 17
- Redis 8

### Deployment Dependencies

- OpenPanel: https://github.com/Openpanel-dev/openpanel
- Self-hosting docs: https://openpanel.dev/docs/self-hosting/self-hosting
- SDKs: https://openpanel.dev/docs

### Implementation Details

**What you set:** `ADMIN_EMAIL`, the email you log in with.

**After deploy:**

1. Open the OpenPanel URL and log in with `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD` (API service → Variables).
2. Create an organization and a project, and copy the client ID (and secret for app/backend projects).
3. Add the SDK to your site or app with `apiUrl: 'https://<your OpenPanel domain>/api'`.

**This template:**

- Creates the admin account at deploy and closes public sign-up; teammates join by invitation
- Pins the login cookie to your dashboard's host, so login works on `*.up.railway.app`
- Runs on Railway's IPv6 private network (API on `::`, Redis client with `family=0`)
- Keeps ClickHouse, PostgreSQL and Redis private, with no public domain or TCP proxy
- Runs the Postgres and ClickHouse migrations on every start, so upgrades need no manual step
- Tunes ClickHouse for a small service: high-volume internal logs off, fewer query threads
- Routes `/api` to the API and everything else to the dashboard through one domain, keeping the visitor's real IP for geolocation
- Pins OpenPanel 2.3.0, ClickHouse 25.10, PostgreSQL 17, Redis 8.10 and Caddy 2.10

**Notes:** the seven services idle at about 1.7 GB of RAM together. Email (invitations, password resets) needs a Resend API key; without it, everything else works. For a custom domain, update `DASHBOARD_URL`, `API_URL` and `CUSTOM_COOKIE_DOMAIN` (see the README).

## Why Deploy OpenPanel on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying OpenPanel on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
