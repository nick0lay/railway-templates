# Deploy and Host Langfuse v4 on Railway

Langfuse is the open-source LLM engineering platform: tracing and observability for LLM apps and agents, prompt management, evaluations (LLM-as-a-judge, datasets, experiments) and cost and latency analytics. Version 4 ingests traces over OpenTelemetry and stores them in ClickHouse for fast queries at scale.

## About Hosting Langfuse v4

Langfuse v4 needs six components: the web app (UI and API), a background worker, PostgreSQL for users, projects and keys, ClickHouse for traces, Redis for job queues, and S3-compatible storage for raw events and media. This template deploys all of them, wired together over Railway's private network, with persistent volumes and a Railway Bucket for storage.

It starts ready to use. On first boot it creates your admin account, an organization, a project and its API keys, so you can log in and send your first trace without the onboarding flow. Public sign-up is closed by default, so nobody else can register on your instance. Versions are pinned and tested together, and Redis is configured the way Langfuse's queues require.

## Common Use Cases

- Trace LLM calls, agents and RAG pipelines (OpenAI, Anthropic, LangChain, LlamaIndex, Vercel AI SDK, any OpenTelemetry source) and debug them step by step
- Manage and version prompts outside your code, and compare prompt versions with datasets and experiments
- Track token usage, cost and latency per user, session, model or feature
- Run LLM-as-a-judge evaluations and collect user feedback scores
- Keep all trace data in your own infrastructure for privacy and compliance

## Dependencies for Langfuse v4 Hosting

- PostgreSQL 18 (Railway Postgres with SSL)
- ClickHouse 26.8 LTS
- Redis 8 (with `noeviction`, as required by Langfuse's queues)
- Railway Bucket (S3-compatible storage)

### Deployment Dependencies

- Langfuse: https://github.com/langfuse/langfuse
- Self-hosting docs: https://langfuse.com/self-hosting
- SDKs (Python ≥ 4.7, JS/TS ≥ 5.4 for v4): https://langfuse.com/docs/observability/sdk/overview

### Implementation Details

**What you set:** only `LANGFUSE_INIT_USER_EMAIL`, your admin login.

**After deploy:**

1. Open the `langfuse-web` public URL and log in with your email and the password in the `LANGFUSE_INIT_USER_PASSWORD` variable.
2. Copy `LANGFUSE_INIT_PROJECT_PUBLIC_KEY` and `LANGFUSE_INIT_PROJECT_SECRET_KEY` into your app:

```bash
LANGFUSE_HOST=https://<your-langfuse-domain>
LANGFUSE_PUBLIC_KEY=pk-lf-...
LANGFUSE_SECRET_KEY=sk-lf-...
```

**Compared with a minimal setup, this template:**

- Creates the admin user, organization, project and API keys on first boot
- Closes public sign-up (`AUTH_DISABLE_SIGNUP=true`); invite teammates from the UI
- Pins Langfuse web and worker to the same tested version, and ClickHouse to an LTS release
- Runs Redis with `maxmemory-policy noeviction` and AOF persistence, so queued events are never evicted
- Uses a lean ClickHouse configuration with the high-volume internal log tables turned off, which saves disk and memory
- Stores events, media and exports in a Railway Bucket instead of a separate MinIO container
- Has optional SMTP variables for invite and password-reset emails

**Connect Claude Code or Cursor:** Langfuse v4 includes an MCP server at `/api/public/mcp`. Use Basic auth with `base64(public_key:secret_key)`:

```bash
claude mcp add --transport http langfuse https://<your-langfuse-domain>/api/public/mcp \
    --header "Authorization: Basic <base64 token>"
```

**Notes:**

- `SALT` and `ENCRYPTION_KEY` are generated once. Don't change them after the first deploy, or existing API keys and stored secrets stop working.
- If you add a custom domain, set `NEXTAUTH_URL` on `langfuse-web` to it.
- Upgrade by changing the image tag of `langfuse-web` and `langfuse-worker` to the same version. Migrations run automatically.

## Why Deploy Langfuse v4 on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Langfuse v4 on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
