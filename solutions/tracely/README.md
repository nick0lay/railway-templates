# Tracely

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/tracely?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

[Tracely](https://github.com/jwuthri-cloud/tracely-ai) is trace-native CI/CD for AI agents. It collects your agents' production traces, grades them with evaluators, groups failures into clusters, turns failures into replayable regression tests, and can block pull requests that make an agent worse.

This template deploys the full self-hosted stack: API, worker, web UI, Postgres with pgvector, ClickHouse and Redis, plus a Railway Bucket for raw trace events.

## Architecture

```
                    ┌──────────────────────── Railway project ────────────────────────┐
  Browser ────────▶ │ frontend :3000 (public, login) ──┐                              │
                    │                                  ▼                              │
  SDK / OTLP / CI ─▶│ backend :8000 (public, API key) ◀── worker (private, Celery)    │
  MCP clients       │      │                                  │                       │
                    │      ▼                                  ▼                       │
                    │  Postgres :5432   ClickHouse :8123   Redis :6379                │
                    │  (pgvector)       (traces, scores)   (queue)                    │
                    │         private, each with a volume                             │
                    │                                                                 │
                    │  Railway Bucket (S3 API, raw trace events)                      │
                    └─────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| frontend | `frontend/Dockerfile` | Next.js web UI. Public; email and password login |
| backend | `backend/Dockerfile` | FastAPI API, OTLP trace ingest and MCP endpoint. Public; every call needs a login session or an ingest key. Runs the database migrations on start |
| worker | `backend/Dockerfile` | Celery worker with the scheduler (scoring, failure clustering, monitors). Private |
| Postgres | `pgvector/pgvector:0.8.7-pg17` | Projects, users, evaluators, regression tests. Private |
| ClickHouse | `solutions/clickhouse/clickhouse` | Trace events and scores. Private |
| Redis | `redis:8.10` | Celery broker. Private |
| Bucket | Railway Bucket | S3-compatible storage for raw trace events, the source of truth before processing. Private, access by key only |

Tracely publishes no Docker images or release tags, so `backend` and `frontend` build from the upstream source at a pinned commit (`TRACELY_REF`).

## What this template does differently

Compared with the upstream Railway files in `deploy/railway`:

- `TRACELY_ENV=prod`. Upstream's example uses `railway`, which seeds the well-known ingest key `tracely_dev_key` on a public API. In `prod` that key is never created.
- The migrations include the LangGraph checkpointer step, which upstream's Railway pre-deploy command leaves out.
- The worker runs the scheduler (`CELERY_BEAT=true`). Without it, monitors, the self-check and the ClickHouse log cleanup never run.
- The worker waits until the API is healthy before it starts, so the first deploy has no worker crash loop.
- Upstream code is pinned to a tested commit instead of following the main branch.
- Raw events go to a Railway Bucket instead of MinIO. MinIO's open-source repository was archived in 2026 and its Docker Hub images are gone, so a bucket is one less service to run and update.

## First login

Open the frontend's public domain and create your workspace. The first account becomes the owner. After that, sign-up is closed: other people join through **Settings → Team** invites.

## Sending traces

Create an ingest key under **Settings → API keys**. The API address is the backend's public domain (also shown on that page).

```bash
pip install "tracelyai-sdk[openai]"
```

```python
import tracely_sdk as tracely

tracely.init(endpoint="https://<backend-domain>", api_key="<ingest-key>", service_name="support-agent")

with tracely.trace(agent="support-agent", conversation="conv-1"):
    client.chat.completions.create(model="gpt-4o", messages=[{"role": "user", "content": "Hi"}])
```

Any OTLP/HTTP exporter works too: `POST https://<backend-domain>/v1/traces` with `Authorization: Bearer <ingest-key>`.

The API also serves an MCP endpoint, so a coding agent can read traces and write evaluators:

```bash
claude mcp add --transport http tracely https://<backend-domain>/mcp --header "Authorization: Bearer <ingest-key>"
```

## LLM features

Evaluators, failure analysis and the assistant call models through OpenRouter. Each workspace adds its own OpenRouter key under **Settings**; the key is stored encrypted with `SECRETS_ENCRYPTION_KEY`. Tracely runs without a key, but LLM-graded evaluators stay idle.

## Variables

### User-configurable (backend)

| Variable | Default | Description |
|----------|---------|-------------|
| `TRACELY_REF` | empty | Upstream commit to build. Empty = the commit tested with this template. Worker and frontend follow the backend's value |
| `OPENROUTER_API_KEY` | empty | Optional server-wide OpenRouter key. Normally each workspace brings its own |
| `RESEND_API_KEY` | empty | Optional [Resend](https://resend.com) key to email team invites. Without it, invites are links you copy |
| `EMAIL_FROM` | `Tracely <onboarding@resend.dev>` | Sender for invite emails |

Worker: `CELERY_POOL` (`solo`) and `CELERY_CONCURRENCY` (`1`). Switch to `prefork` with a higher concurrency when trace volume grows. Keep `CELERY_BEAT=true` on exactly one worker.

### Auto-configured (do not change)

| Variable | Service | Why |
|----------|---------|-----|
| `SESSION_SECRET` | backend, worker | Signs login sessions. Generated; the worker references the backend's value |
| `SECRETS_ENCRYPTION_KEY` | backend, worker | Encrypts stored OpenRouter keys. Changing it makes stored keys unreadable, and every workspace must enter its key again |
| `AUTH_MODE=local`, `TRACELY_ENV=prod` | backend, worker | Login required, no dev key. `dev` mode would leave the API open |
| `DATABASE_URL`, `ALEMBIC_DATABASE_URL` | backend, worker | Postgres, with the async and migration drivers |
| `CLICKHOUSE_*` | backend, worker | `${{ClickHouse.*}}` references |
| `REDIS_URL` | backend, worker | `${{Redis.REDIS_URL}}` |
| `S3_*` | backend, worker | Railway Bucket endpoint, region, name and keys (`${{Bucket.*}}`) |
| `APP_BASE_URL`, `FRONTEND_ORIGIN` | backend, worker | The frontend's public domain, used in links and for CORS |
| `INTERNAL_API_URL` | backend, worker | How server-side jobs reach the API |
| `TRACELY_API` | frontend | The backend on the private network |
| `NEXT_PUBLIC_TRACELY_PUBLIC_API` | frontend | The backend's public domain, built into the UI |
| `NODE_OPTIONS=--dns-result-order=ipv4first` | frontend | The API listens on IPv4 only; without this, server-side page loads can hang for 10 s |

## Upgrading

Set `TRACELY_REF` on the backend to a newer commit SHA from [the upstream repository](https://github.com/jwuthri-cloud/tracely-ai/commits/main) and redeploy backend, worker and frontend. Migrations run when the backend starts. Tracely has no releases yet, so read the commit log before you upgrade.

## Troubleshooting

- **Builds take long.** The backend installs scientific Python packages (numba, hdbscan, umap) and the frontend runs a full Next.js build, so the first deploy takes several minutes.
- **The backend's first deploy fails with a ClickHouse name error.** The migrations wait for ClickHouse to come up. If ClickHouse is still starting after that, redeploy the backend.
- **LLM evaluators never run.** Add an OpenRouter key in the workspace **Settings**, and check that the worker is running.
- **Invites are not emailed.** Set `RESEND_API_KEY` and a verified `EMAIL_FROM`, or copy the invite link from the UI.

## Testing

2026-11-07, upstream commit `128a5d8`: clean deploy from the template, all 7 services healthy in about 2 minutes. Checked that all migrations ran and no dev ingest key was created, that the API returns 401 without a login, that a second sign-up is refused, and that the worker starts the scheduler. A trace sent with the owner's ingest key showed up in the UI.

Same day, after the move from MinIO to a Railway Bucket: clean deploy healthy; a trace was stored in the bucket and returned by the trace list, and listing and bulk delete (used when a workspace is wiped) worked against the bucket.
