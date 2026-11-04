# Deploy and Host Flowise on Railway

Flowise is an open-source visual builder for AI agents, chatbots and RAG pipelines. You connect LLMs, prompts, vector stores, tools and agents on a canvas, test them in the chat panel, and run them as a REST API or an embeddable chat widget. It works with OpenAI, Anthropic, Google, Ollama and many other providers.

## About Hosting Flowise

Flowise is a Node.js app that stores flows, the owner account and encrypted credentials in a database and keeps uploaded files on disk. In production it needs PostgreSQL, a persistent volume, fixed secrets so credentials stay readable and logins survive restarts, and an owner account that only you can use. Flowise 3 creates that account on the first visit, so a fresh public instance can be claimed by whoever opens it first.

This template creates the owner account at deploy with your email and a generated password, and runs Flowise with PostgreSQL over Railway's private network, a volume for files, generated secrets and a pinned, tested version.

## Common Use Cases

- AI agents that use tools, APIs and your own data
- RAG chatbots over documents, with vector stores such as Pinecone, Qdrant or pgvector
- Customer support and lead-capture chat widgets embedded on your site
- Multi-agent workflows called from your app via API
- Prototyping prompts and models side by side

## Dependencies for Flowise Hosting

- PostgreSQL 18
- Persistent volume for uploaded files and logs

### Deployment Dependencies

- Flowise: https://github.com/FlowiseAI/Flowise
- Documentation: https://docs.flowiseai.com
- Image: https://hub.docker.com/r/flowiseai/flowise

### Implementation Details

**What you set:** `ADMIN_EMAIL`, the email you log in with. Everything else is generated.

**After deploy:**

1. Open the Flowise URL and log in with `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD`.
2. Add your provider keys under Credentials.
3. Build a flow, create an API key and assign it to the flow, then call it:

```bash
curl -X POST "https://<flowise-domain>/api/v1/prediction/<flow-id>" \
  -H "Authorization: Bearer $FLOWISE_API_KEY" -H "Content-Type: application/json" \
  -d '{"question": "Hello"}'
```

**This template:**

- Creates the owner account on first start, so nobody else can claim your instance
- Generates the credential encryption key and the login and session secrets, so credentials and logins survive restarts
- Keeps flows in PostgreSQL on a volume, and uploaded files on a second volume
- Connects to PostgreSQL over the private network
- Pins Flowise 3.1.4 and PostgreSQL 18, logs at `info` level, and turns off telemetry
- Checks health on `/api/v1/ping`

**Notes:** a flow without an assigned API key answers anyone who knows its ID; assign a key to every flow you don't want public. Don't change `FLOWISE_SECRETKEY_OVERWRITE` after the first deploy. Upgrade by changing the image tag; Flowise migrates the database on start.

## Why Deploy Flowise on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Flowise on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
