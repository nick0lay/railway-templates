# Deploy and Host Langflow on Railway

Langflow is an open-source visual builder for AI applications. You connect LLMs, prompts, vector stores, tools and agents on a canvas, test them in the playground, and run them as a REST API, an MCP server for Claude, Cursor and other clients, or an embedded chat on your site. It works with OpenAI, Anthropic, Google, Ollama and many other providers.

## About Hosting Langflow

Langflow is a Python web app that stores flows, users and credentials in a database and keeps uploaded files and caches on disk. In production it needs PostgreSQL, a persistent volume, a fixed secret key so saved credentials stay readable after restarts, and a login so strangers can't run code or spend your API credits.

This template deploys Langflow with PostgreSQL over Railway's private network, a volume for files, a generated secret key and admin password, and a pinned, tested version.

## Common Use Cases

- AI agents that use tools, APIs and your own data
- RAG chatbots over documents, with vector stores such as Astra DB, Qdrant, Pinecone or pgvector
- Multi-agent workflows and automations called from your app via API
- Exposing flows as MCP tools for Claude, Cursor and other AI clients
- Prototyping and testing prompts and models side by side

## Dependencies for Langflow Hosting

- PostgreSQL 18
- Persistent volume for uploaded files and cache

### Deployment Dependencies

- Langflow: https://github.com/langflow-ai/langflow
- Documentation: https://docs.langflow.org
- Image: https://hub.docker.com/r/langflowai/langflow

### Implementation Details

**What you set:** nothing. All secrets are generated.

**After deploy:**

1. Open the Langflow URL and log in as `admin` with the generated `LANGFLOW_SUPERUSER_PASSWORD`.
2. Add your provider keys under Settings → Global Variables.
3. Start from a template, then call your flow:

```bash
curl -X POST "https://<langflow-domain>/api/v1/run/<flow-id>" \
  -H "x-api-key: $LANGFLOW_API_KEY" -H "Content-Type: application/json" \
  -d '{"input_value": "Hello", "input_type": "chat", "output_type": "chat"}'
```

**This template:**

- Requires a login (auto-login off) with a generated admin password, and turns off public sign-up
- Lets only admins create custom components, which run Python on the server
- Generates a persistent `LANGFLOW_SECRET_KEY`, so saved credentials survive restarts
- Keeps flows in PostgreSQL on a volume, and uploaded files on a second volume
- Connects to PostgreSQL over the private network
- Pins Langflow 1.13.1 and PostgreSQL 18, logs at `info` level, and turns off telemetry
- Has optional Langfuse tracing: set `LANGFUSE_BASE_URL`, `LANGFUSE_PUBLIC_KEY` and `LANGFUSE_SECRET_KEY`

**Notes:** don't change `LANGFLOW_SECRET_KEY` after the first deploy. Upgrade by changing the image tag; Langflow migrates the database on start. Langflow needs about 1–2 GB of RAM.

## Why Deploy Langflow on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Langflow on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
