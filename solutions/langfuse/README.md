# Langfuse v4

Self-hosted [Langfuse](https://github.com/langfuse/langfuse) v4 (open-source LLM observability: tracing, prompt management, evaluations) on Railway. It starts ready to use: an admin account, an organization, a project and API keys are created on first boot, and public sign-up is closed.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/langfuse-v4-2?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
                 Internet
                    │ HTTPS
                    ▼
┌──────────────────────────────────────────────────────────┐
│ Railway project                                          │
│                                                          │
│  langfuse-web :3000 (public) ── UI, public API, OTel, MCP│
│     │                                                    │
│     ├── Postgres    :5432 (volume)  users, projects, keys │
│     ├── ClickHouse  :8123/:9000 (volume)  traces, scores  │
│     ├── Redis       :6379 (volume)  queues (BullMQ)       │
│     └── Bucket      (Railway Bucket)  raw events, media   │
│                                                          │
│  langfuse-worker :3030 (private) ── ingestion, evals,    │
│     exports; uses the same Postgres/ClickHouse/Redis/Bucket│
└──────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| langfuse-web | `langfuse/langfuse:4.72` | UI, public API, OpenTelemetry ingestion, MCP endpoint (public) |
| langfuse-worker | `langfuse/langfuse-worker:4.72` | Processes ingested events, evaluations, exports (private) |
| ClickHouse | `../clickhouse/clickhouse/Dockerfile` (our ClickHouse component, 26.8 LTS) | Traces, observations, scores (private) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Users, organizations, projects, API keys, prompts (private) |
| Redis | `redis:8.10` with `--maxmemory-policy noeviction` | Job queues and cache (private) |
| Bucket | Railway Bucket | S3-compatible storage for raw events, media and batch exports |

## What this template does differently

- **Ready on first open.** `LANGFUSE_INIT_*` creates the admin user, organization `My Organization`, project `My Project` and its API keys at first boot. Log in with `LANGFUSE_INIT_USER_EMAIL` and the generated `LANGFUSE_INIT_USER_PASSWORD`; copy the keys from `LANGFUSE_INIT_PROJECT_PUBLIC_KEY` / `LANGFUSE_INIT_PROJECT_SECRET_KEY` into your SDK.
- **Sign-up closed.** `AUTH_DISABLE_SIGNUP=true`. Without it anyone who finds the URL can create an account on your instance. Invite teammates from the UI (needs SMTP, see below).
- **Redis set up for queues.** Langfuse's queues (BullMQ) require `maxmemory-policy noeviction`. With the Redis default, Redis can evict queued jobs under memory pressure and traces are lost. The start command also enables AOF persistence.
- **Pinned versions.** Web and worker are pinned to the same Langfuse minor version, and ClickHouse to an LTS release. Newer versions are tested before the template is updated.
- **Lean ClickHouse.** Our ClickHouse component disables the high-volume internal log tables, so it uses less disk and memory. `query_log`, which Langfuse reads, stays on (7-day TTL).
- **Railway Bucket instead of MinIO.** No extra container to run or update.

## Variables

### User-configurable (langfuse-web)

| Variable | Default | Notes |
|---|---|---|
| `LANGFUSE_INIT_USER_EMAIL` | (required) | Admin login |
| `LANGFUSE_INIT_USER_PASSWORD` | generated | Read it from the variable after deploy. Changing it later does not change the password; use the UI |
| `LANGFUSE_INIT_USER_NAME` | `Admin` | |
| `LANGFUSE_INIT_ORG_NAME` / `LANGFUSE_INIT_PROJECT_NAME` | `My Organization` / `My Project` | |
| `AUTH_DISABLE_SIGNUP` | `true` | `false` lets anyone with the URL register |
| `SMTP_CONNECTION_URL` | empty | `smtp://user:pass@host:587`. Enables invite and password-reset emails |
| `EMAIL_FROM_ADDRESS` | empty | Required with SMTP |

The `LANGFUSE_INIT_*` values only take effect on the first boot (on an empty database).

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `SALT`, `ENCRYPTION_KEY` | generated on web, referenced by worker | Changing them invalidates API keys and stored secrets |
| `NEXTAUTH_SECRET` | generated | Session signing |
| `NEXTAUTH_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Must match the public URL. Update it if you add a custom domain |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | |
| `CLICKHOUSE_URL` / `CLICKHOUSE_MIGRATION_URL` | `http://…:8123` / `clickhouse://…:9000` over the private network | Migrations use the native protocol |
| `CLICKHOUSE_CLUSTER_ENABLED` | `false` | Single node |
| `REDIS_CONNECTION_STRING` | `${{Redis.REDIS_URL}}?family=0` | `family=0` is needed for Railway's IPv6 private network |
| `LANGFUSE_S3_*` | `${{Bucket.*}}`, virtual-hosted style | Events under `events/`, media under `media/`, exports under `exports/` |

## Sending traces

Langfuse v4 ingests traces over OpenTelemetry. Use Python SDK ≥ 4.7 or JS/TS SDK ≥ 5.4 (older SDKs are rejected by v4):

```bash
LANGFUSE_HOST=https://<your-domain>
LANGFUSE_PUBLIC_KEY=<LANGFUSE_INIT_PROJECT_PUBLIC_KEY>
LANGFUSE_SECRET_KEY=<LANGFUSE_INIT_PROJECT_SECRET_KEY>
```

Any OpenTelemetry exporter works too: `POST https://<your-domain>/api/public/otel/v1/traces` with Basic auth `public_key:secret_key`.

## Connect Claude Code or Cursor (MCP)

Langfuse v4 has an MCP endpoint at `/api/public/mcp` (prompts, traces, datasets).

```bash
TOKEN=$(echo -n "pk-lf-...:sk-lf-..." | base64)
claude mcp add --transport http langfuse https://<your-domain>/api/public/mcp \
    --header "Authorization: Basic $TOKEN"
```

Cursor: add the same URL and header under Settings → Tools & Integrations → Add Custom MCP.

## AI features (playground, LLM-as-a-judge)

The playground and evaluators call your LLM provider. Add a provider key in the UI under Project Settings → LLM Connections. It is stored encrypted with `ENCRYPTION_KEY`.

## Upgrading

- Change the image tag of **both** `langfuse-web` and `langfuse-worker` to the same version. Migrations run automatically on start.
- ClickHouse can't be downgraded. Langfuse v4 needs ClickHouse 25.12 or later; leave `CLICKHOUSE_IMAGE_TAG` empty to get the LTS release tested with this template.
- Coming from Langfuse v3 with existing data: follow the official [v3 → v4 upgrade guide](https://langfuse.com/self-hosting/upgrade/upgrade-guides/upgrade-v3-to-v4). This template is for new installs.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Can't log in after deploy | `LANGFUSE_INIT_USER_EMAIL` was empty on first boot. Set it, then delete the Postgres volume data or create the user via sign-up (temporarily `AUTH_DISABLE_SIGNUP=false`) |
| `getaddrinfo ENOTFOUND redis.railway.internal` | `?family=0` missing from `REDIS_CONNECTION_STRING` |
| Old SDK gets `404` / `400` | v4 rejects Python SDK v2 and JS/TS SDK v3 and older. Upgrade the SDK |
| MCP returns `403` | You use a custom domain: set `NEXTAUTH_URL` to it, or add it to `LANGFUSE_MCP_ALLOWED_HOSTS` |
| Media uploads fail in the browser | Check the Bucket variables; media uses presigned URLs to the bucket's public endpoint |

## Testing

Tested on 2026-11-01 with a test deploy of the template config, and the published template on 2026-11-02: all five services healthy, admin login works, sign-up returns "Sign up is disabled", an OpenTelemetry trace sent with the init keys was readable through `/api/public/v2/observations` about a minute later.
