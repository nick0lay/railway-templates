# LiteLLM 1.110 (Postgres + Redis)

Self-hosted [LiteLLM](https://github.com/BerriAI/litellm) proxy on Railway: an OpenAI-compatible AI gateway for 100+ model providers, with virtual keys, budgets, rate limits, spend tracking and an admin UI. This template runs the official `litellm-database` image at a pinned version with PostgreSQL 18 for keys and spend, and Redis for response caching and shared rate limits. The admin UI requires a login with a generated password.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/litellm-1110-postgres-redis?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
            Your apps, agents, teammates (OpenAI-compatible clients)
                               │ HTTPS, virtual key
                               ▼
┌───────────────────────────────────────────────────────────┐
│ Railway project                                           │
│                                                           │
│  LiteLLM :4000 (public)                                   │
│    /v1/* API (key required), /ui admin (login required)   │
│        │                         │                        │
│        ▼                         ▼                        │
│  Postgres :5432               Redis :6379                 │
│  (private, volume)            (private, volume, password) │
│  keys, teams, models,         response cache, rpm/tpm     │
│  spend logs                   counters                    │
└───────────────────────────────────────────────────────────┘
                               │
                               ▼
          OpenAI, Anthropic, Gemini, OpenRouter, ... (your provider keys)
```

## Services

| Service | Source | Role |
|---------|--------|------|
| LiteLLM | `litellm/litellm-database:v1.110.1` | Proxy API and admin UI (public). Migrates its database on start, healthcheck `/health/liveliness` |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Virtual keys, teams, users, models added in the UI, spend logs (private, volume) |
| Redis | `redis:8.10` | Response cache and rate-limit counters, password, append-only file on a volume, `maxmemory 256mb` with `volatile-lru` (private) |

## What this template does differently

- **Admin UI behind a login.** `UI_USERNAME` is `admin` and `UI_PASSWORD` is generated, so the UI never falls back to an empty password. Every API call needs the master key or a virtual key.
- **Redis wired into the proxy.** LiteLLM uses Redis only when its proxy config turns it on. Here the config turns on the Redis response cache and points `router_settings` at Redis, so rate limits and usage are shared when you add replicas.
- **Opt-in cache.** The cache runs in `default_off` mode with a 10 minute TTL: a request is cached only when it sends `"cache": {"use-cache": true}`. Agents and chat apps that expect fresh answers are not affected. Switch to `default_on` in `LITELLM_CONFIG` to cache everything.
- **Generated keys.** `LITELLM_MASTER_KEY` (admin API key) and `LITELLM_SALT_KEY` (encrypts provider keys stored in the database).
- **Keys and models in Postgres.** `STORE_MODEL_IN_DB=True`: models, provider credentials and virtual keys added in the UI or API survive redeploys.
- **Any model, one key.** The config routes any model name to its provider (`model: "*"`), so `gpt-4o-mini`, `anthropic/claude-haiku-4-5` or `gemini/gemini-2.5-flash` work as soon as the provider key is set. Unsupported parameters are dropped instead of failing the request.
- **Pinned versions.** LiteLLM v1.110.1, PostgreSQL 18 and Redis 8.10 instead of `latest`. LiteLLM releases often; you upgrade when you choose.
- **Private data services.** Postgres and Redis have volumes and no public TCP proxy; Redis has a password.
- **Healthcheck and restart policy.** Railway waits for `/health/liveliness` before it switches traffic, and restarts a crashed service.
- **Privacy defaults.** LiteLLM's anonymous telemetry is off, and the model price list bundled in the image is used instead of downloading it on start.

## After deploy

1. Open `https://your-litellm-domain/ui` and log in with `UI_USERNAME` and the `UI_PASSWORD` variable from the `LiteLLM` service.
2. Set the provider keys you use as variables on `LiteLLM` (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `OPENROUTER_API_KEY`), or add models with their own credentials under **Models** in the UI.
3. Create a virtual key per app or person under **Virtual Keys**, optionally with a budget, an rpm/tpm limit or a model allow-list.
4. Use it from any OpenAI client:

```bash
curl https://your-litellm-domain/v1/chat/completions \
  -H "Authorization: Bearer sk-your-virtual-key" \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-4o-mini", "messages": [{"role": "user", "content": "Hello"}]}'
```

Add `"cache": {"use-cache": true}` to the body to serve repeated identical requests from Redis.

## Variables

### User-configurable

| Variable | Default | Notes |
|---|---|---|
| `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `OPENROUTER_API_KEY` | empty | Optional. Provider keys used by the wildcard route. Add other providers' variables as needed |
| `UI_USERNAME` | `admin` | Admin UI user |
| `UI_PASSWORD` | generated | Admin UI password |
| `LITELLM_CONFIG` | wildcard + Redis | The proxy config, written to `/tmp/litellm.yaml` on start. Add fixed model aliases, fallbacks or callbacks here |
| `LITELLM_TELEMETRY` | `False` | LiteLLM's anonymous telemetry |

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `LITELLM_MASTER_KEY` | generated | Admin API key. Use it to create virtual keys; don't hand it out |
| `LITELLM_SALT_KEY` | generated | Encrypts provider keys stored in Postgres. **Never change it after the first deploy** |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Private network |
| `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD` | `${{Redis.*}}` | Private network, read by the cache and router config |
| `STORE_MODEL_IN_DB` | `True` | Keep models and keys added in the UI in Postgres |
| `LITELLM_LOCAL_MODEL_COST_MAP` | `True` | Use the price list bundled in the image |
| `PORT` | `4000` | |

## Upgrading

Change the `LiteLLM` image tag to a newer `litellm/litellm-database` release (see [releases](https://github.com/BerriAI/litellm/releases); prefer `-stable` releases). LiteLLM migrates its database on start; back up Postgres first.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `401` on every request | Use the master key or a virtual key as `Authorization: Bearer ...` |
| Provider says the API key is invalid | The matching `*_API_KEY` variable is missing or wrong, or the model needs a provider prefix such as `anthropic/` |
| Responses are never cached | The cache is opt-in: send `"cache": {"use-cache": true}`, or set `mode: default_on` in `LITELLM_CONFIG` |
| Stored provider keys fail after a change | `LITELLM_SALT_KEY` was changed. Restore the old value |
| UI login fails | Use `UI_USERNAME` and `UI_PASSWORD` from the `LiteLLM` service variables |

## License

LiteLLM is licensed under the [MIT License](https://github.com/BerriAI/litellm/blob/main/LICENSE), except the `enterprise/` folder, whose features need a LiteLLM Enterprise license. You are responsible for the keys you issue and the provider costs they create.

## Testing

Tested on 2026-11-23 with LiteLLM v1.110.1, deployed from the template draft into a throwaway Railway project: all three services healthy, the database migrated on first start, and Postgres and Redis had no public domain or TCP proxy.

Anonymous and wrong-key requests to the chat, models, key, model and cache endpoints were refused. The admin UI login refused a wrong password and accepted the generated `UI_PASSWORD`. The cache health check reported a healthy Redis cache. The master key created a virtual key, which could not create keys itself. A model added through the API was stored in Postgres and answered requests made with the virtual key. A second identical request that opted in to caching was served from Redis (same response, cache key header), while a request without the opt-in was not. A key with `rpm_limit` 1 got `429` on its second request, and spend was recorded on the key. Idle memory was about 0.75 GB for LiteLLM, 0.11 GB for Postgres and 15 MB for Redis.

After redeploying Postgres, Redis and LiteLLM, the virtual key, the stored model and the UI password still worked and the Redis cache was healthy again.

Not tested: real provider calls, Enterprise features, several replicas.
