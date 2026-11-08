# NVIDIA Auto Ontology

Self-hosted [NVIDIA Auto Ontology](https://github.com/NVIDIA/auto-ontology) on Railway. It builds a semantic layer over your databases: it reads the schemas, works out what tables, columns and joins mean, keeps a glossary of business terms, and answers questions in plain language with SQL it shows you. AI agents use the same layer through its MCP server.

This template runs NVIDIA's official 1.2.0 images: the web app, the API, the ingestion service and the MCP server, with PostgreSQL. A Chinook sample database is loaded on first start, so you can try it right away. The admin account is created at deploy, sign-up is off, and only the web app and the MCP server are public. Both need a login.

## Architecture

```
          You (browser)                      AI agents (Cursor, Claude, ...)
               │ HTTPS                                │ HTTPS /mcp + OAuth
               ▼                                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Railway project                                                     │
│                                                                     │
│  Auto Ontology (web) :3000  public ◄──── MCP :3003  public          │
│  login, UI, /api routes,     sign-in and  (asks the web app's API   │
│  permission checks           token check   as the signed-in user)   │
│        │                                                            │
│        ▼                                                            │
│  API :3001  private  ───────────►  Ingestion :3002  private         │
│  text-to-SQL, catalog,              reads your databases' schemas,  │
│  migrations                         embeds them (daily + on demand) │
│        │                                   │                        │
│        ▼                                   ▼                        │
│  Postgres :5432  private, volume                                    │
│  auto_ontology: catalog, semantic layer, embeddings, users          │
│  chinook: sample database (read-only user)                          │
└─────────────────────────────────────────────────────────────────────┘
        │
        ▼  HTTPS
   Model endpoints (NVIDIA API catalog by default): chat, embeddings, rerank
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Auto Ontology | `nvcr.io/nvidia/auto-ontology-frontend:1.2.0` | Web app and the public `/api` (login, sessions, API tokens, OAuth for MCP). Syncs its schema and creates the admin on start |
| API | `nvcr.io/nvidia/auto-ontology:1.2.0` | Text-to-SQL, catalog and semantic layer. Loads the sample database and runs migrations on start (private) |
| Ingestion | `nvcr.io/nvidia/auto-ontology:1.2.0` | Reads your databases' schemas and builds embeddings, once at start and then every 24 hours (private) |
| MCP | `nvcr.io/nvidia/auto-ontology-mcp:1.2.0` | MCP server for AI agents; users sign in with their Auto Ontology account |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:17` | Auto Ontology's data and the Chinook sample database (private, volume) |

Railway templates can't reference `nvcr.io` images directly, so the `api`, `web` and `mcp` folders hold one-line Dockerfiles (`FROM` the official image, pinned by digest). Railway pulls the image at build time; nothing is compiled.

## What this template does differently

- **Login on everything public.** Sign-up is off, so the only account is the admin created from `AUTO_ONTOLOGY_ADMIN_EMAIL` and a generated password; others join by invitation. The MCP server accepts only OAuth tokens that Auto Ontology issues to signed-in users.
- **API and ingestion stay private.** Only the web app and the MCP server have domains. Every `/api` call goes through the web app's permission checks; the Python API has no domain of its own.
- **Works on Railway's private network.** The API and ingestion service bind to `0.0.0.0` in NVIDIA's images. Railway's private DNS returns IPv6 addresses, so the start scripts bind them to IPv6 and IPv4.
- **Something to ask about on day one.** On first start, the API loads the [Chinook](https://github.com/lerocha/chinook-database) music-store database (11 tables, checksum-verified) into its own database with a read-only user, and `CONNECTION_STRINGS` points at it. Clear the variable to use your own databases.
- **No one-shot jobs.** Upstream runs the two migrations as separate containers. Here the API runs `alembic upgrade head` and the web app syncs its schema before each starts, so upgrades need no manual step.
- **Pinned.** NVIDIA's 1.2.0 images by digest, PostgreSQL 17.

## After deploy

1. Open the **Auto Ontology** URL and log in with `AUTO_ONTOLOGY_ADMIN_EMAIL` and `AUTO_ONTOLOGY_ADMIN_PASSWORD` (Auto Ontology service → Variables).
2. The ingestion service has already read the Chinook schema at start. With a valid model key it also built the embeddings; to rebuild, open **Settings → Semantic Compilation** and run it.
3. Ask a question in the chat, for example *"Which genres earned the most in 2025?"*. The answer shows the SQL it ran.
4. **Your own data:** set `CONNECTION_STRINGS` on the API service (comma-separated URLs such as `postgresql://user:pass@host:5432/db`, `snowflake://...`, `clickhouse://...`, `trino://...`, `mysql://...`), or clear it and add connections in **Settings → Connections**. Use a read-only database user.
5. **AI agents:** add the MCP server to your client. There are no credentials in the config; the client opens Auto Ontology's login page:

   ```json
   { "mcpServers": { "auto-ontology": { "url": "https://<your MCP domain>/mcp" } } }
   ```
6. **Scripts:** create an API token in the user menu → **API Tokens**, and send it as `x-api-key` to `https://<your Auto Ontology domain>/api/...`.

## Models

Auto Ontology calls four kinds of model: a reasoning model, a non-reasoning model (both chat), an embedding model and a reranker. The defaults use NVIDIA's hosted models, so no GPU is needed. Get a free `nvapi-` key at [build.nvidia.com](https://build.nvidia.com) and set it as `DEFAULT_MODELS_API_KEY`. It is used for all four.

Other providers:

- **Chat:** `DEFAULT_MODELS_ENDPOINT` and `DEFAULT_MODELS_MODEL`. Model names starting with `openai/`, `azure/` or `aws/` use an OpenAI client; all others use NVIDIA's client, which works with NIM and NVIDIA-compatible endpoints. For a different non-reasoning model, add `NON_REASONING_ENDPOINT`, `NON_REASONING_MODEL` and `NON_REASONING_API_KEY` (and `REASONING_*` likewise).
- **Embeddings:** `EMBED_ENDPOINT` and `EMBED_MODEL` take any OpenAI-compatible embeddings endpoint. Questions and ingestion must use the same model, so after changing it, run ingestion again.
- **Rerank:** `RERANK_ENDPOINT` URLs ending in `/reranking` or `/ranking` use NVIDIA NIM's format; URLs ending in `/rerank` use the `{"query", "documents"}` format (Cohere, Jina, vLLM). Set `RERANK_API_KEY` if it differs from the default key.

Set model variables on the **API** service; the Ingestion service references them.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Auto Ontology | `AUTO_ONTOLOGY_ADMIN_EMAIL` | (required) | Admin login |
| Auto Ontology | `AUTO_ONTOLOGY_ADMIN_PASSWORD` | generated | Re-applied on every start: change it here, not in the app |
| API | `DEFAULT_MODELS_API_KEY` | (required) | `nvapi-` key from build.nvidia.com, or your provider's key |
| API | `DEFAULT_MODELS_ENDPOINT`, `DEFAULT_MODELS_MODEL` | NVIDIA API catalog, `nvidia/nemotron-3.5-lightning-30b-a3b` | Chat model |
| API | `EMBED_ENDPOINT`, `EMBED_MODEL` | NVIDIA API catalog, `nvidia/nemotron-3.5-embed-1b` | Embeddings |
| API | `RERANK_ENDPOINT`, `RERANK_MODEL` | NVIDIA API catalog, `nvidia/nemotron-3.5-rerank-8b` | Reranker |
| API | `CONNECTION_STRINGS` | the Chinook sample | Databases to model; clear it to manage connections in the UI |
| API | `SAMPLE_DATA` | `true` | `false` skips loading Chinook on first start |
| API | `LLM_MAX_INFLIGHT` | `6` | Concurrent model requests; lower it if your endpoint returns 503 |
| Ingestion | `INGEST_INTERVAL_HOURS` | `24` | Hours between automatic ingestion runs |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Auto Ontology | `AUTH_SECRET` | generated | Signs sessions and tokens; changing it logs everyone out |
| Auto Ontology | `APP_URL` | Railway domain | Public URL; change it for a custom domain |
| Auto Ontology, MCP | `AUTO_ONTOLOGY_MCP_PUBLIC_URL` | MCP's Railway domain | Tokens are issued for this address; both must match |
| MCP | `AUTO_ONTOLOGY_API_URL` | web app's Railway domain | Where MCP clients sign in |
| Auto Ontology | `PYTHON_API_URL` | API private host | Private network |
| API | `INGESTION_SERVICE_URL` | Ingestion private host | Private network |
| Ingestion | `API_HEALTH_URL` | API private host | Ingestion waits until the API has run the migrations |
| all | `POSTGRES_*` | from Postgres | Private network |
| API | `SAMPLE_DB_*` | Chinook 1.4.5, generated password | Sample database and its read-only user |
| API, Ingestion, Auto Ontology | `API_RUN_SH`, `INGESTION_RUN_SH`, `WEB_RUN_SH` | scripts | Start scripts |
| Auto Ontology | `HOSTNAME` | `::` | Listen on IPv6 and IPv4 |

## Custom domain

Add the domain to the **Auto Ontology** service and set `APP_URL=https://ontology.example.com` on it. For a custom MCP domain, set `AUTO_ONTOLOGY_MCP_PUBLIC_URL` to the same `https://...` value on both the Auto Ontology and MCP services, and set `AUTO_ONTOLOGY_API_URL` on MCP to the web app's URL. Redeploy both.

## Upgrading

NVIDIA publishes the images on [NGC](https://catalog.ngc.nvidia.com) as `nvcr.io/nvidia/auto-ontology`, `auto-ontology-frontend` and `auto-ontology-mcp`, with the same version tag. Change the tag and digest in all three Dockerfiles together, then redeploy every service except Postgres; migrations run on start. Back up Postgres first.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Answers fail or ingestion logs `0/N row(s) embedded` | `DEFAULT_MODELS_API_KEY` is missing or wrong, or the model names don't exist on your endpoint. Fix it on the API service and redeploy API and Ingestion |
| Endpoint returns 503 under load | Lower `LLM_MAX_INFLIGHT` |
| MCP client: "Protected resource ... does not match" | `AUTO_ONTOLOGY_MCP_PUBLIC_URL` differs between the Auto Ontology and MCP services, or from the URL the client uses |
| MCP client can't find how to sign in | `AUTO_ONTOLOGY_API_URL` on MCP must be the web app's public URL; `https://<web>/.well-known/oauth-authorization-server` should return JSON |
| Settings → Connections can't add connections | `CONNECTION_STRINGS` is set; connections then come from it. Clear it to manage them in the UI |
| Ingestion stays at "API not ready" | The API failed to start; check its logs (Postgres reachable, migrations) |

## Testing

Tested on Railway on 2026-11-08 with the official 1.2.0 images and a placeholder model key; all 5 services started.

- **Refusals:** anonymous visitors are sent to `/login`, anonymous and wrong-token `/api` calls get 401, a stranger's sign-up gets 400 ("sign up is not enabled"), a wrong password 401, and the MCP server returns 401 without a token or with a made-up one.
- **Admin:** logs in as admin and sees the settings. The catalog lists the Chinook sample (11 tables and 64 columns read by the ingestion service). An API token works on `/api`.
- **MCP:** dynamic client registration, authorize (anonymous goes to login), consent, and PKCE token exchange all work. With the token, `initialize`, `tools/list` (`ask_question` and the other tools) and `check_readiness` run as the admin.
- **Redeploy:** after redeploying all 5 services, the admin, catalog and earlier API token were still there, and the sample wasn't loaded twice (25/25).
- **Not tested:** answering questions and building embeddings, which need a real model key.

Idle memory is about 1.2 GB for all five services (API 0.5 GB).
