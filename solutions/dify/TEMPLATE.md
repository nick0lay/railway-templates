# Deploy and Host Dify on Railway

Dify is an open-source platform for building LLM apps: chatflows, agents, workflows and knowledge bases (RAG) in a visual editor, with 100+ model providers and a plugin marketplace. Every app you publish gets a web app and a REST API.

## About Hosting Dify

Self-hosted Dify is several services: the API, a Celery worker and a scheduler, the web console, a code sandbox for Code nodes, a plugin daemon for model providers and tools, an outbound SSRF proxy, PostgreSQL, Redis, a vector store and file storage. The console needs the UI and the API on one origin for its login cookies.

This template deploys the whole stack on Railway's private network, behind one public gateway. The admin account is created at deploy time, so nobody else can claim a fresh instance.

## Common Use Cases

- Customer support chatbots that answer from your documents (RAG)
- AI agents with tools, HTTP calls and Python code
- Workflow automation with LLM steps, exposed as a REST API
- Internal assistants for your team's knowledge base
- Prototyping LLM apps across OpenAI, Anthropic, Gemini, Ollama and other providers

## Dependencies for Dify Hosting

- PostgreSQL 18 (Dify data) and pgvector (knowledge bases)
- Redis 8 (cache, sessions, Celery queue)
- A Railway Bucket for files
- An LLM provider API key (OpenAI, Anthropic, Gemini, OpenRouter, ...), added in Dify after deploy

### Deployment Dependencies

- Dify: https://github.com/langgenius/dify
- Dify docs: https://docs.dify.ai

### Implementation Details

**What you set:** `ADMIN_EMAIL` on the `Dify` service, the email you log in with.

**After deploy:**

1. Open the `Dify` URL and log in with `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD` (variables of the `Dify` service). Change the password in Dify under Account.
2. In **Settings, Model Provider**, install a model provider and paste its API key.
3. Build a Workflow, Chatflow, Chatbot or Agent and publish it.
4. Create an API key under **API Access** (`app-...`) and call `https://your-dify-domain/v1/chat-messages` or `/v1/workflows/run` with `Authorization: Bearer app-YOUR_KEY`.

**This template:**

- Pins Dify 1.20.0 with the sandbox (0.2.15) and plugin daemon (0.6.15) versions upstream pins, PostgreSQL 18, pgvector 0.8.7 and Redis 8.12
- Creates the admin account at deploy time and guards `/install` with a generated init password
- Includes the full upstream stack: API, worker, scheduler (beat), web, sandbox, plugin daemon with a volume, and the SSRF proxy that keeps HTTP nodes away from private addresses
- Uses pgvector and a Railway Bucket instead of Weaviate and MinIO (MinIO is archived upstream)
- Serves the console and APIs from one public gateway, so login cookies work
- Generates every internal key that upstream ships with a fixed default
- Keeps workers, sandbox, plugin daemon, databases and Redis private; only the gateway is public, behind the Dify login
- Turns off Dify's anonymous telemetry

**Resources:** eleven services, about 3 GB of RAM in total when idle.

**Notes:** The Agent V2 backend and the collaboration websocket (new in Dify 1.19) are not included; classic agents, chatflows, workflows and knowledge bases work without them. Dify's license is based on Apache 2.0 with conditions: no multi-tenant SaaS without a commercial license, and the Dify logo stays in the console. You are responsible for complying with it.

## Why Deploy Dify on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Dify on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
