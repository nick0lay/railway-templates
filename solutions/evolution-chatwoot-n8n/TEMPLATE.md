# Deploy and Host Evolution API + Chatwoot + n8n on Railway

Evolution API + Chatwoot + n8n is a WhatsApp AI support desk. Evolution API connects a WhatsApp number by scanning a QR code, like WhatsApp Web, with no Meta Business approval. An n8n workflow, such as an AI agent with your docs, answers each message. Every conversation, including the bot's answers, is mirrored into Chatwoot, where your agents read along and take over.

## About Hosting Evolution API + Chatwoot + n8n

Evolution API keeps WhatsApp sessions open and exposes them as a REST API with a web manager. One instance can use two of its integrations at once: n8n gets each incoming message on a webhook and its `output` goes back to the chat, and Chatwoot gets a copy of every message in an inbox, so agent replies go back to WhatsApp. Chatwoot needs PostgreSQL with pgvector, Redis and Sidekiq. n8n runs in queue mode, with a worker and a task runner.

This template deploys all three on Railway's private network, each app with its own PostgreSQL and Redis. Logins, the Chatwoot API token and every private address are created at deploy time and filled in as variables.

## Common Use Cases

- AI agent answers WhatsApp customers; agents see every chat in Chatwoot
- Human takeover: an agent reply in Chatwoot is designed to pause the bot for that contact
- n8n hands a chat to a person: label, assign or note through the Chatwoot API
- Lead capture and order updates from n8n workflows
- Several WhatsApp numbers, each with its own inbox and workflow

## Dependencies for Evolution API + Chatwoot + n8n Hosting

- PostgreSQL 18 (Evolution API, n8n) and PostgreSQL 16 with pgvector (Chatwoot)
- Redis (one per app: Evolution cache, Chatwoot jobs, n8n queue)
- n8n worker and task runner (official images, same version as n8n)

### Deployment Dependencies

- Evolution API: https://github.com/evolution-foundation/evolution-api
- Chatwoot: https://github.com/chatwoot/chatwoot
- n8n: https://github.com/n8n-io/n8n
- Docs: https://doc.evolution-api.com, https://developers.chatwoot.com, https://docs.n8n.io

### Implementation Details

**What you set:** `ADMIN_EMAIL` (Chatwoot) and `N8N_INSTANCE_OWNER_EMAIL` (n8n), the emails you log in with.

**After deploy:**

1. Log in to Chatwoot with `ADMIN_EMAIL` / `ADMIN_PASSWORD`, and to n8n with `N8N_INSTANCE_OWNER_EMAIL` / `N8N_OWNER_PASSWORD`.
2. In n8n, build a workflow: Webhook (POST, Basic Auth, respond with the Respond to Webhook node), your logic, then Respond to Webhook with `{"output": "reply"}`. Publish it.
3. Open `https://<evolution-domain>/manager` with `AUTHENTICATION_API_KEY` and create a **Baileys** instance with a hard-to-guess name.
4. **Integrations → Chatwoot:** paste `CHATWOOT_URL`, account `1` and `CHATWOOT_TOKEN` from the Evolution API variables, and turn on Auto create. Evolution API creates the inbox.
5. **Integrations → n8n:** webhook URL = `PRIVATE_WEBHOOK_URL` of n8n plus your path, your basic auth, trigger all, **Stop bot from me** on.
6. Scan the QR code, or request a pairing code with `GET /instance/connect/<instance>?number=<phone>`.

Give a chat back to the bot with `POST /n8n/changeStatus/<instance>` and `{"remoteJid": "...", "status": "opened"}`.

**This template:**

- Pins Evolution API 2.3.7 (newer images need a license activation), Chatwoot 4.19.1 CE and n8n 2.47.3
- Creates the Chatwoot admin, its API token and the n8n owner at deploy time, and closes Chatwoot's onboarding page
- Turns on only the n8n and Chatwoot integrations in Evolution API
- Puts private URLs and keys for Evolution API, Chatwoot and n8n in variables, ready to paste
- Runs n8n in queue mode with a worker and an external task runner
- Protects every public service: Evolution API key, Chatwoot and n8n logins; workers and databases stay private

**Notes:** In Evolution API 2.3.7, Chatwoot's callback `/chatwoot/webhook/<instance>` has no API-key check, so keep instance names secret. The built-in EVOLUTION test channel's `/webhook/evolution` has no API-key check either, so production bots belong on WHATSAPP-BAILEYS instances. Send the n8n basic-auth password as `basicAuthPass`. Never change `SECRET_KEY_BASE`, `ACTIVE_RECORD_ENCRYPTION_*` or `N8N_ENCRYPTION_KEY` after the first deploy. Tested on 2026-11-10 with simulated messages: the bot answered, and its replies showed up in the Chatwoot conversation. An agent reply paused the bot in a simulated test where the contact and reply numbers matched; this is not yet confirmed with a paired phone. WhatsApp may ban numbers that send bulk or unsolicited messages. Evolution API, Chatwoot and n8n are not affiliated with WhatsApp or Meta.

## Why Deploy Evolution API + Chatwoot + n8n on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Evolution API + Chatwoot + n8n on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
