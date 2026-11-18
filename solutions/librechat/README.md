# LibreChat

Self-hosted [LibreChat](https://github.com/danny-avila/LibreChat) on Railway: a ChatGPT-style chat app for OpenAI, Anthropic, Google Gemini, OpenRouter, Groq, Mistral, DeepSeek, xAI and any OpenAI-compatible API, with agents, MCP tools, file search (RAG), conversation search and multiple users. The full upstream stack (MongoDB, Meilisearch, RAG API, pgvector) runs on Railway's private network. The admin account is created for you at deploy and public sign-up is off. Every image is pinned to a tested release.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/librechat-089?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
                         You / your team
                           │ HTTPS
                           ▼
┌───────────────────────────────────────────────────────────────┐
│ Railway project                                               │
│                                                               │
│  LibreChat :3080 (public, login required)                     │
│    web client + API, volume /app/data (uploads, images)       │
│      │                │                    │                  │
│      ▼                ▼                    ▼                  │
│  MongoDB :27017   Meilisearch :7700    RAG-API :8000          │
│  (private,        (private, master     (private, checks       │
│   volume)          key, volume)         LibreChat's JWT)      │
│  users, chats,    conversation search       │                 │
│  keys, files                                ▼                 │
│                                        VectorDB :5432         │
│                                        (pgvector, private,    │
│                                         volume) embeddings    │
└───────────────────────────────────────────────────────────────┘
          │                                     │
          ▼                                     ▼
   LLM provider APIs                  OpenAI embeddings API
   (OpenAI, Anthropic, ...)           (file search)
```

## Services

| Service | Source | Role |
|---------|--------|------|
| LibreChat | `ghcr.io/librechat-ai/librechat:v0.8.9` | Web client and API (public) |
| MongoDB | `mongo:8.0.20` | Users, conversations, stored keys, file records (private, volume) |
| Meilisearch | `getmeili/meilisearch:v1.35.1` | Conversation search (private, volume) |
| RAG-API | `ghcr.io/librechat-ai/librechat-rag-api-dev-lite:v0.9.0` | File search: chunks and embeds uploaded files (private) |
| VectorDB | `pgvector/pgvector:0.8.0-pg15-trixie` | Embeddings for file search (private, volume) |

MongoDB, Meilisearch and pgvector use the versions pinned in LibreChat's own docker-compose for v0.8.9.

## What this template does differently

- **Admin account created at deploy, sign-up off.** On a fresh LibreChat with open registration, anyone who finds the URL can sign up, and the first account becomes the admin. Every signed-up user can then spend the API keys you set on the server. This template creates the admin from `ADMIN_EMAIL` and a generated `ADMIN_PASSWORD` with LibreChat's own `create-user` command, and keeps `ALLOW_REGISTRATION=false`.
- **Pinned releases.** LibreChat v0.8.9 and RAG API v0.9.0 instead of the `librechat-dev:latest` / `rag-api-dev-lite:latest` nightly builds that upstream compose files use, so a redeploy doesn't pull an untested build.
- **Uploads persist.** A volume at `/app/data` keeps uploaded files, generated images and avatars across redeploys.
- **Config file in a variable.** `LIBRECHAT_YAML` is written to `librechat.yaml` at start. It adds OpenRouter, Groq, Mistral, DeepSeek and xAI next to the built-in OpenAI, Anthropic and Google; edit it in the Railway dashboard to add providers, MCP servers or interface settings.
- **File search works with your OpenAI key.** The RAG API takes its embeddings key from LibreChat's `OPENAI_API_KEY`, so setting one key turns on both chat and file search.
- **Scheduled agent runs work.** `SCHEDULES_SINGLE_PROCESS=true` tells LibreChat it runs as one replica; without it (and without Redis) LibreChat refuses schedule writes.
- **Private by default.** Only LibreChat has a public domain. MongoDB has authentication on (upstream compose runs it with `--noauth`), Meilisearch runs in production mode with a generated master key, and the RAG API only accepts requests signed with LibreChat's `JWT_SECRET`.
- **Abuse limits on.** Login, sign-up and message rate limits and automatic bans are set, and search engines are asked not to index the server.

## After deploy

1. Open the LibreChat URL and log in with `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD` (both on the LibreChat service's Variables tab).
2. Pick a provider in the model menu. By default every provider key is `user_provided`: each user enters their own key in the chat window. To pay for everyone, put your key in the variable (for example `OPENAI_API_KEY=sk-...`) and redeploy.
3. Add users: set `ALLOW_REGISTRATION=true`, redeploy, let them sign up, then set it back to `false`.

## Variables

### User-configurable

| Variable | Default | Notes |
|---|---|---|
| `ADMIN_EMAIL` | `admin@example.com` | Admin login, created on first start. Set your own before deploying |
| `ADMIN_PASSWORD` | generated | Admin password. Changing it later does not change the existing account's password |
| `ALLOW_REGISTRATION` | `false` | Open sign-up |
| `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_KEY` | `user_provided` | Built-in providers |
| `OPENROUTER_KEY`, `GROQ_API_KEY`, `MISTRAL_API_KEY`, `DEEPSEEK_API_KEY`, `XAI_API_KEY` | `user_provided` | Providers defined in `LIBRECHAT_YAML` |
| `ENDPOINTS` | `openAI,agents,anthropic,google,custom` | Providers shown, in order |
| `LIBRECHAT_YAML` | providers above | Full `librechat.yaml`; see the [config reference](https://www.librechat.ai/docs/configuration/librechat_yaml) |
| `CONFIG_PATH` | empty | URL of a `librechat.yaml` to use instead |
| `APP_TITLE` | `LibreChat` | Name in the tab and on the login page |
| `ALLOW_SOCIAL_LOGIN` | `false` | Google/GitHub/Discord login; needs OAuth app variables from the LibreChat docs |
| RAG-API `RAG_OPENAI_API_KEY` | LibreChat's `OPENAI_API_KEY` | Embeddings key for file search |
| RAG-API `EMBEDDINGS_PROVIDER`, `EMBEDDINGS_MODEL` | `openai`, `text-embedding-3-small` | Other providers: azure, huggingface, ollama, bedrock, google_genai |

Rate limits (`LOGIN_MAX`, `MESSAGE_IP_MAX`, `BAN_*` ...) follow LibreChat's recommended values and can be changed on the LibreChat service.

### Auto-configured (do not change)

| Variable | Service | Why |
|---|---|---|
| `CREDS_KEY`, `CREDS_IV` | LibreChat | Encrypt the API keys users store. New values make stored keys unreadable |
| `JWT_SECRET`, `JWT_REFRESH_SECRET` | LibreChat | Sign logins; the RAG API checks `JWT_SECRET`. New values log everyone out |
| `MONGO_URI` | LibreChat | MongoDB over the private network, with the MongoDB service's credentials |
| `MEILI_HOST`, `MEILI_MASTER_KEY` | LibreChat | Meilisearch over the private network and its key (from the Meilisearch service) |
| `RAG_API_URL` | LibreChat | `http://${{RAG-API.RAILWAY_PRIVATE_DOMAIN}}:8000` |
| `DB_HOST`, `POSTGRES_*`, `JWT_SECRET` | RAG-API | pgvector connection and LibreChat's JWT secret |
| `LIBRECHAT_START_SH`, `RAILWAY_RUN_UID` | LibreChat | Start script (volume links, config file, admin account); runs as root so it can write to the volume |

## Upgrading

Change the LibreChat image tag on the service (for example to a newer `v0.8.x` from the [releases](https://github.com/danny-avila/LibreChat/releases)) and redeploy; LibreChat migrates MongoDB on start. Read the release notes first: LibreChat marks every release as a pre-release and sometimes changes configuration between versions. Bump `version:` in `LIBRECHAT_YAML` when the release notes ask for it.

## Troubleshooting

- **"No key found" when chatting.** The provider is set to `user_provided`: click the key icon next to the model menu and enter your key, or set the key on the server.
- **File upload fails with "Error processing file".** File search needs an embeddings key. Set `OPENAI_API_KEY` on LibreChat (or `RAG_OPENAI_API_KEY` on RAG-API) and redeploy RAG-API.
- **Forgot the admin password.** Changing `ADMIN_PASSWORD` does not reset it. Open a shell on the LibreChat service and run `npm run reset-password`.
- **A provider is missing from the model menu.** Check `ENDPOINTS` and, for OpenRouter/Groq/Mistral/DeepSeek/xAI, `LIBRECHAT_YAML`.
- **Memory.** LibreChat uses about 500 MB to 1 GB of RAM; the whole stack about 1.5 to 2 GB.

## Tested

2026-11-18: deployed from the template; anonymous API calls, forged tokens, sign-up and a wrong password refused; admin login works; chat without a key returns a "no key" error; chat with an OpenAI key answers; a file upload is embedded by the RAG API into pgvector; after redeploying MongoDB, Meilisearch, pgvector and LibreChat the admin, the stored keys, conversations and files were kept.

## License

LibreChat and the RAG API are MIT-licensed, Meilisearch Community Edition is MIT, pgvector uses the PostgreSQL License, and MongoDB Community Server is under the SSPL. This template only deploys the official images; you are responsible for complying with these licenses and with the terms of the LLM providers you connect.
