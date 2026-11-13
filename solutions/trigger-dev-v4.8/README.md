# Trigger.dev v4.8

Self-hosted Trigger.dev v4.8.5 on Railway (webapp and data services) plus a DigitalOcean droplet for the supervisor that runs your tasks. The template runs the official upstream images, not a patched fork.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/triggerdev-v48?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

The earlier [`trigger-dev`](../trigger-dev/) template (v4.0.0, patched image) stays published for existing projects.

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
│     └── registry    (volume)   task images                 │
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
| trigger.dev | image `ghcr.io/triggerdotdev/trigger.dev:v4.8.5` | Webapp, API, dashboard (public). Healthcheck `/healthcheck` |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:16` | Primary database (private) |
| Redis | `redis:8.2` | Queues, cache, pub/sub (private) |
| ClickHouse | `clickhouse/Dockerfile` (`clickhouse/clickhouse-server:26.10` plus one setting) | Analytics for runs and logs (private) |
| Bucket | Railway Bucket | S3-compatible storage for large payloads |
| registry | `registry/Dockerfile` (`registry:2` with basic auth, volume at `/var/lib/registry`) | Docker registry for deployed task images (public, password-protected) |
| ops-controller | `ghcr.io/nick0lay/trigger-ops-controller:sha-<commit>` | Provisions the DigitalOcean supervisor (`ghcr.io/triggerdotdev/supervisor:${TRIGGER_VERSION}`), sets up Postgres→ClickHouse replication, then disables itself |

Every image is pinned. The webapp and the supervisor must always run the same version.

## Where the code lives

- **This directory**: the ClickHouse and registry images, docs and template copy.
- **[nick0lay/trigger.dev](https://github.com/nick0lay/trigger.dev)** (fork of `triggerdotdev/trigger.dev`): only the ops-controller (`.railway/ops-controller/`) and the workflow that builds `ghcr.io/nick0lay/trigger-ops-controller`. The webapp is upstream's image as is.

## Networking

Projects created on Railway after 2025-10-16 resolve `*.railway.internal` to IPv4 and IPv6, so upstream's Redis client works without the `family: 0` patch the v4.0.0 template needed. Every project created from this template is such a project.

## ClickHouse

`clickhouse/Dockerfile` pins `clickhouse/clickhouse-server:26.10` and adds `config.d/trigger-dev.xml`, which turns on the MergeTree setting `allow_dimensions_outside_sorting_key`. ClickHouse 26.10 and later reject Trigger.dev's migration 022 (`errors_v1`) without it (`Code: 36 ... BAD_ARGUMENTS`).

ClickHouse can only move forward. An older version can't read data written by a newer one: 26.2 crash-loops on a 26.10 data directory. Raise `CLICKHOUSE_IMAGE_TAG`, never lower it.

### Database migrations

On boot the webapp applies upstream's Prisma migrations, the dashboard-agent migrations (into the same Postgres) and the ClickHouse migrations (goose).

## Object storage (Railway Bucket)

Trigger.dev stores large payloads and outputs under `packets/…` in an S3-compatible store. The template wires a Railway Bucket:

| Variable (trigger.dev) | Value |
|---|---|
| `OBJECT_STORE_BASE_URL` | `https://${{Bucket.BUCKET}}.t3.storageapi.dev` (virtual-hosted style; Trigger.dev sets the path itself) |
| `OBJECT_STORE_ACCESS_KEY_ID` | `${{Bucket.ACCESS_KEY_ID}}` |
| `OBJECT_STORE_SECRET_ACCESS_KEY` | `${{Bucket.SECRET_ACCESS_KEY}}` |
| `OBJECT_STORE_REGION` | `${{Bucket.REGION}}` |


## Registry

The CLI on your machine pushes task images to the registry, and the supervisor on DigitalOcean pulls them, both through the registry's **public** domain.

| Where | Variable | Value |
|---|---|---|
| registry | `PORT` | `5000`. The registry listens on 5000; without this the public domain returns 502 |
| registry | `REGISTRY_USERNAME` / `REGISTRY_PASSWORD` | `trigger` / generated. The entrypoint turns them into an htpasswd file (basic auth) |
| trigger.dev | `V4_DEPLOY_REGISTRY_HOST`, `DEPLOY_REGISTRY_HOST` | `${{registry.RAILWAY_PUBLIC_DOMAIN}}`. A private `*.railway.internal` host can't be reached by the CLI or the supervisor |
| trigger.dev | `V4_DEPLOY_REGISTRY_USERNAME`/`_PASSWORD` (and `DEPLOY_REGISTRY_*`) | references to the registry service |
| ops-controller | (read through the Railway API) | passes the domain, user and password to the supervisor as `DOCKER_REGISTRY_URL`/`_USERNAME`/`_PASSWORD` |

Images are stored on a volume at `/var/lib/registry`, so deployed task versions survive registry restarts. Each deploy adds an image. To free space, delete old versions through the registry API, then run `registry garbage-collect /etc/docker/registry/config.yml` in the service.

Before deploying tasks, run `docker login <registry-domain> -u trigger` with the password from the registry service's variables.

## Required input

Both go on the ops-controller service. Everything else is generated or wired automatically.

- `DIGITALOCEAN_TOKEN`: lets it create the supervisor droplet. Create one at https://cloud.digitalocean.com/account/api/tokens.
- `RAILWAY_API_TOKEN`: lets it read the other services' variables (registry domain and password, worker token), configure Postgres and save the worker token on its own service. Use an account or workspace token from https://railway.com/account/tokens. A project token doesn't work, because the ops-controller sends it as a Bearer token.

After the deploy, the supervisor usually connects within about 5 minutes; allow up to 20. Runs triggered before that stay queued and start once it connects.

## Upgrading

1. Change the webapp image tag (for example `ghcr.io/triggerdotdev/trigger.dev:v4.8.6`) and the ops-controller's `TRIGGER_VERSION` to the same version. Use an exact version, never `latest`: the supervisor is only replaced when the value changes.
2. The webapp applies new migrations on boot.
3. Changing `TRIGGER_VERSION` redeploys the ops-controller. It destroys the supervisor droplet tagged with the old version, waits until it is gone and creates a new one. Runs queue in the meantime.
4. The ops-controller finds the worker token in older webapp deployments and keeps it as its own `TRIGGER_WORKER_TOKEN` variable, so webapp redeploys don't break supervisor re-creation.
5. ClickHouse: the version comes from `CLICKHOUSE_IMAGE_TAG` in `clickhouse/Dockerfile` (default `26.10`). To change it, add a `CLICKHOUSE_IMAGE_TAG` variable to the ClickHouse service; Railway passes it to the build. Only raise it, never lower it (an older server can't read a newer data directory), and check upstream's release notes for ClickHouse requirements first.

If you reset or recreate Postgres, the webapp creates a new worker group and prints a new worker token on its next boot. Delete `TRIGGER_WORKER_TOKEN` on the ops-controller and redeploy it, so it picks up the new token. Otherwise the supervisor keeps the old token and runs stay queued.

## Removing the deployment

The supervisor droplet lives in your DigitalOcean account, outside the Railway project. Deleting the Railway project does not delete it, and DigitalOcean keeps billing it. After deleting the project, open https://cloud.digitalocean.com/droplets and destroy the droplet named `trigger-supervisor-...`.

See the fork's [ops-controller README](https://github.com/nick0lay/trigger.dev/tree/main/.railway/ops-controller) for supervisor setup and troubleshooting.
