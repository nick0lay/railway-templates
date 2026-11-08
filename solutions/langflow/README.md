# Langflow

Self-hosted [Langflow](https://github.com/langflow-ai/langflow) on Railway: a visual builder for AI agents, RAG pipelines and multi-agent workflows that you run as an API, an MCP server or an embedded chat. It requires a login, keeps your data in Postgres and on a volume, and runs a pinned, tested version.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/langflow-4?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
                 You / your apps
                       │ HTTPS
                       ▼
┌──────────────────────────────────────────────────────┐
│ Railway project                                      │
│                                                      │
│  langflow :7860 (public)                             │
│    editor, REST API, MCP server, embedded chat       │
│    volume /app/langflow: uploaded files, cache       │
│        │                                             │
│        ▼                                             │
│  Postgres :5432 (private, volume)                    │
│    flows, users, API keys, encrypted credentials     │
└──────────────────────────────────────────────────────┘
                       │
                       ▼
          LLM providers, vector stores, tools
```

## Services

| Service | Source | Role |
|---------|--------|------|
| langflow | `langflowai/langflow:1.13.1` | Visual editor, API and MCP server (public) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Flows, users, API keys, credentials (private) |

## What this template does differently

- **Login required.** `LANGFLOW_AUTO_LOGIN=false` with an `admin` account and a generated password. The most-deployed Langflow template on Railway leaves the editor open to anyone who finds the URL.
- **Sign-up off.** The admin adds users (see [Adding users](#adding-users)). Only admins can create or edit custom components, which run Python on the server (`LANGFLOW_CUSTOM_COMPONENT_ADMIN_ONLY=true`).
- **Persistent secret key.** `LANGFLOW_SECRET_KEY` is generated once. Without it, Langflow makes a new key on every restart and saved credentials can no longer be decrypted.
- **Data persists.** Postgres on a volume for flows and credentials, and a volume for uploaded files. Tested: a saved credential and an uploaded file were still there after a redeploy.
- **Private database connection.** Langflow reaches Postgres over Railway's private network, not a public TCP proxy.
- **Pinned version, quiet logs.** Langflow 1.13.1 and Postgres 18 instead of `latest`; `info` log level instead of `debug`; Langflow's usage telemetry off.
- **Optional Langfuse tracing.** Fill in three variables to trace every flow run in Langfuse.

## After deploy

1. Open the `langflow` URL and log in as `admin` with the `LANGFLOW_SUPERUSER_PASSWORD` variable.
2. Add your model provider keys under Settings → Global Variables (stored encrypted with `LANGFLOW_SECRET_KEY`), or in a component's API key field.
3. Start from a template such as "Basic Prompting" or "Vector Store RAG".
4. Run flows from your app with an API key (Settings → Langflow API Keys):

```bash
curl -X POST "https://<langflow-domain>/api/v1/run/<flow-id>" \
  -H "x-api-key: $LANGFLOW_API_KEY" -H "Content-Type: application/json" \
  -d '{"input_value": "Hello", "input_type": "chat", "output_type": "chat"}'
```

Each project is also an MCP server: see the project's **MCP Server** tab for the URL and the config for Claude Code, Cursor and other clients.

## Adding users

Langflow 1.13 has no user management page in its UI, so the admin adds users through the API:

```bash
LF=https://<langflow-domain>
TOKEN=$(curl -s -X POST "$LF/api/v1/login" -d username=admin -d "password=$LANGFLOW_SUPERUSER_PASSWORD" | jq -r .access_token)

# Create the user, then activate it (new users start inactive)
USER_ID=$(curl -s -X POST "$LF/api/v1/users/" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"username": "alice", "password": "a-long-password"}' | jq -r .id)
curl -s -X PATCH "$LF/api/v1/users/$USER_ID" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"is_active": true}'
```

Each user sees only their own flows. To make someone an admin, also send `"is_superuser": true` in the `PATCH`.

## Variables

### User-configurable

| Variable | Default | Notes |
|---|---|---|
| `LANGFLOW_SUPERUSER` | `admin` | Admin username |
| `LANGFLOW_SUPERUSER_PASSWORD` | generated | Read it after deploy. It's applied when the admin is created on first start |
| `LANGFLOW_ENABLE_SIGNUP` | `false` | `true` allows public sign-up |
| `LANGFLOW_NEW_USER_IS_ACTIVE` | `false` | New accounts stay inactive until the admin activates them |
| `LANGFLOW_CUSTOM_COMPONENT_ADMIN_ONLY` | `true` | `false` lets every user write custom components (Python on your server) |
| `LANGFLOW_WORKERS` | `1` | More workers handle more parallel runs, but each uses more memory |
| `LANGFLOW_LOG_LEVEL` | `info` | `debug` for troubleshooting |
| `LANGFUSE_BASE_URL`, `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY` | empty | Optional Langfuse tracing, see below |

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `LANGFLOW_SECRET_KEY` | generated | Signs logins and encrypts saved credentials. **Never change it after the first deploy** |
| `LANGFLOW_DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Private network |
| `LANGFLOW_CONFIG_DIR` | `/app/langflow` | On the volume: uploaded files, cache |
| `LANGFLOW_AUTO_LOGIN` | `false` | `true` would let anyone in as admin |
| `LANGFLOW_ACCESS_SECURE`, `LANGFLOW_REFRESH_SECURE` | `true` | Login cookies only over HTTPS |
| `PORT`, `LANGFLOW_PORT`, `LANGFLOW_HOST` | `7860`, `0.0.0.0` | |
| `RAILWAY_RUN_UID` | `0` | The image runs as user 1000, but Railway volumes belong to root. Running as root lets Langflow write to the volume |
| `DO_NOT_TRACK` | `true` | Langflow telemetry off |

## Tracing with Langfuse

Set on `langflow`:

| Variable | Value |
|---|---|
| `LANGFUSE_BASE_URL` | Your Langfuse URL, for example from our [Langfuse v4 template](../langfuse/) or `https://cloud.langfuse.com` |
| `LANGFUSE_PUBLIC_KEY` | `pk-lf-...` from the Langfuse project |
| `LANGFUSE_SECRET_KEY` | `sk-lf-...` from the Langfuse project |

If Langfuse runs in the same Railway project, you can use its private address. Langflow bundles the Langfuse Python SDK v3; see Langflow's [Langfuse integration](https://docs.langflow.org/integrations-langfuse) docs.

## Scaling

The template runs one worker (`LANGFLOW_WORKERS=1`) with an in-process job queue and an in-memory cache. That's enough for one person or a small team, and Langflow logs a warning about it at start that you can ignore.

To run several workers or replicas, the workers must share running jobs and the cache through Redis. Otherwise a request that lands on another worker can't see a running flow's events or cancel it.

1. Add Redis to the project (**+ Create → Database → Redis**).
2. Set on `langflow`:

| Variable | Value |
|---|---|
| `LANGFLOW_JOB_QUEUE_TYPE` | `redis` |
| `LANGFLOW_REDIS_QUEUE_URL` | `${{Redis.REDIS_URL}}` |
| `LANGFLOW_CACHE_TYPE` | `redis` |
| `LANGFLOW_REDIS_URL` | `${{Redis.REDIS_URL}}` |
| `LANGFLOW_WORKERS` | for example `2` or `4`; each worker needs about 1 GB of RAM |

If Redis is set but unreachable, Langflow stops at start with a message that names the setting. With Redis, Langflow 1.13 logs two warnings you can ignore: that the Redis cache is experimental, and that the separate background worker isn't available, so flows still run inside the web workers.

## Upgrading

Change the image tag (for example `langflowai/langflow:1.13.2`). Langflow runs database migrations on start, and can't go back to an older version after that. Read the [release notes](https://github.com/langflow-ai/langflow/releases) first. If a flow needs components that the default image doesn't include, use `langflowai/langflow-all` with the same version.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Login fails with the generated password | The admin is created on the first start only. If you changed `LANGFLOW_SUPERUSER_PASSWORD` later, use the old password |
| Saved API keys stop working after a change | `LANGFLOW_SECRET_KEY` was changed. Restore the old value |
| Out of memory, or the service restarts during runs | Langflow needs about 1–2 GB of RAM. Lower `LANGFLOW_WORKERS`, or raise the service's memory limit |
| A starter project is missing | The default image skips templates whose components it doesn't include (for example ArXiv). Use `langflowai/langflow-all` |
| Embedded chat on another site can't reach Langflow | Langflow allows all origins by default (without cookies). If you set `LANGFLOW_CORS_ORIGINS`, include your site |
| `Permission denied` on `/app/langflow` | `RAILWAY_RUN_UID` must be `0` |

## Testing

Tested on 2026-11-04 with Langflow 1.13.1 in a throwaway Railway project: both services healthy. Without a login, the API returned 403. A wrong password was refused, the generated admin password logged in, and public sign-up was refused. A credential variable and an uploaded file were saved, and both were still there after a redeploy. The scaling setup above (Redis, 2 workers) started, and login and saved data worked across repeated requests. In a second run: logged in through the browser, opened a flow in the editor and got a reply in the Playground; ran the same flow through the API with an API key (refused without one); added and activated a user with the commands above, who saw none of the admin's flows; all data was still there after a redeploy.
