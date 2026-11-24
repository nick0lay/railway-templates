# Deploy and Host LiteLLM on Railway

LiteLLM is an open-source AI gateway: one OpenAI-compatible API in front of 100+ model providers (OpenAI, Anthropic, Gemini, OpenRouter, Bedrock, Azure, Ollama and more). Give every app or teammate its own virtual key with budgets and rate limits, track spend per key, cache responses and switch providers without changing your code.

## About Hosting LiteLLM

The LiteLLM proxy is a Python server with an admin UI. It keeps virtual keys, teams, models added in the UI and spend logs in PostgreSQL, and uses Redis for response caching and for rate limits and usage shared between replicas. In production it needs a master key, a salt key that encrypts stored provider keys, an admin UI password and a pinned version, because it migrates its database on start.

This template runs LiteLLM with PostgreSQL 18 and Redis on Railway's private network, generates every key and the admin password for you, and wires Redis into the proxy config.

## Common Use Cases

- One API key per app, customer or teammate, each with its own budget and rate limit
- Switching between OpenAI, Anthropic, Gemini and open models without code changes
- Tracking LLM spend per key, team and model
- Caching repeated prompts in Redis to save tokens
- A private gateway for coding agents, chatbots and automation tools (n8n, Open WebUI, LibreChat)

## Dependencies for LiteLLM Hosting

- PostgreSQL 18
- Redis 8
- An API key for at least one model provider

### Deployment Dependencies

- LiteLLM: https://github.com/BerriAI/litellm
- Docs: https://docs.litellm.ai/docs/simple_proxy
- Docker image: https://hub.docker.com/r/litellm/litellm-database

### Implementation Details

**What you set:** the provider keys you use: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY` or `OPENROUTER_API_KEY` (all optional; you can also add models and keys in the admin UI). `LITELLM_MASTER_KEY`, `UI_PASSWORD` and the salt key are generated.

**After deploy:**

1. Open `/ui` on the LiteLLM URL and log in with `UI_USERNAME` (`admin`) and the generated `UI_PASSWORD` (Variables tab of the LiteLLM service).
2. Create a virtual key for each app under Virtual Keys, with a budget or rate limit if you like.
3. Point your app at `https://your-litellm-domain/v1` with the virtual key. Any model name works, for example `gpt-4o-mini`, `anthropic/claude-haiku-4-5` or `gemini/gemini-2.5-flash`, as long as its provider key is set.
4. To cache a request, send `"cache": {"use-cache": true}` in the body; repeated identical requests are then answered from Redis.

**This template:**

- Requires a login on the admin UI (generated `UI_PASSWORD`) and a key on every API call
- Generates the master key and the salt key that encrypts provider keys stored in the database
- Pins LiteLLM v1.110.3 (`litellm-database` image), PostgreSQL 18 and Redis 8.12 instead of `latest`
- Stores virtual keys, teams, models and spend logs in PostgreSQL, so keys and models added in the UI survive redeploys
- Wires Redis into the proxy: opt-in response cache (10 minute TTL) and rate limits and usage shared across replicas
- Keeps PostgreSQL and Redis on volumes, private, with no public TCP proxy; Redis has a generated password
- Routes any model name to its provider (wildcard), and drops parameters a provider does not support
- Checks health on `/health/liveliness` and restarts a crashed service
- Turns off LiteLLM's anonymous telemetry

**Notes:** never change `LITELLM_SALT_KEY` after the first deploy, or stored provider keys become unreadable. Hand out virtual keys, not the master key. To cache every request, change `mode: default_off` to `default_on` in `LITELLM_CONFIG`. LiteLLM is MIT licensed outside its enterprise folder; enterprise features need a LiteLLM license. You are responsible for the provider costs your keys create.

## Why Deploy LiteLLM on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying LiteLLM on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
