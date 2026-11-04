# Open WebUI

Self-hosted [Open WebUI](https://github.com/open-webui/open-webui) on Railway: a ChatGPT-style interface for OpenAI, Anthropic (through an OpenAI-compatible gateway), OpenRouter, Groq, Ollama and any other OpenAI-compatible API, with chat history, document chat (RAG), web search, tools and multiple users. The admin account is created for you at deploy and public sign-up is off. Data lives in Postgres and on a volume, and the version is pinned and tested.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/open-webui-10?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
                     You / your team
                       │ HTTPS
                       ▼
┌──────────────────────────────────────────────────────┐
│ Railway project                                      │
│                                                      │
│  open-webui :8080 (public)                           │
│    chat UI, API, document processing                 │
│    volume /app/backend/data: uploads, document       │
│    index, embedding model cache                      │
│        │                                             │
│        ▼                                             │
│  Postgres :5432 (private, volume)                    │
│    users, chats, settings                            │
└──────────────────────────────────────────────────────┘
                       │
                       ▼
     OpenAI-compatible APIs (OpenAI, OpenRouter, LiteLLM, ...)
```

## Services

| Service | Source | Role |
|---------|--------|------|
| open-webui | `ghcr.io/open-webui/open-webui:v0.13.0` | Chat UI and API (public) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Users, chats, settings (private) |

## What this template does differently

- **Admin account created at deploy.** On a fresh Open WebUI, the first person to sign up becomes the admin. This template creates the admin on first start from `WEBUI_ADMIN_EMAIL` and a generated `WEBUI_ADMIN_PASSWORD`, and Open WebUI then turns public sign-up off. Nobody else can claim the instance.
- **Logins survive redeploys.** `WEBUI_SECRET_KEY` is generated once. Without it, Open WebUI writes a new key inside the container on every start, so every redeploy logs everyone out.
- **Data persists.** Postgres on a volume for users and chats, and a volume for uploaded files, the document index and the embedding model. Tested: a user, an uploaded document and a login token were all still valid after a redeploy.
- **Pinned version.** Open WebUI v0.13.0 and Postgres 18 instead of `:main`, so a redeploy doesn't pull an untested build.
- **No Ollama errors.** The Ollama connection is off, because no Ollama runs in the project. Turn it on if you run one.
- **Analytics off**, healthcheck on `/health`, and Postgres over the private network.

## After deploy

1. Open the `open-webui` URL and log in with `WEBUI_ADMIN_EMAIL` and the `WEBUI_ADMIN_PASSWORD` variable.
2. Add a model provider: set `OPENAI_API_KEY` (and `OPENAI_API_BASE_URL` for a provider other than OpenAI) on the service, or add connections under **Admin Panel → Settings → Connections**.
3. Add users under **Admin Panel → Users** (the **+** button). Public sign-up stays off.
4. Upload documents in a chat or under **Workspace → Knowledge** to chat with them. Documents are embedded on the server with the built-in `all-MiniLM-L6-v2` model, so no extra API key is needed.

### Providers

| Provider | `OPENAI_API_BASE_URL` |
|---|---|
| OpenAI | `https://api.openai.com/v1` (default) |
| OpenRouter (Claude, Gemini, Llama, ...) | `https://openrouter.ai/api/v1` |
| Groq | `https://api.groq.com/openai/v1` |
| LiteLLM in the same project | `http://${{litellm.RAILWAY_PRIVATE_DOMAIN}}:${{litellm.PORT}}/v1`, with the LiteLLM master key as `OPENAI_API_KEY` |

You can add several connections in Admin Settings; Open WebUI lists the models of all of them.

## Variables

### User-configurable

| Variable | Default | Notes |
|---|---|---|
| `WEBUI_ADMIN_EMAIL` | (required) | Email of the admin account. You log in with it |
| `WEBUI_ADMIN_PASSWORD` | generated | Read it after deploy. It's applied only when the admin is created on first start |
| `WEBUI_ADMIN_NAME` | `Admin` | Display name of the admin |
| `OPENAI_API_BASE_URL` | `https://api.openai.com/v1` | Any OpenAI-compatible API, see the table above |
| `OPENAI_API_KEY` | empty | Optional. Key for the API above |
| `ENABLE_OLLAMA_API` | `false` | Set `true` and `OLLAMA_BASE_URL` if you run Ollama somewhere |

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `WEBUI_SECRET_KEY` | generated | Signs logins. Changing it logs everyone out |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Private network |
| `DATA_DIR` | `/app/backend/data` | On the volume: uploads, document index, embedding model |
| `WEBUI_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Links and OAuth callbacks |
| `SCARF_NO_ANALYTICS`, `DO_NOT_TRACK`, `ANONYMIZED_TELEMETRY` | off | Analytics off |
| `PORT` | `8080` | |

All other settings (web search, image generation, speech, tools, OAuth) are in **Admin Panel → Settings**, or as [environment variables](https://docs.openwebui.com/reference/env-configuration).

## Scaling

The template runs one instance with the document index on its volume. That's enough for a team. Several replicas need a shared vector database (for example `VECTOR_DB=pgvector` or Qdrant) and Redis for websockets (`ENABLE_WEBSOCKET_SUPPORT=true`, `WEBSOCKET_MANAGER=redis`, `REDIS_URL`); see Open WebUI's [scaling guide](https://docs.openwebui.com/). We haven't tested a multi-replica setup.

## Upgrading

Change the image tag (for example `ghcr.io/open-webui/open-webui:v0.13.1`). Open WebUI migrates the database on start and can't go back to an older version after that. Read the [release notes](https://github.com/open-webui/open-webui/releases) first; Open WebUI releases often.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Login fails with the generated password | The admin is created on the first start only. If you changed `WEBUI_ADMIN_PASSWORD` or `WEBUI_ADMIN_EMAIL` later, use the old values |
| No models in the model list | No provider is configured. Set `OPENAI_API_KEY`, or add a connection in Admin Panel → Settings → Connections |
| Everyone is logged out after a redeploy | `WEBUI_SECRET_KEY` was changed or removed. Set it to a fixed value |
| Out of memory, or restarts while processing documents | Open WebUI with the local embedding model needs about 1–2 GB of RAM. Raise the service's memory limit, or switch embeddings to an API under Admin Panel → Settings → Documents |
| A user signs up and waits for approval | Sign-up was turned back on in Admin Settings; new users get the `pending` role until the admin approves them |

## License

Open WebUI uses its own [license](https://github.com/open-webui/open-webui/blob/main/LICENSE) (BSD-3-Clause plus a branding clause): you can self-host it, but keep the "Open WebUI" branding unless you qualify for an exception.

## Testing

Tested on 2026-11-04 with Open WebUI v0.13.0 in throwaway Railway projects, from the config and then from the template draft: both services healthy, and the admin was created at first start. A stranger's sign-up was refused, requests without a login were refused, a wrong password was refused and the admin logged in, through the API and in the browser (the login page offered no sign-up). The admin added a user, who could log in. A document was uploaded and embedded with the built-in model. After two redeploys, the admin login, the user, the document and an existing login token were all still valid. Chatting with a model was not tested, because it needs a provider key.
