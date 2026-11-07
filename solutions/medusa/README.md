# Medusa

Self-hosted [Medusa](https://github.com/medusajs/medusa) v2 on Railway: the open-source commerce platform (a self-hosted Shopify alternative) with its admin dashboard, a separate background worker, and the official [Next.js Starter Storefront](https://github.com/medusajs/nextjs-starter-medusa). The admin user and the storefront's publishable API key are created on first start, and a demo store is loaded, so the shop works as soon as the deploy finishes. PostgreSQL, Redis and the worker stay private; product images go to a Railway Bucket. Versions are pinned and tested.

## Architecture

```
            Shoppers                          You / your team
               │ HTTPS                              │ HTTPS
               ▼                                    ▼
┌───────────────────────────────────────────────────────────────────┐
│ Railway project                                                   │
│                                                                   │
│  Storefront :8000 (public)        Medusa :9000 (public)           │
│    Next.js shop  ───────────────▶   store + admin API             │
│                  private network    admin dashboard /app (login)  │
│                                     product images /media         │
│                                        │        │         │       │
│                     ┌──────────────────┘        │         │       │
│                     ▼                           ▼         ▼       │
│  Medusa Worker (private)  ───▶  Redis :6379   Postgres   Bucket   │
│    jobs, subscribers,           (private)     :5432      (S3,     │
│    scheduled jobs               events,       (private)  private) │
│                                 workflows,                        │
│                                 locks                             │
└───────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Medusa | `backend/Dockerfile` (Medusa 2.22.4, Node 22) | Store and admin API, admin dashboard at `/app`, media at `/media` (public, admin login required) |
| Medusa Worker | `backend/Dockerfile` (same image, `MEDUSA_WORKER_MODE=worker`) | Background jobs, event subscribers, scheduled jobs (private) |
| Storefront | `storefront/Dockerfile` (Next.js Starter, pinned commit) | Shop front for customers (public) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Products, orders, customers (private) |
| Redis | `redis:8.10` | Event bus, workflow engine and locks shared by server and worker (private) |
| Bucket | Railway Bucket | Product images and uploads (private, served through Medusa) |

## What this template does differently

- **Admin account created at deploy.** Medusa has no admin sign-up page; normally you run `medusa user` by hand. This template creates the admin from `MEDUSA_ADMIN_EMAIL` and a generated `MEDUSA_ADMIN_PASSWORD` on first start. Nobody else can create an admin account: new admins need an invite from an existing one.
- **Storefront works on the first deploy.** The storefront has to be built with a publishable API key, and that key normally exists only after the backend has run and someone has copied it from the admin. Here the key's value is generated as a template variable (`MEDUSA_PUBLISHABLE_KEY`), the storefront is built with it, and the backend registers it on start, linked to the default sales channel.
- **Separate worker.** Background jobs, subscribers and scheduled jobs run in their own service (`MEDUSA_WORKER_MODE=worker`), so heavy jobs don't slow down the API. Server and worker share events, workflows and locks through Redis. The worker waits until the server has finished migrations before it starts.
- **Images in a bucket.** Uploads go to a Railway Bucket. Buckets are private, so Medusa serves images at `https://<Medusa domain>/media/<file>`, and only image and video files: private uploads such as product import CSVs are never public.
- **Demo store.** On an empty database the backend loads Medusa's demo data (a Europe region in EUR, shipping options, four products), so the storefront shows a working shop. Set `SEED_DEMO_DATA=false` before the first deploy for an empty store.
- **Private by default.** PostgreSQL, Redis and the worker have no public domain or TCP proxy.
- **Pinned versions:** Medusa 2.22.4 with a lockfile, Node 22.23.4, Next.js Starter at a fixed commit, PostgreSQL 18, Redis 8.10. Healthchecks on Medusa (`/health`) and the storefront (`/api/healthcheck`).

## After deploy

1. Wait until the Medusa service is healthy. The first start runs the database migrations and loads the demo data, which takes 3 to 5 minutes. The storefront and worker start in parallel.
2. Open `https://<Medusa domain>/app` and log in with `MEDUSA_ADMIN_EMAIL` and the `MEDUSA_ADMIN_PASSWORD` variable of the Medusa service.
3. Open the Storefront URL. You land on the demo region (`/de` by default) with the demo products.
4. In the admin, add your products, set up regions, currencies and shipping, and invite your team under **Settings → Users**.

## Environment variables

### User-configurable

| Variable | Service | Default | Description |
|---|---|---|---|
| `MEDUSA_ADMIN_EMAIL` | Medusa | *(required)* | Email of the admin account created on first start |
| `MEDUSA_ADMIN_PASSWORD` | Medusa | generated | Password of that account. Changing it later does not change the existing account |
| `SEED_DEMO_DATA` | Medusa | `true` | Load the demo store when the database is empty |
| `STORE_CORS` | Medusa | storefront URL | Origins allowed to call the store API; add your own frontends, comma-separated |
| `NEXT_PUBLIC_DEFAULT_REGION` | Storefront | `de` | Country shown when the visitor's country has no region |
| `NEXT_PUBLIC_STRIPE_KEY` | Storefront | empty | Stripe publishable key, if you add the Stripe provider to the backend |
| `NODE_OPTIONS` | Medusa, Worker | `--max-old-space-size=2048` | Node heap limit |

### Auto-configured (do not change)

| Variable | Service | Purpose |
|---|---|---|
| `MEDUSA_WORKER_MODE` | Medusa, Worker | `server` on Medusa, `worker` on the worker. Both `shared` or both `server` would leave jobs unprocessed or run them twice |
| `MEDUSA_PUBLISHABLE_KEY` | Medusa | Publishable key token; the storefront is built with the same value (`NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY`). Changing it requires a storefront rebuild |
| `JWT_SECRET`, `COOKIE_SECRET` | Medusa, Worker | Sign logins and sessions; changing them logs everyone out |
| `DATABASE_URL`, `REDIS_URL` | Medusa, Worker | Postgres and Redis over the private network |
| `S3_*` | Medusa, Worker | The Railway Bucket |
| `MEDUSA_BACKEND_URL` | Medusa, Worker, Storefront | Public URL of Medusa (file links) on the backend; private URL on the storefront |
| `MEDUSA_SERVER_URL` | Worker | The worker waits for this server's `/health` before starting |
| `MEDUSA_MEDIA_HOSTNAME` | Storefront | Host allowed for product images |

Storefront variables starting with `NEXT_PUBLIC_` are compiled into the build. After changing one, redeploy the storefront (a restart is not enough).

## Updating

Medusa's version is set in `backend/package.json` and `backend/package-lock.json`. To upgrade, fork this repository, bump the `@medusajs/*` packages, regenerate the lockfile, and point the Medusa and Medusa Worker services at your fork. Migrations run automatically on the next start of the Medusa service.

## Troubleshooting

- **Storefront shows "No valid regions configured".** The store has no region with countries (for example after `SEED_DEMO_DATA=false`). Add a region in the admin under **Settings → Regions**.
- **Storefront returns errors about the publishable key.** The key in `MEDUSA_PUBLISHABLE_KEY` was revoked or deleted in the admin. Redeploy the Medusa service; it registers the key again on start.
- **Admin login fails after changing `MEDUSA_ADMIN_PASSWORD`.** The account is created only once. Use **Forgot password** (needs an email provider) or log in with the old password and change it in the admin.
- **Product images don't load on the storefront.** Images are served from the Medusa domain. If you add a custom domain to Medusa, update `MEDUSA_BACKEND_URL` on Medusa and `MEDUSA_MEDIA_HOSTNAME` on the storefront, and redeploy both.
- **The worker keeps restarting at deploy.** It waits up to 30 minutes for Medusa's `/health`. Check the Medusa service logs first.

## Tested

2026-11-07: deployed on Railway with Medusa 2.22.4. Admin login, product with an image uploaded to the bucket, storefront product page, product export run by the worker, and data after redeploying every service all worked; a self-registered account got no admin access.
