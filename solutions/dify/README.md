# Dify

Self-hosted [Dify](https://github.com/langgenius/dify) on Railway: build LLM apps, chatflows, agents, workflows and knowledge bases (RAG) in a visual editor, with 100+ model providers. The full upstream stack runs on Railway's private network: API, Celery worker and scheduler, web console, code sandbox, plugin daemon, SSRF proxy, PostgreSQL, pgvector, Redis and a Railway Bucket for files.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/dify-119-1?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

Dify is pinned to a stable release, the admin account is created at deploy time, and only one service is public: the gateway, behind the Dify login.

## Architecture

```
                 You (browser)                 Your apps
                       │ HTTPS                    │ Bearer app-... key
                       ▼                          ▼
┌────────────────────────────────────────────────────────────────────┐
│ Railway project                                                    │
│                                                                    │
│   Dify :8080 gateway (public, admin login)                         │
│     │ /console/api /api /v1 /files ...     │ /            │ /e/    │
│     ▼                                      ▼              ▼        │
│   dify-api :5001 ──────────────────► dify-web :3000  dify-plugin-  │
│     │   │   │   └──► dify-sandbox :8194              daemon :5002  │
│     │   │   │        (Code nodes)          │         (volume)      │
│     ▼   │   ▼                              │                       │
│ Dify    │  Dify Vector (pgvector)          │                       │
│ Postgres│                                  │                       │
│     ▲   ▼                                  ▼                       │
│     │  Dify Redis ◄── dify-worker, dify-beat                       │
│     │  Bucket (files) ◄──┘                                         │
│     │                                                              │
│   HTTP Request nodes, Code nodes ──► dify-ssrf-proxy :3128 ──► internet
└────────────────────────────────────────────────────────────────────┘
```

Only the `Dify` gateway is public. Every other service, both Postgres databases, Redis and the Bucket stay private.

## Services

| Service | Source | Role |
|---------|--------|------|
| Dify | `nginx:1.30.6-alpine` | Gateway: one public origin for the console, the APIs and plugin hooks (public, admin login) |
| dify-api | `langgenius/dify-api:1.19.0` | Console and service API, runs migrations, creates the admin account |
| dify-worker | `langgenius/dify-api:1.19.0` | Celery worker: document indexing, workflow storage, mail |
| dify-beat | `langgenius/dify-api:1.19.0` | Celery beat: scheduled tasks |
| dify-web | `langgenius/dify-web:1.19.0` | Console UI and published web apps |
| dify-sandbox | `langgenius/dify-sandbox:0.2.15` | Runs Python and JavaScript Code nodes |
| dify-plugin-daemon | `langgenius/dify-plugin-daemon:0.6.14-local` | Runs model provider and tool plugins (volume for installed plugins) |
| dify-ssrf-proxy | `ubuntu/squid:6.6-24.04_beta` | Outbound proxy for HTTP and Code nodes; blocks private addresses |
| Dify Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Dify data (`railway` database) and plugin data (`dify_plugin`) |
| Dify Vector | `pgvector/pgvector:0.8.7-pg16` | Vector store for knowledge bases |
| Dify Redis | `redis:8.10` | Cache, sessions and the Celery queue |
| Bucket | Railway Bucket | Uploaded files, knowledge base documents, workspace keys |

## What this template does differently

- **The admin exists before anyone can open the page.** Fresh Dify lets the first visitor create the admin at `/install`. Here a start-up script on `dify-api` creates the admin from `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD` (variables of the `Dify` service) as soon as the API is up. `/install` is also guarded by a generated `INIT_PASSWORD`, so nobody can claim the instance even before the script runs.
- **The full stack.** Scheduler (`dify-beat`), SSRF proxy, plugin daemon with a volume and a sandbox are all included, as in upstream's compose file. Without the scheduler, scheduled tasks and cleanups never run; without the proxy, HTTP nodes can reach private services.
- **No Weaviate, no MinIO.** Knowledge bases use pgvector in its own Postgres, and files go to a Railway Bucket. The MinIO repository was archived upstream, and its Docker Hub images are gone.
- **One public origin.** Dify's console uses `__Host-` cookies, and two separate `*.up.railway.app` domains can't share them. The nginx gateway serves the UI, the APIs and plugin endpoints from one domain, following upstream's routes.
- **No default secrets.** Upstream compose ships fixed keys for the plugin daemon, the sandbox and the inner API. Here every one is generated per deploy.
- **Pinned, tested versions:** Dify 1.19.0 with the sandbox and plugin daemon versions its compose file pins, PostgreSQL 18, pgvector 0.8.7, Redis 8.10.

Not included: the Agent V2 backend and its local sandbox (new in Dify 1.19 and off here: `NEXT_PUBLIC_ENABLE_AGENT_V2=false`), the collaboration websocket and the plugin remote-debugging port. Classic Agent apps, chatflows, workflows and knowledge bases work without them.

## Resources

The stack has eleven services. Expect about 3 GB of RAM in total when idle; dify-api, dify-worker and the plugin daemon use the most. Lower `CELERY_WORKER_AMOUNT` on `dify-worker` to save memory.

## After deploy

**1. Log in**

Open the `Dify` URL and log in with `ADMIN_EMAIL` and `ADMIN_PASSWORD` from the `Dify` service variables. The script runs once: later edits to these variables do nothing. Change the password in Dify (avatar → Account).

**2. Add a model**

Go to **Settings → Model Provider** and install a provider (OpenAI, Anthropic, Gemini, Ollama, OpenRouter...) from the Marketplace. Paste its API key. Without a model, LLM and Agent nodes fail with `Provider ... does not exist`.

**3. Build and publish an app**

Create a **Workflow**, **Chatflow**, **Chatbot** or **Agent**, click **Publish**, then open **API Access → API Key → Create** and copy the `app-...` key.

```bash
URL=https://your-dify-domain
KEY=app-YOUR_KEY

# Chat apps (Chatflow, Chatbot, Agent)
curl -X POST "$URL/v1/chat-messages" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"inputs":{},"query":"Hello","response_mode":"blocking","user":"user-1"}'

# Workflow apps
curl -X POST "$URL/v1/workflows/run" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"inputs":{"name":"Railway"},"response_mode":"blocking","user":"user-1"}'
```

Other services in the same Railway project can use `DIFY_PRIVATE_API_URL` of the `Dify` service (`http://dify-api.railway.internal:5001/v1`) instead of the public URL.

API reference: https://docs.dify.ai

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Dify | `ADMIN_EMAIL` | `admin@example.com` | Admin login. Change it to your own before deploying |
| dify-api | `ADMIN_NAME` | `Admin` | |
| dify-worker | `CELERY_WORKER_AMOUNT` | `4` | Parallel background tasks |
| dify-sandbox | `WORKER_TIMEOUT`, `ENABLE_NETWORK` | `15`, `true` | Code node time limit, internet access through the proxy |
| dify-ssrf-proxy | `SQUID_CONFIG` | squid rules | Add `acl ... dstdomain` and `http_access allow` lines (before `deny private_dst`) to let Dify reach a private service |

### Generated

| Service | Variable | Notes |
|---|---|---|
| Dify | `ADMIN_PASSWORD` | Initial admin password. Used once |
| dify-api | `INIT_PASSWORD` | Guards `/install` |
| dify-api | `SECRET_KEY` | Signs sessions and encrypts stored keys; worker and beat use the same key. **Never change it after the first deploy** |
| dify-plugin-daemon | `SERVER_KEY`, `DIFY_INNER_API_KEY` | Keys between dify-api and the plugin daemon |
| dify-sandbox | `API_KEY` | Key dify-api uses to run code |

### Auto-configured (do not change)

| Service | Variable | Value |
|---|---|---|
| Dify | `DIFY_PRIVATE_API_URL`, `DIFY_PUBLIC_API_URL` | Service API URLs, private and public |
| Dify | `NGINX_CONFIG`, `GATEWAY_START_SH` | Gateway routes and start script |
| dify-api | `DIFY_SETUP_PY` | Script that creates the admin account once |
| dify-api, worker, beat | `CONSOLE_*`, `APP_*`, `SERVICE_API_URL`, `FILES_URL`, `TRIGGER_URL`, `ENDPOINT_URL_TEMPLATE` | Public gateway domain |
| dify-api, worker, beat | `DB_*`, `REDIS_*`, `CELERY_BROKER_URL`, `PGVECTOR_*`, `S3_*` | Dify Postgres, Dify Redis, Dify Vector, Bucket |
| dify-api, worker, beat | `CODE_EXECUTION_*`, `PLUGIN_DAEMON_*`, `SSRF_PROXY_*` | Sandbox, plugin daemon and proxy addresses and keys |
| dify-api, worker, beat | `DISABLE_TELEMETRY` | `true` |

## Custom domains

Add the domain on the `Dify` service. Then replace `${{Dify.RAILWAY_PUBLIC_DOMAIN}}` with your domain in the URL variables of `dify-api`, `dify-worker`, `dify-beat` and `dify-web`.

## Upgrading

Change `dify-api`, `dify-worker`, `dify-beat` and `dify-web` to the same version, and the sandbox and plugin daemon to the versions in that release's `docker/docker-compose.yaml`. dify-api migrates the database on start. Back up `Dify Postgres` first.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Can't log in | Use `ADMIN_EMAIL` and `ADMIN_PASSWORD` from the `Dify` variables; `dify-api` logs show `[dify-setup]`. After a password change in Dify, the variable is stale |
| `Provider ... does not exist` | No model provider installed; see step 2 |
| `401` from `/v1/...` | The `Authorization: Bearer app-...` header is missing, or the key belongs to another app |
| HTTP node can't reach a private service | The SSRF proxy blocks private addresses; add the host to `SQUID_CONFIG` |
| Documents stay "queuing" | `dify-worker` isn't running; check its logs |
| Plugin install fails | Check `dify-plugin-daemon` logs; it needs internet access and time to install Python packages |
| The first start is slow | dify-api runs migrations on first start; the gateway shows errors until it is healthy |

## License

Dify: [Dify Open Source License](https://github.com/langgenius/dify/blob/main/LICENSE), based on Apache 2.0 with conditions. Don't run it as a multi-tenant service without a commercial license from LangGenius, and keep the Dify logo and copyright in the console. You are responsible for complying with the license when you deploy it.

## Testing

Tested on 2026-11-18 with two test deploys of the template draft: all 11 services healthy, migrations done and the admin created at first start, about 2.9 GB of RAM in total when idle.

Dify reported setup finished and refused an anonymous setup and init (403), its console API without a login (401), a wrong password and an unknown account. The generated admin password worked. The plugin daemon answered through dify-api. A text file uploaded to an economy-mode knowledge base was stored in the Bucket, indexed by the worker and found by keyword search.

A Workflow app built through Dify's API with no LLM (Start, Template, Python Code node, HTTP Request to a public site, HTTP Request to dify-api's private address, End) was published. Its API key ran it on the public `/v1/workflows/run`: the Code node returned its result from the sandbox, the public request went out through the SSRF proxy, and the proxy refused the private one (403 in its log). A missing or wrong key got 401. After redeploying dify-api, the worker, the plugin daemon, Dify Postgres and Dify Vector, the login, the app, its published workflow and the knowledge base were still there, the setup script did nothing, and the workflow ran again with the same key.

Not tested:
- A real LLM provider, and so LLM, Agent and RAG answers.
- Embedding-based (high-quality) knowledge bases, which are the only path that uses pgvector.
- Plugin installation from the Marketplace.
- Custom domains.
