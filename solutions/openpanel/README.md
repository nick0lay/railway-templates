# OpenPanel

Self-hosted [OpenPanel](https://openpanel.dev) on Railway: open-source product and web analytics, an alternative to Mixpanel and Google Analytics, with events, funnels, retention, user profiles and real-time dashboards. This template runs OpenPanel's official images (API, dashboard, worker) with ClickHouse, PostgreSQL and Redis behind one Caddy proxy. The admin account is created at deploy, so nobody can claim your instance, all databases are private, and every version is pinned and tested.

## Architecture

```
          You (dashboard)                 Your sites, apps and backends (SDKs)
                 │ HTTPS                               │ HTTPS  /api/track
                 ▼                                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Railway project                                                     │
│                                                                     │
│  OpenPanel (Caddy) :8080  public                                    │
│     /api/*  ──────────────►  API :3000         tracking + dashboard │
│     /*      ──────────────►  Dashboard :3000   backend, migrations  │
│                                                                     │
│  Worker  (queues, scheduled jobs, writes events to ClickHouse)      │
│                                                                     │
│  ClickHouse :8123      Postgres :5432          Redis :6379          │
│  events, profiles      users, projects,        queues and cache     │
│  volume                clients; volume         volume               │
│  (all private)                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| OpenPanel | `caddy:2.10.2-alpine` | Public entry point: `/api` goes to the API, everything else to the dashboard |
| API | `lindesvard/openpanel-api:2.3.0` | Event ingestion (`/api/track`), the dashboard's backend, database migrations |
| Dashboard | `lindesvard/openpanel-dashboard:2.3.0` | Web UI (login required) |
| Worker | `lindesvard/openpanel-worker:2.3.0` | Event batching into ClickHouse, sessions, scheduled jobs |
| ClickHouse | `clickhouse/clickhouse-server:25.10.2.65-alpine` | Events and profiles (private) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:17` | Users, organizations, projects, clients, dashboards (private) |
| Redis | `redis:8.10` | Queues and cache (private, `noeviction`) |

## What this template does differently

- **No one can claim your instance.** On a fresh OpenPanel, the first person to sign up becomes the admin. This template creates the admin from `ADMIN_EMAIL` and a generated `ADMIN_PASSWORD` on a private port before the API is reachable, and sign-up is closed (`ALLOW_REGISTRATION=false`). You add teammates by invitation.
- **Login works on Railway domains.** OpenPanel sets its login cookie for the parent domain, which for `*.up.railway.app` is a public suffix that browsers reject. `CUSTOM_COOKIE_DOMAIN` pins the cookie to your dashboard's host.
- **Works on Railway's IPv6 private network.** The API listens on `::`, and the Redis connection uses `family=0`; OpenPanel's defaults are IPv4 only.
- **Private databases.** ClickHouse, Postgres and Redis have no public domain or TCP proxy.
- **Pinned versions.** OpenPanel 2.3.0 (the current public release) and the ClickHouse version OpenPanel's own compose file uses, instead of `:2` or `latest`.
- **ClickHouse tuned for a small service.** High-volume internal log tables are off or kept for a few days, and query threads are limited, so ClickHouse doesn't fill its volume or memory.
- **Migrations on every start.** The API runs the Postgres and ClickHouse migrations before it starts, so upgrades need no manual step. Database passwords are kept out of the migration log.
- **Real visitor IPs.** The proxy passes on the visitor IP Railway forwards, so countries and cities are filled in (the GeoLite2 database is included in the images).

## After deploy

1. Open the OpenPanel URL and log in with `ADMIN_EMAIL` and the `ADMIN_PASSWORD` variable (API service → Variables).
2. Create an organization and a project. OpenPanel shows a **client ID** (and, for app/backend projects, a **client secret**).
3. Add the SDK to your site or app and set `apiUrl` to `https://<your OpenPanel domain>/api`:

   ```html
   <script>
     window.op = window.op || function (...args) { (window.op.q = window.op.q || []).push(args); };
     window.op('init', {
       apiUrl: 'https://<your OpenPanel domain>/api',
       clientId: '<client id>',
       trackScreenViews: true,
       trackOutgoingLinks: true,
     });
   </script>
   <script src="https://openpanel.dev/op1.js" defer async></script>
   ```

   Server-side, send events with the client ID and secret in the `openpanel-client-id` and `openpanel-client-secret` headers, to `POST https://<your OpenPanel domain>/api/track`.
4. Change your password and turn on two-factor sign-in in your profile.
5. Invite teammates in the organization settings. Invitations are sent by email, so set up email first (below).

## Email (optional)

OpenPanel sends invitations and password resets through [Resend](https://resend.com). Set `RESEND_API_KEY` and `EMAIL_SENDER` (a verified sender address) on the API, Dashboard and Worker services and redeploy. Without them, everything else works.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| API | `ADMIN_EMAIL` | (required) | Email of the admin account. You log in with it |
| API | `ADMIN_PASSWORD` | generated | Read it after deploy. Applied only when the admin is created on the first start |
| API | `ADMIN_FIRST_NAME`, `ADMIN_LAST_NAME` | `Admin`, `User` | Name of the admin |
| API, Dashboard, Worker | `DASHBOARD_URL`, `API_URL`, `CUSTOM_COOKIE_DOMAIN` | Railway domain | Change all three on all three services when you add a custom domain |
| API, Dashboard, Worker | `ALLOW_REGISTRATION` | `false` | `true` lets anyone sign up |
| API, Dashboard, Worker | `ALLOW_INVITATION` | `true` | Let the admin invite people |
| API, Dashboard, Worker | `RESEND_API_KEY`, `EMAIL_SENDER` | empty | Email, optional |
| API, Dashboard, Worker | `BATCH_SIZE`, `BATCH_INTERVAL` | `5000`, `10000` | How events are batched into ClickHouse |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| API | `COOKIE_SECRET` | generated | Signs sessions; Dashboard and Worker reference it. Changing it logs everyone out |
| API, Dashboard, Worker | `DATABASE_URL`, `DATABASE_URL_DIRECT`, `CLICKHOUSE_URL`, `REDIS_URL` | from the database services | Private network |
| API | `API_HOST`, `API_PORT`, `PORT` | `::`, `3000` | Listen on IPv6 and IPv4 |
| API | `CH_HOST` | ClickHouse private host | The start script waits for it |
| API | `API_RUN_SH` | script | Start script: migrations, admin account, API |
| OpenPanel | `CADDYFILE`, `API_UPSTREAM`, `DASHBOARD_UPSTREAM`, `PORT` | config | Routing |
| ClickHouse | `CLICKHOUSE_USER`, `CLICKHOUSE_PASSWORD`, `CLICKHOUSE_DB` | `openpanel`, generated, `openpanel` | ClickHouse account and database |
| ClickHouse | `CLICKHOUSE_RUN_SH` | script | Small log tables and thread limits |
| Postgres, Redis | `POSTGRES_PASSWORD`, `REDIS_PASSWORD` | generated | Database passwords |

## Custom domain

Add the domain to the **OpenPanel** service, then set `DASHBOARD_URL=https://analytics.example.com`, `API_URL=https://analytics.example.com/api` and `CUSTOM_COOKIE_DOMAIN=analytics.example.com` on the API, Dashboard and Worker services and redeploy them.

## Upgrading

Change the tag of all three OpenPanel images together (API, Dashboard, Worker), for example `lindesvard/openpanel-api:2.3.1`, and redeploy; the API runs the migrations on start. Read the [self-hosting changelog](https://openpanel.dev/docs/self-hosting/changelog) first, and back up Postgres and ClickHouse before a major version. OpenPanel 3 adds a Redpanda (Kafka) service; it isn't a public release yet, and moving to it is more than a tag change.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Login succeeds but you land back on the login page | `CUSTOM_COOKIE_DOMAIN` doesn't match the host in your browser. Set it to the dashboard's host (see **Custom domain**) |
| Login fails with the generated password | The admin is created on the first start only. If you changed `ADMIN_PASSWORD` later, use the old value |
| `Too many requests` on login | Sign-in allows 3 attempts per 30 seconds. Wait and retry |
| Events from a server return `401 Invalid cors or secret` | Send both `openpanel-client-id` and `openpanel-client-secret`, and use a client of an app/backend project |
| Browser events are rejected | Add your site's origin to the project's allowed domains (CORS) in the project settings |
| Events arrive late | The worker writes events to ClickHouse in batches, every `BATCH_INTERVAL` ms (10 s by default) |

## License

OpenPanel is [AGPL-3.0](https://github.com/Openpanel-dev/openpanel/blob/main/LICENSE). ClickHouse is Apache-2.0, Caddy is Apache-2.0, Redis is RSALv2/SSPLv1/AGPLv3.

## Testing

Tested on 2026-11-08 with OpenPanel 2.3.0 in a throwaway Railway project deployed from the template. All seven services were healthy about two minutes after deploy; the migrations ran and the admin account was created on the first start. Without a login, tRPC calls were refused and project pages redirected to the login page; a wrong password and a stranger's sign-up were refused. The admin logged in (the cookie was set for the dashboard's host), created an organization, a project and a client, and the dashboard pages rendered. Server-side events sent to `/api/track` with the client ID and secret were accepted, a wrong or missing secret was refused, and the events appeared in the event list (ClickHouse) within seconds, with an identified profile and the visitor's real country and city. After redeploying all seven services, the admin, organization, project, client and the earlier events were still there, and new events were ingested (14/14 checks before and after). At idle the seven services used about 1.7 GB of RAM together. Not tested: email, social login, the browser SDK and the dashboard UI in a real browser (only its pages and API).
