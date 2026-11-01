# Trigger.dev

Self-hosted Trigger.dev v4 on Railway (webapp and data services) plus a DigitalOcean droplet for the supervisor that runs your tasks.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/triggerdev?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
                    Internet
                       │ HTTPS
                       ▼
┌────────────────────────────────────────────────────────────┐
│ Railway project                                            │
│                                                            │
│  trigger.dev webapp (public) ── dashboard, API, run engine │
│     │                                                      │
│     ├── Postgres    (volume)   jobs, runs, state           │
│     ├── Redis       (volume)   queues, cache, pub/sub      │
│     ├── ClickHouse  (volume)   run analytics, logs         │
│     ├── Bucket      (Railway Bucket) large payloads        │
│     └── registry               task images                 │
│                                                            │
│  ops-controller ── creates and maintains the supervisor ───┼──┐
└────────────────────────────────────────────────────────────┘  │
                                                                ▼
                                   DigitalOcean droplet: supervisor
                                   (needs Docker socket, which Railway
                                    doesn't provide; runs your tasks)
```

## Services

| Service | Source | Role |
|---------|--------|------|
| trigger.dev | `webapp/Dockerfile` (`ghcr.io/nick0lay/trigger.dev-railway:v4.0.0`) | Webapp, API, dashboard (public) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:16` | Primary database (private) |
| Redis | `redis:8.2` (Railway's Redis) | Queues, cache, pub/sub (private) |
| ClickHouse | `clickhouse/clickhouse-server` | Analytics for runs and logs (private) |
| Bucket | Railway Bucket | S3-compatible storage for large payloads |
| registry | `registry:2` | Docker registry for deployed task images |
| ops-controller | `ghcr.io/nick0lay/trigger-ops-controller` | Provisions the DigitalOcean supervisor, sets up Postgres→ClickHouse replication, then disables itself |

## Where the code lives

- **This directory**: the Railway packaging for the webapp: a Dockerfile that pins the patched image, docs and template copy.
- **[nick0lay/trigger.dev](https://github.com/nick0lay/trigger.dev)** (fork of `triggerdotdev/trigger.dev`): the patches (dual-stack IPv6 for Redis/Postgres on Railway's private network, ClickHouse fixes), the GitHub Actions that build `ghcr.io/nick0lay/trigger.dev-railway` and `ghcr.io/nick0lay/trigger-ops-controller`, the ops-controller code, and detailed docs under `.railway/docs/`.

To upgrade Trigger.dev, rebuild the patched image from the fork for the new version and change `TRIGGER_IMAGE_TAG`.

### Database migrations

The webapp applies upstream's Prisma migrations on boot (about 700 of them; under a minute on an empty database). An earlier version replaced them with one consolidated migration, but Railway's builder kept the original files. Both sets then ran, and the first boot failed with `type "AuthenticationMethod" already exists`.

### Why the webapp isn't built from the fork

Railway scans the dependency lockfile of the repository it builds from. The Trigger.dev monorepo lockfile includes example apps under `references/` that pin vulnerable Next.js versions (for example CVE-2025-66478). Those examples aren't part of the webapp image, but the scan still blocks the build ("SECURITY VULNERABILITIES DETECTED"). Building from this directory, which has no lockfile, avoids that.

## Object storage (Railway Bucket)

Trigger.dev stores large payloads and outputs under `packets/…` in an S3-compatible store. The template wires a Railway Bucket:

| Variable (trigger.dev) | Value |
|---|---|
| `OBJECT_STORE_BASE_URL` | `https://${{Bucket.BUCKET}}.t3.storageapi.dev` (virtual-hosted style; Trigger.dev sets the path itself) |
| `OBJECT_STORE_ACCESS_KEY_ID` | `${{Bucket.ACCESS_KEY_ID}}` |
| `OBJECT_STORE_SECRET_ACCESS_KEY` | `${{Bucket.SECRET_ACCESS_KEY}}` |
| `OBJECT_STORE_REGION` | `${{Bucket.REGION}}` |

This replaced MinIO in November 2026. MinIO stopped publishing community images in late 2025, and the `bitnami/minio` image the template used was removed from Docker Hub.

## Redis

The template uses Railway's own Redis service definition (`redis:8.2`, volume at `/data`). The webapp connects with `REDIS_URL=${{Redis.REDIS_URL}}?family=0`, and the patched image enables dual-stack DNS lookups. Without that, connections fail with `getaddrinfo ENOTFOUND redis.railway.internal`, because Railway's private network is IPv6.

## Required input

- `DIGITALOCEAN_TOKEN` on ops-controller: lets it create the supervisor droplet. Everything else is generated or wired automatically.

See the fork's [.railway/docs](https://github.com/nick0lay/trigger.dev/tree/main/.railway/docs) for supervisor setup, data replication and troubleshooting.
