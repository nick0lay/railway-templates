# Deploy and Host Evolution API + Dify on Railway

Evolution API + Dify gives you WhatsApp AI agents and RAG chatbots. Dify is an open-source platform for LLM apps: chatflows, agents, knowledge bases and 100+ model providers in a visual editor. Evolution API connects a WhatsApp number by scanning a QR code, like WhatsApp Web, with no Meta Business approval. Each message to your number goes to a Dify app, and Dify's answer goes back to the chat.

## About Hosting Evolution API + Dify

Evolution API is a Node.js service that keeps WhatsApp sessions open and exposes them as a REST API with a web manager. Its Dify integration sends every incoming message to a Dify app's chat API, keeps one Dify conversation per WhatsApp chat, and sends the answer back. Self-hosted Dify is several services: the API, a Celery worker and scheduler, the web console, a code sandbox, a plugin daemon for model providers and tools, an outbound proxy, PostgreSQL, Redis, a vector store and file storage.

This template deploys the whole stack on Railway's private network. Evolution API calls Dify's API over a private address that is already filled in as a variable.

## Common Use Cases

- WhatsApp customer support agents that answer from your documents (RAG)
- Lead qualification and booking assistants with tools and HTTP calls
- Internal assistants on WhatsApp for your team's knowledge base
- Human handover: the bot pauses when you answer from the phone
- Several WhatsApp numbers, each routed to its own Dify app

## Dependencies for Evolution API + Dify Hosting

- PostgreSQL 18 (two: Evolution API and Dify) and pgvector (Dify knowledge bases)
- Redis 8 (two: Evolution API cache, Dify cache and queue)
- A Railway Bucket for Dify files
- An LLM provider API key (OpenAI, Anthropic, Gemini, OpenRouter, ...), added in Dify after deploy

### Deployment Dependencies

- Evolution API: https://github.com/evolution-foundation/evolution-api
- Evolution API docs: https://doc.evolution-api.com
- Dify: https://github.com/langgenius/dify
- Dify docs: https://docs.dify.ai

### Implementation Details

**What you set:** `ADMIN_EMAIL` on the `Dify` service, the email you log in to Dify with.

**After deploy:**

1. Open the `Dify` URL and log in with `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD` (variables of the `Dify` service).
2. In **Settings → Model Provider**, install a model provider and paste its API key.
3. Build a Chatflow, Chatbot or Agent, publish it, and create an API key under **API Access** (`app-...`).
4. Open `https://<evolution-domain>/manager` and log in with the `AUTHENTICATION_API_KEY` of the Evolution API service. Create an instance and scan its QR code in WhatsApp (Settings → Linked devices), or request a pairing code with `/instance/connect/<name>?number=<phone>`.
5. In the instance's Dify integration, add a bot. Type: Chatbot (or Agent). API URL: the `DIFY_PRIVATE_API_URL` variable of the `Dify` service. API key: your `app-...` key. Trigger: all messages or a keyword.
6. Message your number from another phone.

**This template:**

- Pins Evolution API 2.3.7 (newer images need a license activation), Dify 1.19.0, PostgreSQL 18, pgvector 0.8.7 and Redis 8.10
- Creates the Dify admin account at deploy time and guards `/install` with a generated init password, so nobody else can claim a fresh instance
- Uses pgvector and a Railway Bucket instead of Weaviate and MinIO (MinIO is archived upstream)
- Serves the Dify console and APIs from one public gateway, so login cookies work
- Generates every internal key that upstream ships with a fixed default
- Turns on only the Dify integration in Evolution API
- Lets Dify HTTP nodes call Evolution API over the private network; other private addresses stay blocked by the SSRF proxy
- Protects every public service: Evolution API key and Dify admin login. Workers, sandbox, plugin daemon and databases stay private

**Notes:** Use botType Chatbot, Agent or Text Generator. Evolution API 2.3.7 never calls Dify for Workflow apps. Evolution API sends `remoteJid`, `pushName`, `instanceName`, `serverUrl` and `apiKey` as inputs; in a chatflow, declare them with a max length of 256. The `EVOLUTION` test channel accepts `/webhook/evolution` without a key, so keep production bots on `WHATSAPP-BAILEYS` instances. Dify's license forbids multi-tenant SaaS without a commercial license. WhatsApp may ban numbers that send bulk or unsolicited messages. Evolution API and Dify are not affiliated with WhatsApp or Meta.

## Why Deploy Evolution API + Dify on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Evolution API + Dify on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
