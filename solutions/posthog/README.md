# PostHog

Self-hosted [PostHog](https://github.com/PostHog/posthog) on Railway: open-source product analytics with session replay, feature flags, experiments, surveys and a SQL editor over your events. This template runs PostHog's official images as 23 Railway services: the web app and its workers, the event capture and ingestion pipeline, ClickHouse, Kafka (Redpanda), Postgres, Redis and S3 storage. The admin account is created at deploy, so nobody else can claim the instance, and only one service is public.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/posthog?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
          Your sites and apps (posthog-js, SDKs)        You (browser)
                       │ HTTPS                                │ HTTPS
                       ▼                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Railway project                                                             │
│                                                                             │
│  PostHog :8000 (Caddy, the only public service)                             │
│   /e /batch /i/v0 ─► Capture :3000 ──┐        /s ─► Replay Capture :3000 ─┐  │
│   /flags ─► Feature Flags :3001      │        /array /surveys ─► Hypercache│  │
│   everything else ─► Web :8000 (login required)                          │  │
│                                      ▼                                   ▼  │
│                              Kafka :9092 (Redpanda) ◄────────────────────┘  │
│                                      │                                      │
│        ┌─────────────────┬───────────┼───────────────┬─────────────────┐    │
│        ▼                 ▼           ▼               ▼                 ▼    │
│   Ingestion        Property Defs  ClickHouse    Replay Ingestion   Livestream│
│   (persons, events)                :9000 + Kafka   (recordings →         │  │
│        │                           engine tables    Storage)             │  │
│        ▼                                │                                   │
│   Postgres :5432 ◄── Web, Worker, Temporal Worker, Plugins, PersonHog       │
│   Redis :6379        Temporal :7233     ZooKeeper :2181   Storage :19000    │
│                                                           (SeaweedFS S3)    │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| PostHog | `caddy:2.10.2-alpine` | Public entry point. Routes capture, flags and recordings to the Rust services, the rest to Web (public) |
| Web | `posthog/posthog` (pinned commit) | Django app and API with login. Runs migrations and creates the admin on start (private) |
| Worker | `posthog/posthog` | Celery worker and scheduler: exports, alerts, cohorts, reports (private) |
| Temporal Worker | `posthog/posthog` | Temporal workflows: batch exports, data warehouse syncs (private) |
| Plugins | `ghcr.io/posthog/posthog-node` | Destinations, webhooks, workflows, realtime cohorts (private) |
| Ingestion | `ghcr.io/posthog/posthog-node` | Event ingestion: persons, properties, writes events to ClickHouse via Kafka (private) |
| Replay Ingestion | `ghcr.io/posthog/posthog-node` | Session recording ingestion into storage (private) |
| Recording API | `ghcr.io/posthog/posthog-node` | Serves recordings to the web app (private) |
| Capture | `ghcr.io/posthog/posthog/capture` | Event capture endpoint (private, reached through PostHog) |
| Replay Capture | `ghcr.io/posthog/posthog/capture` | Session recording capture endpoint (private) |
| Feature Flags | `ghcr.io/posthog/posthog/feature-flags` | Flag evaluation for SDKs (private) |
| Hypercache | `ghcr.io/posthog/posthog/hypercache-server` | Remote config and surveys for SDKs (private) |
| Property Defs | `ghcr.io/posthog/posthog/property-defs-rs` | Records event and property definitions (private) |
| PersonHog Replica, PersonHog Router | `ghcr.io/posthog/posthog/personhog-*` | Person lookups over gRPC, required by the plugin server (private) |
| Livestream | `ghcr.io/posthog/posthog/livestream` | Live events stream in the web app (private) |
| Temporal | `temporalio/auto-setup:1.29.7` | Workflow engine, stores state in Postgres (private) |
| ClickHouse | `ghcr.io/posthog/clickhouse-posthog:26.9.5.2` | Events, persons, recordings metadata (private, volume) |
| Kafka | `redpandadata/redpanda:v25.1.9` | Event queue between capture, ingestion and ClickHouse (private, volume) |
| ZooKeeper | `zookeeper:3.7.0` | ClickHouse coordination (private, volume) |
| Postgres | `postgres-ssl:15` | App data, persons, Temporal, plugin job queue (private, volume) |
| Redis | `redis:7.2-alpine` | Cache and queues (private, volume) |
| Storage | `chrislusf/seaweedfs:4.29` | S3 storage for recordings, exports and uploads (private, volume) |

## What this template does differently

- **No one can claim your instance.** A fresh PostHog lets the first visitor sign up as the owner. This template creates the admin from `POSTHOG_ADMIN_EMAIL` and a generated `POSTHOG_ADMIN_PASSWORD` on the first start. After that, sign-up for new organizations is closed; teammates join by invitation.
- **Only one public service.** Capture, flags, recordings, the web app and presigned storage links all go through the `PostHog` Caddy service, like PostHog's own Docker setup. ClickHouse, Kafka, Postgres, Redis and storage have no public domain or TCP proxy.
- **Everything generated.** The Django secret, the encryption salt, the storage keys and the database password are generated at deploy. Nothing is shared between deployments of this template.
- **Pinned and tested.** All PostHog images are pinned to one tested commit, and the ClickHouse configuration is read from that same commit, so the services can't drift apart.
- **Railway fixes built in:**
  - ClickHouse gets PostHog's config, Kafka schemas and UDF binaries from the PostHog repository on its first start, with hostnames rewritten for Railway's private network.
  - Kafka topics that PostHog's consumers expect are created before anything writes to them.
  - The plugin server's job queue database (`cyclotron_node`) is created and migrated by Web on start. PostHog's Docker setup skips this step, and the plugin server doesn't start without it.
  - The Node.js services download the GeoIP database they need on start, and wait for the job queue database.
- Kafka, storage, Temporal and the Rust services listen on IPv6 as well as IPv4, because Railway's private DNS can answer with IPv6 addresses only.
- Every service restarts automatically when it exits, so the pipeline recovers after a dependency restarts.

## Left out

To keep the stack a reasonable size, these parts of PostHog's full Docker setup are not included:

- **Error tracking symbolication** (`cymbal`): exceptions are captured but not processed into issues.
- **LLM analytics capture** (`capture-ai`) and **logs and traces capture** (`capture-logs`).
- **Heatmap screenshots** (`browserless`).
- **PersonHog's leader write path** (leader, writer, identity, etcd): person writes go straight to Postgres, which is PostHog's default.
- **Elasticsearch** for Temporal: workflow search uses Postgres.

## After deploy

The first start takes about 30 minutes while Web runs PostHog's database migrations. Watch for `posthog-setup: starting web server` in the Web logs.

1. Open the PostHog URL and log in with `POSTHOG_ADMIN_EMAIL` and the `POSTHOG_ADMIN_PASSWORD` variable (Web service → Variables).
2. Copy the project API key from **Settings → Project** and add the snippet to your site, with `api_host` set to your PostHog URL.
3. Invite teammates under **Settings → Members**. Invitations need email (below); without it, copy the invite link from the members page.

## Email (optional)

PostHog sends invitations, password resets and alerts by email. Set the SMTP settings in **Instance settings** (staff admin), or add `EMAIL_HOST`, `EMAIL_PORT`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD`, `EMAIL_USE_TLS` and `EMAIL_DEFAULT_FROM` to Web and Worker and redeploy.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Web | `POSTHOG_ADMIN_EMAIL` | (required) | Email of the admin account. You log in with it |
| Web | `POSTHOG_ADMIN_PASSWORD` | generated | Read it after deploy. Applied only when the admin is created on the first start |
| Web | `POSTHOG_ADMIN_NAME` | `Admin` | First name of the admin |
| Web | `POSTHOG_ORGANIZATION_NAME` | `PostHog` | Name of the organization created with the admin |
| Web, Worker, Temporal Worker | `OPT_OUT_CAPTURE` | `false` | Set to `true` to stop sending anonymous usage stats to PostHog Inc. |
| Web | `GRANIAN_WORKERS` | `2` | Web server processes. Raise it for more traffic |
| Worker | `WEB_CONCURRENCY` | `2` | Celery worker processes |
| Kafka | `KAFKA_LOG_RETENTION_MS` | `3600000` | How long Kafka keeps messages (they are consumed within seconds) |

### Auto-configured (do not change)

| Service | Variable | Why |
|---|---|---|
| Web | `SECRET_KEY`, `ENCRYPTION_SALT_KEYS` | Generated. Other services reference them. Changing them logs everyone out and makes stored secrets unreadable |
| Web | `RECORDING_API_JWT_SECRET` | Generated. Shared with Recording API |
| Web | `POSTHOG_REPO_REF` | The PostHog commit of the images. Job queue migrations are read from it |
| ClickHouse | `POSTHOG_REPO_REF` | The commit whose ClickHouse config is used. Keep it equal to the images' commit |
| Storage | `S3_ACCESS_KEY`, `S3_SECRET_KEY` | Generated storage credentials, referenced by the app services |
| Postgres | `POSTGRES_PASSWORD` | Generated database password |
| all | `*_UPSTREAM`, `*_HOST`, `*_URL`, `KAFKA_HOSTS`, `OBJECT_STORAGE_*`, `SESSION_RECORDING_V2_S3_*` | Private network addresses of the other services |
| several | `*_RUN_SH`, `CADDYFILE`, `LIVESTREAM_CONFIG` | Start scripts and config files |
| ClickHouse | `CLICKHOUSE_API_PASSWORD`, `CLICKHOUSE_APP_PASSWORD` | PostHog's default ClickHouse users. ClickHouse is reachable only on the private network |

## Upgrading

PostHog publishes a new image for every commit to its main branch, and the self-hosted setup tracks that branch. To upgrade, pick a newer commit, then change these together and redeploy:

- the image tag of Web, Worker and Temporal Worker (`posthog/posthog:sha-<commit>`) and of the four Node.js services (`ghcr.io/posthog/posthog-node:sha-<commit>`);
- `POSTHOG_REPO_REF` on Web and ClickHouse;
- optionally the Rust service images (`ghcr.io/posthog/posthog/<service>:sha-<short commit>`).

Migrations run on Web's start. Back up Postgres and ClickHouse first; PostHog doesn't support downgrades.

## Resources

PostHog is a large system. At idle the services use about 15 GB of RAM together (see Testing). Railway bills by actual usage, so expect a higher bill than a single-service app. ClickHouse, the web app and the workers are the largest.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| The URL shows an error for the first 30 minutes | Web is still running migrations. Watch its logs for `posthog-setup: starting web server` |
| Web fails with `POSTHOG_ADMIN_EMAIL` missing | Set the variable and redeploy Web |
| Login fails with the generated password | The admin is created on the first start only. If you changed the variables later, use the old values, or reset the password with `python manage.py changepassword` in Web |
| Events are accepted but don't show up | Check the Ingestion and ClickHouse logs. Events go Capture → Kafka → Ingestion → Kafka → ClickHouse |
| ClickHouse fails on its first start with a download error | It fetches config files from GitHub on the first start. Redeploy when GitHub is reachable |
| A Node.js service fails with `geoip: download failed` | It downloads the GeoIP database from PostHog's CDN on start. Redeploy it |
| Login page or `/_preflight` hangs after Redis was redeployed | The Plugins service doesn't always reconnect to a restarted Redis, and Web waits on its health endpoint. Redeploy Plugins, then Web |
| Events stop arriving after Kafka was redeployed | Redeploy Capture and Ingestion (they restart on their own when they exit, but can stall) |

## License

PostHog is [MIT](https://github.com/PostHog/posthog/blob/master/LICENSE) except the `ee/` directory, which is under PostHog's enterprise license; features in it need a license key.

## Testing

Tested on 2026-11-07 with PostHog at commit `1a3b1f8` in a throwaway Railway project, deployed from the template. All 23 services were healthy; Web's first start (migrations) took about 30 minutes. The admin account was created on the first start. Requests without a login, a wrong password, a wrong personal API key and a stranger's sign-up were refused; the admin logged in as staff. Events sent to `/e/` and `/batch/` and an `$identify` went through Capture, Kafka and Ingestion into ClickHouse and were returned by a SQL query, with person properties stored and a property definition recorded. A feature flag created through the API evaluated as enabled on `/flags`, remote config answered on `/array/<token>/config`, and a CSV export was produced by the worker, stored and downloaded. After redeploying the data and app services, the admin, events and flag were still there and new events were ingested. At idle the services used about 15 GB of RAM together (Worker 4.1, Web 2.9, ClickHouse 2.9, Temporal Worker 1.6, the rest under 0.5 each).

Not verified: session replay end to end. A synthetic recording was accepted by Replay Capture and read by Replay Ingestion but not stored, so recordings should be checked with a real site using posthog-js. Also not tested: email, batch exports to external destinations, and the browser UI beyond the login page.
