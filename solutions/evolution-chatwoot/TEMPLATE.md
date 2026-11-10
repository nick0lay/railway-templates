# Deploy and Host Evolution API + Chatwoot on Railway

Evolution API + Chatwoot gives your team a shared WhatsApp inbox. Chatwoot is an open-source customer support platform with conversation assignment, labels, canned replies and private notes; Evolution API connects a WhatsApp number by scanning a QR code, like WhatsApp Web, with no Meta Business approval. WhatsApp messages become Chatwoot conversations, and agent replies go back to the customer.

## About Hosting Evolution API + Chatwoot

Evolution API is a Node.js service that keeps WhatsApp sessions open and exposes them as a REST API with a web manager. Its Chatwoot integration creates an API inbox in Chatwoot, pushes every incoming message into it, and receives agent replies through the inbox webhook. Chatwoot is a Rails app with Sidekiq workers, PostgreSQL with pgvector, and Redis.

This template deploys both on Railway's private network, each with its own PostgreSQL and Redis. The Chatwoot admin account and its API token are created at deploy time, and the Chatwoot URL, account id and token are already filled in as variables on Evolution API, so linking a number is one API call or one form.

## Common Use Cases

- A support or sales team answering one WhatsApp number from a shared inbox
- Assigning WhatsApp chats to agents and teams, with labels and private notes
- Importing existing WhatsApp contacts and recent history into Chatwoot
- Several WhatsApp numbers, each in its own Chatwoot inbox
- Handling WhatsApp next to website live chat and email in one dashboard

## Dependencies for Evolution API + Chatwoot Hosting

- PostgreSQL (two: Railway Postgres 18 for Evolution API, pgvector Postgres 16 for Chatwoot)
- Redis 8 (two: Evolution API cache, Chatwoot Sidekiq and cache)

### Deployment Dependencies

- Evolution API: https://github.com/evolution-foundation/evolution-api
- Evolution API docs: https://doc.evolution-api.com
- Chatwoot: https://github.com/chatwoot/chatwoot
- Chatwoot docs: https://www.chatwoot.com/docs

### Implementation Details

**What you set:** `ADMIN_EMAIL` on the Chatwoot service, the email you sign in with.

**After deploy:**

1. Open the `Chatwoot` URL and sign in with `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD` (variables of the Chatwoot service).
2. Copy `AUTHENTICATION_API_KEY`, `CHATWOOT_URL`, `CHATWOOT_ACCOUNT_ID` and `CHATWOOT_TOKEN` from the Evolution API service variables.
3. Create an instance linked to Chatwoot in one call:

```
POST https://<evolution-domain>/instance/create   (header apikey: <AUTHENTICATION_API_KEY>)
{"instanceName":"sales-x7k2q9","integration":"WHATSAPP-BAILEYS","qrcode":true,
 "chatwootAccountId":"1","chatwootToken":"<CHATWOOT_TOKEN>","chatwootUrl":"<CHATWOOT_URL>",
 "chatwootSignMsg":true,"chatwootReopenConversation":true,"chatwootConversationPending":false,
 "chatwootAutoCreate":true}
```

   Or open `https://<evolution-domain>/manager`, create an instance, and fill **Integrations → Chatwoot** with the same values and **Auto create** on. An existing instance is linked with `POST /chatwoot/set/<instance>`.
4. Pair the number: scan the QR code in the manager (WhatsApp → Settings → Linked devices), or call `GET /instance/connect/<instance>?number=<your number>` and enter the pairing code in WhatsApp.
5. Evolution API creates the inbox in Chatwoot. Message your number from another phone and reply from Chatwoot.

**This template:**

- Pins Evolution API 2.3.7 (newer images need a license activation) and Chatwoot 4.19.1 CE
- Creates the Chatwoot admin and closes the public onboarding page at deploy time, so nobody else can claim a fresh instance
- Sets the admin's Chatwoot API token from a generated variable and exposes it, with Chatwoot's private URL and account id, on Evolution API
- Turns on only the Chatwoot integration in Evolution API, with Chatwoot's database connected for contact and history import
- Gives each app its own PostgreSQL and Redis
- Protects every public service: generated Evolution API key and Chatwoot login; databases stay private
- Stores WhatsApp sessions in PostgreSQL so restarts don't log your number out

**Security notes:** In Evolution API 2.3.7 the Chatwoot webhook route (`/chatwoot/webhook/<instance>`) has no API-key check, so use hard-to-guess instance names. The built-in `EVOLUTION` test channel's `/webhook/evolution` has no API-key check either, so production numbers belong on `WHATSAPP-BAILEYS` instances. `ADMIN_ACCESS_TOKEN` is applied on every Chatwoot start; rotate it there, then run `/chatwoot/set` again for each instance.

**Notes:** Add Chatwoot's `SMTP_*` variables to send agent invitations and password resets. Don't change `SECRET_KEY_BASE` or the `ACTIVE_RECORD_ENCRYPTION_*` keys after the first deploy. WhatsApp may ban numbers that send bulk or unsolicited messages. Evolution API and Chatwoot are not affiliated with WhatsApp or Meta.

## Why Deploy Evolution API + Chatwoot on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Evolution API + Chatwoot on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
