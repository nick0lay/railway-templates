# Deploy and Host Langfuse v4 + LiteLLM on Railway

LiteLLM is an open-source AI gateway: one OpenAI-compatible API for OpenAI, Anthropic, Gemini, Bedrock, Azure and 100+ other LLM providers, with virtual keys, budgets and spend tracking. Langfuse is the open-source LLM observability platform for tracing, prompt management and evaluations. This template connects them, so every LLM call through the gateway is traced in Langfuse.

## About Hosting Langfuse v4 + LiteLLM

The stack has eight parts: the LiteLLM proxy with its own PostgreSQL, and the full Langfuse v4 platform (web app, worker, PostgreSQL, ClickHouse, Redis and a Railway Bucket for storage). They talk over Railway's private network, and every database has a persistent volume.

LiteLLM starts with Langfuse's OpenTelemetry integration enabled and the keys of the Langfuse project created on first boot. Your apps keep using the OpenAI SDK they already have; only the base URL changes, and every request shows up in Langfuse with prompt, response, tokens, cost and latency.

## Common Use Cases

- Trace every LLM call from all your apps and agents without adding an SDK to each one
- Give each app or team its own virtual key with a budget, and see their cost and usage in both LiteLLM and Langfuse
- Switch or mix providers (OpenAI, Anthropic, Gemini, open models) behind one API, and compare their quality and latency in Langfuse
- Debug agents and RAG pipelines step by step, and run evaluations on real traffic
- Keep prompts, responses and keys in your own infrastructure

## Dependencies for Langfuse v4 + LiteLLM Hosting

- PostgreSQL 18 for LiteLLM, and a second one for Langfuse
- ClickHouse 26.8 LTS
- Redis 8 (with `noeviction`, as Langfuse's queues require)
- Railway Bucket (S3-compatible storage)

### Deployment Dependencies

- LiteLLM: https://github.com/BerriAI/litellm
- Langfuse: https://github.com/langfuse/langfuse
- LiteLLM proxy docs: https://docs.litellm.ai/docs/simple_proxy

### Implementation Details

**What you set:** only `LANGFUSE_INIT_USER_EMAIL`, your Langfuse admin login. Provider keys are optional at deploy time; you can add them in the LiteLLM UI.

**After deploy:**

1. LiteLLM UI: open `https://<litellm-domain>/ui`, log in as `admin` with the generated `UI_PASSWORD`, and add a model with your provider key.
2. Call the gateway with the generated `LITELLM_MASTER_KEY` or a virtual key:

```bash
curl https://<litellm-domain>/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-4o-mini", "messages": [{"role": "user", "content": "Hello"}]}'
```

3. Langfuse: open the `langfuse-web` URL, log in with your email and the generated `LANGFUSE_INIT_USER_PASSWORD`, and find the request under Tracing.

**This template:**

- Enables LiteLLM's `langfuse_otel` callback, which works with Langfuse v4's OpenTelemetry ingestion, and sends traces over the private network
- Gives LiteLLM its own PostgreSQL, so its schema updates can never touch Langfuse's tables
- Generates the LiteLLM master key, salt key and UI password
- Includes everything from our Langfuse v4 template: admin account and API keys created on first boot, closed sign-up, pinned versions, Redis with `noeviction`, lean ClickHouse, Railway Bucket

**Notes:** don't change `LITELLM_SALT_KEY`, `SALT` or `ENCRYPTION_KEY` after the first deploy; stored keys depend on them. Use the `litellm/litellm-database` image when upgrading LiteLLM.

## Why Deploy Langfuse v4 + LiteLLM on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Langfuse v4 + LiteLLM on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
