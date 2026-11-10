# Deploy and Host Evolution API on Railway

Evolution API is an open-source REST API for WhatsApp. You connect a number by scanning a QR code, like WhatsApp Web, with no Meta Business approval, then send and receive messages, media and group events over HTTP and webhooks. It integrates with n8n, Typebot, Chatwoot, Dify and OpenAI.

## About Hosting Evolution API

Evolution API is a Node.js service that keeps WhatsApp sessions open and exposes them as a REST API with a web manager. It stores instances, sessions, messages and contacts in PostgreSQL and uses Redis as a cache. It needs a public HTTPS URL for its manager and webhook links, and a global API key that protects every endpoint.

This template runs the latest stable Evolution API release with PostgreSQL and Redis on Railway's private network. The API key is generated, WhatsApp sessions are stored in PostgreSQL so they survive redeploys, and messages, contacts and chats are saved so you can read them back from the API. The Typebot, Chatwoot, n8n, Flowise, Dify and OpenAI integrations are switched on, so you can connect a bot or inbox to an instance from the manager.

## Common Use Cases

- WhatsApp chatbots and AI agents with n8n, Typebot, Dify or OpenAI
- Customer support on WhatsApp through Chatwoot
- Order confirmations, reminders and alerts from your own apps
- Receiving WhatsApp messages in your backend through webhooks
- Running several WhatsApp numbers from one API

## Dependencies for Evolution API Hosting

- PostgreSQL 18
- Redis 8

### Deployment Dependencies

- Evolution API: https://github.com/evolution-foundation/evolution-api
- Documentation: https://doc.evolution-api.com
- Image: https://hub.docker.com/r/evoapicloud/evolution-api

### Implementation Details

**What you set:** nothing. The API key is generated.

**After deploy:**

1. Copy `AUTHENTICATION_API_KEY` from the Evolution API service variables.
2. Open `https://<your-domain>/manager` and log in with your domain and the API key.
3. Create an instance (Baileys), then scan its QR code in WhatsApp under Settings → Linked devices.
4. Send messages with the API, using the `apikey` header:

```bash
curl -X POST "https://<your-domain>/message/sendText/<instance>" \
  -H "apikey: <AUTHENTICATION_API_KEY>" -H "content-type: application/json" \
  -d '{"number":"<phone with country code>","text":"Hello from Railway"}'
```

**This template:**

- Pins Evolution API 2.3.7, the latest stable release (the image's `latest` tag is a 2.4.0 release candidate), PostgreSQL 18 and Redis 8.10
- Generates a 64-character global API key; every endpoint except the welcome page requires it
- Stores WhatsApp sessions in PostgreSQL, not Redis, so a restart doesn't log your numbers out
- Saves messages, message updates, contacts, chats, labels and history (`DATABASE_SAVE_*`), so the find endpoints and the manager's chat view have data
- Sets `SERVER_URL` to your Railway domain for webhook and media links
- Keeps PostgreSQL and Redis private, with volumes for both and for `/evolution/instances`
- Turns telemetry off and sets the time zone to UTC
- Checks health on `/` and restarts on failure

**Notes:** the first deploy migrates the database and takes about a minute. If you add a custom domain, set `SERVER_URL` to it. WhatsApp may ban numbers that send bulk or unsolicited messages. Evolution API is not affiliated with WhatsApp or Meta.

## Why Deploy Evolution API on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Evolution API on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
