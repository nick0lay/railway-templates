# Deploy and Host Evolution API + Typebot + Chatwoot on Railway

Evolution API + Typebot + Chatwoot is WhatsApp support where a bot answers first and a person takes over. Evolution API connects a WhatsApp number by scanning a QR code, with no Meta Business approval. Typebot runs your no-code flow, and Chatwoot is the team inbox where agents see every message, including the bot's answers. When an agent replies, the bot pauses for that contact.

## About Hosting Evolution API + Typebot + Chatwoot

Evolution API is a Node.js service that keeps WhatsApp sessions open and exposes them as a REST API with a web manager. On one instance it runs both integrations: incoming messages start or continue a Typebot flow through the Typebot viewer, every message and every bot answer is pushed into a Chatwoot inbox, and agent replies come back through the inbox webhook. Typebot is a builder and a viewer (Next.js) with Postgres, Redis and a bucket; Chatwoot is Rails with Sidekiq, pgvector Postgres and Redis.

This template deploys all three on Railway's private network, each app with its own PostgreSQL and Redis (12 services and a bucket). The Chatwoot admin and its API token are created at deploy time, and the Typebot viewer URL and Chatwoot URL, account id and token are filled in as variables on Evolution API.

## Common Use Cases

- A WhatsApp bot that answers FAQs and collects details, with a human taking over in a shared inbox
- Order status or booking flows built in Typebot, escalated to agents in Chatwoot
- Lead qualification on WhatsApp before a sales agent replies
- Agents seeing the full bot conversation before they answer

## Dependencies for Evolution API + Typebot + Chatwoot Hosting

- PostgreSQL (three: Evolution API, Typebot, and pgvector Postgres for Chatwoot)
- Redis (three: one per app)
- A Railway Bucket for media used in Typebot flows

### Deployment Dependencies

- Evolution API: https://github.com/evolution-foundation/evolution-api (docs https://doc.evolution-api.com)
- Typebot: https://github.com/baptisteArno/typebot.io (docs https://docs.typebot.io)
- Chatwoot: https://github.com/chatwoot/chatwoot (docs https://www.chatwoot.com/docs)

### Implementation Details

**What you set:** `ADMIN_EMAIL` on `Chatwoot` and on `typebot-builder` (your logins).

**After deploy:**

1. Sign in to Chatwoot with `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD`. Sign in to `typebot-builder` with its `ADMIN_EMAIL`; the code arrives in the `mailpit` page (user `admin`, `MAILPIT_PASSWORD`).
2. Build and publish a flow in Typebot and copy its public ID.
3. From the `Evolution API` variables copy `AUTHENTICATION_API_KEY`, `CHATWOOT_URL`, `CHATWOOT_TOKEN` and `TYPEBOT_URL`, and create an instance linked to Chatwoot:

```
POST https://<evolution-domain>/instance/create   (header apikey: <AUTHENTICATION_API_KEY>)
{"instanceName":"support-x7k2q9","integration":"WHATSAPP-BAILEYS","qrcode":true,
 "chatwootAccountId":"1","chatwootToken":"<CHATWOOT_TOKEN>","chatwootUrl":"<CHATWOOT_URL>",
 "chatwootSignMsg":true,"chatwootReopenConversation":true,"chatwootAutoCreate":true}
```

4. Pair the number: scan the QR code in `https://<evolution-domain>/manager`, or call `GET /instance/connect/<instance>?number=<your number>` and enter the pairing code in WhatsApp (Linked devices).
5. Attach the flow:

```
POST https://<evolution-domain>/typebot/create/support-x7k2q9
{"enabled":true,"url":"<TYPEBOT_URL>","typebot":"<public id>","triggerType":"keyword",
 "triggerOperator":"equals","triggerValue":"hi","expire":1440,"keywordFinish":"#stop",
 "delayMessage":1000,"listeningFromMe":false,"stopBotFromMe":true,"keepOpen":false,"debounceTime":3}
```

   Or use the manager's **Integrations → Chatwoot** (Auto create on) and **Integrations → Typebot** (Stop bot from me on).

**Bot and human:** bot answers appear in the Chatwoot conversation. An agent reply pauses the contact's bot session (`stopBotFromMe`). The bot resumes after `POST /typebot/changeStatus/<instance>` with `status` `opened`, or `expire` minutes after the last agent reply (`0` = never). Resolving a conversation in Chatwoot does not resume it.

**This template:**

- Pins Evolution API 2.3.7 (newer images need a license activation), Typebot 3.19 and Chatwoot 4.19.1 CE
- Turns on only the Typebot (`latest` chat API) and Chatwoot integrations in Evolution API
- Creates the Chatwoot admin and API token at deploy time and closes the public onboarding page
- Limits Typebot sign-up to `ADMIN_EMAIL`, with sign-in codes caught by password-protected Mailpit
- Gives each app its own PostgreSQL and Redis; all databases are private
- Stores WhatsApp sessions in PostgreSQL so restarts don't log your number out

**Security notes:** Evolution API 2.3.7's `/chatwoot/webhook/<instance>` has no API-key check, so use hard-to-guess instance names. The built-in `EVOLUTION` test channel's `/webhook/evolution` has no API-key check either, so production bots belong on `WHATSAPP-BAILEYS` instances. The Typebot viewer and `files` are public by design (they serve published bots).

**Notes:** Don't change `SECRET_KEY_BASE`, `ACTIVE_RECORD_ENCRYPTION_*` or Typebot's `ENCRYPTION_SECRET` after the first deploy. WhatsApp may ban numbers that send bulk or unsolicited messages. Evolution API, Typebot and Chatwoot are not affiliated with WhatsApp or Meta.

## Why Deploy Evolution API + Typebot + Chatwoot on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Evolution API + Typebot + Chatwoot on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
