# Rybbit

Self-hosted [Rybbit](https://rybbit.com) on Railway: open-source, privacy-friendly web and product analytics, an alternative to Google Analytics, with real-time visitors, custom events, goals, funnels, user journeys, retention, session replay and web vitals. This template runs Rybbit's official images (backend and dashboard) with ClickHouse, PostgreSQL and Redis behind one Caddy proxy. The admin account is created at deploy, so nobody can claim your instance, all databases are private, and every version is pinned and tested.

## Architecture

```
          You (dashboard)                 Your sites and apps (script, SDKs)
                 │ HTTPS                               │ HTTPS  /api/script.js, /api/track
                 ▼                                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Railway project                                                     │
│                                                                     │
│  Rybbit (Caddy) :8080  public                                       │
│     /api/*  ──────────────►  Backend :3001   tracking, API, auth,   │
│     /*      ──────────────►  Client :3002    migrations / dashboard │
│                                                                     │
│  ClickHouse :8123      Postgres :5432          Redis :6379          │
│  events                users, organizations,   sessions, bot        │
│  volume                sites; volume           detection; volume    │
│  (all private)                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Rybbit | `caddy:2.11.9-alpine` | Public entry point: `/api` goes to the backend, everything else to the dashboard |
| Backend | `ghcr.io/rybbit-io/rybbit-backend:v2.9.2` | Tracking script and event ingestion, API, login, database migrations |
| Client | `ghcr.io/rybbit-io/rybbit-client:v2.9.2` | Web dashboard (login required) |
| ClickHouse | `clickhouse/clickhouse-server:26.8.36.3` | Events (private) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:17` | Users, organizations, sites, settings (private) |
| Redis | `redis:8.10.3-alpine` | Sessions, visitor identity, bot detection counters (private, `noeviction`) |

## What this template does differently

- **No one can claim your instance.** On a fresh Rybbit, anyone who opens `/signup` first gets an account. This template creates the admin from `ADMIN_EMAIL` and a generated `ADMIN_PASSWORD` on the first start, while the backend listens on localhost only, then starts it with sign-up closed (`DISABLE_SIGNUP=true`). You add teammates yourself in the organization settings.
- **One domain, as Rybbit expects.** The prebuilt dashboard calls the API at `/api` on its own domain, so a Caddy proxy serves both and passes on the visitor IP Railway forwards, for countries and cities.
- **Works on Railway's IPv6 private network.** The prebuilt backend listens on `0.0.0.0` and its Redis client looks up IPv4 addresses only. The start script switches the backend to `::` and the Redis lookup to IPv4 and IPv6; the dashboard listens on `::` too.
- **Private databases.** ClickHouse, Postgres and Redis have no public domain or TCP proxy.
- **Pinned versions.** Rybbit v2.9.2 instead of `latest`, and the ClickHouse 26.8 LTS release our ClickHouse template uses.
- **ClickHouse tuned for a small service.** High-volume internal log tables are off or kept for a few days, and inserts are batched (`async_insert`) as Rybbit recommends.
- **Migrations on every start.** The backend runs the Postgres migrations and creates its ClickHouse tables before it starts, so upgrades need no manual step.

## After deploy

1. Open the Rybbit URL and sign in with `ADMIN_EMAIL` and the `ADMIN_PASSWORD` variable (Backend service → Variables).
2. Create an organization, then add your site's domain. Rybbit shows the site ID.
3. Add the tracking script to every page of your site:

   ```html
   <script src="https://<your Rybbit domain>/api/script.js?siteId=<site id>" defer></script>
   ```

   Custom events: `window.rybbit.event("signup", { plan: "pro" })`. Server-side, apps and SDKs send events to `POST https://<your Rybbit domain>/api/track`; see the [docs](https://rybbit.com/docs).
4. Change your password in the account settings.
5. Add teammates in the organization settings with **Create user** (email, password and role). Self-hosted Rybbit sends no email, so pass the password on yourself.

Bot blocking is on for new sites, so visits from scripts and data centers are filtered out. If test hits from your own tools don't show up, that's why; turn it off in the site settings if you need them.

## Optional settings

Set these on the **Backend** service and redeploy it:

- `MAPBOX_TOKEN`: a free [Mapbox](https://www.mapbox.com) token for the globe and map views. Without it, everything else works.
- `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET`, `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET`: social login.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Backend | `ADMIN_EMAIL` | `admin@example.com` | Email of the admin account. Set your own before deploying |
| Backend | `ADMIN_PASSWORD` | generated | Read it after deploy. Used only when the admin is created on the first start |
| Backend | `DISABLE_SIGNUP` | `true` | `false` lets anyone sign up |
| Backend | `BASE_URL` | Railway domain | Change it when you add a custom domain |
| Backend | `CLUSTER_WORKERS` | `2` | API worker processes. More handle more traffic and use more memory |
| Backend | `DISABLE_TELEMETRY` | `true` | Don't send anonymous usage statistics to Rybbit |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Backend | `BETTER_AUTH_SECRET` | generated | Signs login sessions. Changing it logs everyone out |
| Backend | `POSTGRES_*`, `CLICKHOUSE_*`, `REDIS_*` | from the database services | Private network |
| Backend | `CLICKHOUSE_QUERY_PASSWORD` | generated | Read-only ClickHouse user Rybbit creates for custom queries |
| Backend | `PORT` | `3001` | Railway's healthcheck port |
| Backend | `BACKEND_RUN_SH` | script | Start script: network patches, admin account, official entrypoint |
| Client | `HOSTNAME`, `PORT` | `::`, `3002` | Listen on IPv6 and IPv4 |
| Rybbit | `CADDYFILE`, `BACKEND_UPSTREAM`, `CLIENT_UPSTREAM`, `PORT` | config | Routing |
| ClickHouse | `CLICKHOUSE_USER`, `CLICKHOUSE_PASSWORD`, `CLICKHOUSE_DB` | `default`, generated, `analytics` | Rybbit always connects as `default` |
| ClickHouse | `CLICKHOUSE_RUN_SH` | script | Small log tables and Rybbit's ClickHouse settings |
| Postgres, Redis | `POSTGRES_PASSWORD`, `REDIS_PASSWORD` | generated | Database passwords |

## Custom domain

Add the domain to the **Rybbit** service, set `BASE_URL=https://analytics.example.com` on the Backend and redeploy it. Update the script tags on your sites to the new domain.

## Upgrading

Change the tag of both Rybbit images together (Backend and Client), for example `ghcr.io/rybbit-io/rybbit-backend:v2.9.3`, and redeploy; the backend runs the migrations on start. Read the [release notes](https://github.com/rybbit-io/rybbit/releases) first, and back up Postgres and ClickHouse before a major version. The start script checks that its two network patches still apply and stops with a clear log line if a new version changed the code they touch.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Sign-in fails with the generated password | The admin is created on the first start only. If you changed `ADMIN_PASSWORD` later, use the old value |
| `/signup` shows a form but sign-up fails | Sign-up is closed (`DISABLE_SIGNUP=true`). Create users in the organization settings |
| Events are accepted but don't appear | Bot blocking filtered them (scripts, curl, data-center IPs), or the site's domain doesn't match the page. Check the site settings |
| Backend log: `listen patch failed` or `redis patch failed` | A new Rybbit version changed the code the start script patches. Go back to the previous image tag and open an issue |
| Everything shows one country | The visitor IP isn't passed on. Don't put another proxy in front without forwarding `X-Forwarded-For` |

## License

Rybbit is [AGPL-3.0](https://github.com/rybbit-io/rybbit/blob/master/LICENSE.md). ClickHouse is Apache-2.0, Caddy is Apache-2.0, Redis is RSALv2/SSPLv1/AGPLv3.

## Testing

Tested on 2026-11-13 with Rybbit v2.9.2 in a throwaway Railway project deployed from the template. All six services were healthy about two minutes after deploy; the migrations ran and the admin account was created on the first start. Sign-up was closed (`/api/config` reported it, and a stranger's sign-up was refused), and a wrong password was refused. The admin signed in with the system admin role, created an organization and a site, and the tracking script was served from `/api/script.js`. A pageview sent to `/api/track` was stored in ClickHouse and counted on the site overview within seconds (bot blocking turned off for the test site, since a scripted request counts as a bot). After redeploying all six services, the admin account was not created again, the admin signed in, the earlier pageview was still counted, and new events were ingested (15/15 checks). At idle the six services used about 1.7 GB of RAM together, most of it the backend's two worker processes. Not tested: the dashboard UI in a real browser (only its page and the API), session replay, the globe map (needs a Mapbox token), social login and visitor geolocation.
