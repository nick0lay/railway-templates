# Langfuse v4 + LiteLLM

Self-hosted [LiteLLM](https://github.com/BerriAI/litellm) gateway with [Langfuse](https://github.com/langfuse/langfuse) v4 tracing already connected. Point any OpenAI-compatible app at LiteLLM, and every call to OpenAI, Anthropic, Gemini, Bedrock or 100+ other providers appears in Langfuse with its prompt, response, tokens, cost and latency. No SDK or code changes in your app.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/langfuse-v4-litellm?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

It is the [Langfuse v4 template](../langfuse/) plus LiteLLM and LiteLLM's own Postgres.

## Architecture

```
            Your apps (OpenAI-compatible SDKs)         You (browser)
                    │ HTTPS                              │ HTTPS
                    ▼                                    ▼
┌────────────────────────────────────────────────────────────────────┐
│ Railway project                                                    │
│                                                                    │
│  litellm :4000 (public) ── /v1/* API, admin UI at /ui              │
│     │   │                                                          │
│     │   └── litellm-postgres :5432 (volume)  models, keys, spend   │
│     │                                                              │
│     │ OpenTelemetry over the private network                       │
│     ▼                                                              │
│  langfuse-web :3000 (public) ── UI, public API, OTel, MCP          │
│     ├── Postgres    :5432 (volume)  users, projects, keys          │
│     ├── ClickHouse  :8123/:9000 (volume)  traces, scores           │
│     ├── Redis       :6379 (volume)  queues (BullMQ)                │
│     └── Bucket      (Railway Bucket)  raw events, media            │
│                                                                    │
│  langfuse-worker :3030 (private) ── ingestion, evals, exports      │
└────────────────────────────────────────────────────────────────────┘
                    │
                    ▼
        LLM providers (OpenAI, Anthropic, Gemini, ...)
```

## Services

| Service | Source | Role |
|---------|--------|------|
| litellm | `litellm/litellm-database:v1.109.1` | OpenAI-compatible gateway, virtual keys, budgets, admin UI (public) |
| litellm-postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | LiteLLM models, virtual keys, spend logs (private) |
| langfuse-web | `langfuse/langfuse:4.80` | Langfuse UI, public API, OpenTelemetry ingestion, MCP endpoint (public) |
| langfuse-worker | `langfuse/langfuse-worker:4.80` | Processes ingested events, evaluations, exports (private) |
| ClickHouse | `../clickhouse/clickhouse/Dockerfile` (26.8 LTS) | Traces, observations, scores (private) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Langfuse users, projects, API keys, prompts (private) |
| Redis | `redis:8.10` with `--maxmemory-policy noeviction` | Langfuse job queues (private) |
| Bucket | Railway Bucket | Raw events, media and batch exports |

## What this template does differently

- **Tracing is wired up.** LiteLLM starts with the `langfuse_otel` callback and the init keys of the Langfuse project, and sends traces over Railway's private network. The first request you make through LiteLLM is in Langfuse.
- **Separate databases.** LiteLLM and Langfuse both manage their schemas with Prisma, and LiteLLM can run `prisma db push --accept-data-loss` on start. Sharing one database could drop Langfuse's tables, so LiteLLM has its own Postgres.
- **Everything from the [Langfuse v4 template](../langfuse/README.md#what-this-template-does-differently):** admin account, organization, project and API keys created on first boot, sign-up closed, Redis set to `noeviction`, pinned and tested versions, lean ClickHouse, Railway Bucket.
- **LiteLLM secrets generated.** Master key, salt key and admin UI password are generated per deploy.

## After deploy

1. **Langfuse:** open the `langfuse-web` URL and log in with `LANGFUSE_INIT_USER_EMAIL` and the generated `LANGFUSE_INIT_USER_PASSWORD` (variables of `langfuse-web`).
2. **LiteLLM:** open `https://<litellm-domain>/ui` and log in as `admin` with `UI_PASSWORD` (variable of `litellm`). Add a model under **Models + Endpoints**, with your provider key. Keys you enter there are stored encrypted with `LITELLM_SALT_KEY`.
3. **Call it** with the master key, or create a virtual key per app or team in the UI:

```bash
curl https://<litellm-domain>/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-4o-mini", "messages": [{"role": "user", "content": "Hello"}]}'
```

Any OpenAI SDK works: set its base URL to `https://<litellm-domain>/v1` and its API key to a LiteLLM key.

```python
from openai import OpenAI
client = OpenAI(base_url="https://<litellm-domain>/v1", api_key="sk-...")
client.chat.completions.create(model="gpt-4o-mini", messages=[{"role": "user", "content": "Hello"}])
```

4. **See the trace** in Langfuse under **Tracing**: a `litellm_request` generation with the model, prompt, response, tokens and cost.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| langfuse-web | `LANGFUSE_INIT_USER_EMAIL` | (required) | Langfuse admin login |
| litellm | `OPENAI_API_KEY`, `ANTHROPIC_API_KEY` | empty | Optional. You can also add provider keys per model in the LiteLLM UI |
| litellm | `UI_USERNAME` | `admin` | LiteLLM admin UI login |

All Langfuse settings (SMTP, sign-up, names) are described in the [Langfuse v4 README](../langfuse/README.md#variables).

### Generated (read them after deploy)

| Service | Variable | Notes |
|---|---|---|
| litellm | `LITELLM_MASTER_KEY` | Admin API key: calls the API and creates virtual keys. Keep it private |
| litellm | `UI_PASSWORD` | LiteLLM admin UI password |
| litellm | `LITELLM_SALT_KEY` | Encrypts provider keys stored in the database. **Never change it after the first deploy**, or stored keys can't be decrypted |
| langfuse-web | `LANGFUSE_INIT_USER_PASSWORD` | Langfuse admin password |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| litellm | `DATABASE_URL` | `${{litellm-postgres.DATABASE_URL}}` | LiteLLM's own database. Don't point it at Langfuse's Postgres |
| litellm | `LANGFUSE_HOST` | `http://${{langfuse-web.RAILWAY_PRIVATE_DOMAIN}}:${{langfuse-web.PORT}}` | Traces go over the private network |
| litellm | `LANGFUSE_PUBLIC_KEY` / `LANGFUSE_SECRET_KEY` | `${{langfuse-web.LANGFUSE_INIT_PROJECT_*_KEY}}` | Keys of the Langfuse project created on first boot |
| litellm | `STORE_MODEL_IN_DB` | `True` | Models and keys added in the UI are saved in Postgres |
| litellm | `LITELLM_LOCAL_MODEL_COST_MAP` | `True` | Uses the model price list bundled in the image, so start doesn't depend on downloading it |
| litellm | start command | writes `{litellm_settings: {callbacks: [langfuse_otel]}}` to `/tmp/litellm.yaml` and starts LiteLLM with it | LiteLLM has no environment variable for callbacks |

## Sending traces to another Langfuse project

The Langfuse keys on `litellm` are references to the project created on first boot. To trace into another project, create API keys in that project and replace `LANGFUSE_PUBLIC_KEY` and `LANGFUSE_SECRET_KEY` on `litellm` with them. If you delete or rotate the init project's keys in Langfuse, update these variables too, or tracing stops.

## Upgrading

- **LiteLLM:** change the `litellm` image tag (for example `litellm/litellm-database:v1.107.x`). Use the `-database` image: it contains the Prisma binaries for migrations. Read the [release notes](https://github.com/BerriAI/litellm/releases) first; LiteLLM releases often.
- **Langfuse:** see [Langfuse v4 → Upgrading](../langfuse/README.md#upgrading).

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| No traces in Langfuse | Check `litellm` logs for `langfuse_otel` in "Initialized Callbacks". If you set your own start command or config, keep `callbacks: [langfuse_otel]`. The legacy `langfuse` callback doesn't work with Langfuse v4 |
| Traces stopped after changing keys in Langfuse | Update `LANGFUSE_PUBLIC_KEY` / `LANGFUSE_SECRET_KEY` on `litellm` |
| `litellm` fails with a YAML `ParserError` | The start command was edited with `\n`. Railway removes backslashes from start commands; keep the config on one line |
| Stored provider keys fail after a redeploy | `LITELLM_SALT_KEY` was changed. Restore the old value |
| `401` from LiteLLM | Use the master key or a virtual key as `Authorization: Bearer ...` |
| Langfuse issues | See [Langfuse v4 → Troubleshooting](../langfuse/README.md#troubleshooting) |

## Testing

Tested on 2026-11-03 with test deploys, first of the template config and then of the template draft: all seven services healthy. A chat completion through LiteLLM (a model added with `/model/new` and `mock_response`, so no provider was called) appeared in Langfuse as a `litellm_request` generation with its model and input, over the private network.
