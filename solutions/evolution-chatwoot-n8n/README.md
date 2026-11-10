# Evolution API + Chatwoot + n8n

A WhatsApp AI support desk on Railway. [Evolution API](https://github.com/evolution-foundation/evolution-api) connects a WhatsApp number by scanning a QR code, with no Meta Business approval. An [n8n](https://github.com/n8n-io/n8n) workflow (an AI agent, your docs, your CRM) answers each message, and every conversation, including the bot's answers, is mirrored into [Chatwoot](https://github.com/chatwoot/chatwoot), where your agents read along and take over. The Chatwoot admin and its API token and the n8n owner are created at deploy time, the n8n and Chatwoot integrations are already on in Evolution API, and every private address and key is filled in as a variable.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/evolution-api-23-chatwoot-419-n8n-247?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
   WhatsApp customers        Agents (browser)       You (browser)
        │                      │ HTTPS, login         │ HTTPS, owner login
        ▼                      ▼                      ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ Railway project                                                          │
│                                                                          │
│  Evolution API :8080 (public, API key)                                   │
│   WhatsApp sessions, manager /manager                                    │
│     │  │  │  ▲  ▲                                                        │
│     │  │  │  │  └ agent replies: POST /chatwoot/webhook/<instance>        │
│     │  │  │  │                        Chatwoot :3000 (public, login)     │
│     │  │  └──┼── mirror every message ──► Rails + Sidekiq ──► Chatwoot   │
│     │  │     │   (private, token)                             Postgres + │
│     │  │     │                                                Redis      │
│     │  └─────┼── each message: POST webhook ──► n8n :5678 (public, login)│
│     │        │   (private, basic auth)          │ queue                  │
│     │        └── {"output": "..."} reply ───────┤ n8n Redis ──► n8n-worker
│     ▼                                           │              │ Code    │
│  Evolution Postgres + Evolution Redis           n8n Postgres   n8n-runner│
│  (private)                                      (private)      (private) │
└──────────────────────────────────────────────────────────────────────────┘
        │
        ▼
 WhatsApp servers (outbound)
```

One WhatsApp instance is linked to both: Evolution API sends each incoming message to the n8n bot and mirrors it into a Chatwoot inbox. The bot's reply goes to the customer and is mirrored into the same Chatwoot conversation as an outgoing message. An agent's reply in Chatwoot goes to the customer and, with **Stop bot from me** on, pauses the bot for that contact.

## Services

| Service | Source | Role |
|---------|--------|------|
| Evolution API | `evoapicloud/evolution-api:v2.3.7` | WhatsApp REST API and manager UI (public, API key) |
| Evolution Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Instances, sessions, messages, bot sessions (private) |
| Evolution Redis | `redis:8.10` | Evolution API cache (private) |
| Chatwoot | `chatwoot/chatwoot:v4.19.1-ce` | Agent inbox: Rails web and Sidekiq in one service, attachments on a volume (public, login) |
| Chatwoot Postgres | `pgvector/pgvector:0.8.7-pg16` | Chatwoot data, with the pgvector extension Chatwoot needs (private) |
| Chatwoot Redis | `redis:8.2.11-alpine` | Sidekiq jobs, Action Cable, cache (private) |
| n8n | `n8nio/n8n:2.47.3` | Editor, REST API and webhooks; queues executions (public, owner login) |
| n8n-worker | `n8nio/n8n:2.47.3` | Runs every execution from the queue (private) |
| n8n-runner | `n8nio/runners:2.47.3` | Runs Code node JavaScript and Python for the worker (private) |
| n8n Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Workflows, credentials, executions (private) |
| n8n Redis | `redis:8.10` | Execution queue, append-only file on a volume (private) |

## What this template does differently

- **Logins exist before anyone opens a page.** The Chatwoot admin is created from `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD`, and Chatwoot's public onboarding page is closed. The n8n owner is created from `N8N_INSTANCE_OWNER_EMAIL` and the generated `N8N_OWNER_PASSWORD` before n8n listens. Nobody can claim a fresh instance.
- **Chatwoot API token known at deploy time.** `ADMIN_ACCESS_TOKEN` (generated) is applied to the admin user on every start, so linking an instance needs no visit to the Chatwoot profile page.
- **Only the two integrations it bundles.** Evolution API has `N8N_ENABLED=true` and `CHATWOOT_ENABLED=true` (plus `CHATWOOT_IMPORT_DATABASE_CONNECTION_URI` for contact and history import), nothing else.
- **Values ready to copy.** `Evolution API` has `CHATWOOT_URL`, `CHATWOOT_ACCOUNT_ID` and `CHATWOOT_TOKEN`. `n8n` has `PRIVATE_WEBHOOK_URL`, `EVOLUTION_API_URL` / `EVOLUTION_API_KEY`, and `CHATWOOT_API_URL` / `CHATWOOT_ACCOUNT_ID` / `CHATWOOT_API_TOKEN` for handoff steps (label, assign, private note) from a workflow. All addresses are private.
- **n8n in queue mode** with a worker and an external task runner, on the official images.
- **Separate databases.** Each app has its own Postgres and Redis.
- **Auth on every public service.** Evolution API needs the generated API key, Chatwoot and n8n a login. Worker, runner and databases have no public domain or TCP proxy.
- **Pinned, tested versions:** Evolution API 2.3.7 (newer images need a license activation), Chatwoot 4.19.1 CE, n8n 2.47.3.

## After deploy

Set `ADMIN_EMAIL` on `Chatwoot` and `N8N_INSTANCE_OWNER_EMAIL` on `n8n` to your own email before deploying (both default to `admin@example.com`).

**1. Log in**

- Chatwoot: `ADMIN_EMAIL` and `ADMIN_PASSWORD` (variables of `Chatwoot`). Invite agents under **Settings → Agents** (needs SMTP for the emails, see Variables).
- n8n: `N8N_INSTANCE_OWNER_EMAIL` and `N8N_OWNER_PASSWORD` (variables of `n8n`). The owner is reset from these on every start; change the password in Railway.

**2. Build the bot workflow in n8n**

1. **Webhook** trigger: method `POST`, a path such as `whatsapp`, **Authentication: Basic Auth** with a new credential, **Respond: Using 'Respond to Webhook' Node**.
2. Your logic, for example an **AI Agent** node with `{{ $json.body.chatInput }}` as the prompt and `{{ $json.body.sessionId }}` as the memory key.
3. **Respond to Webhook** with JSON `{"output": "the reply"}`. No `output` means no reply. **Publish** the workflow.

Evolution API posts `chatInput`, `sessionId`, `remoteJid`, `pushName`, `instanceName`, `serverUrl` and `apiKey` (the instance token) for each message.

To hand a chat to a human from the workflow, call Chatwoot with an **HTTP Request** node: URL `CHATWOOT_API_URL` + `/api/v1/accounts/1/conversations/<id>/labels` (or `/assignments`, or `/messages` with `"private": true` for a note), header `api_access_token` = `CHATWOOT_API_TOKEN`. Find the conversation with `/api/v1/accounts/1/contacts/search?q=<number>`. Paste the values from the `n8n` variables; n8n 2.x blocks `$env` in expressions.

**3. Create the instance, linked to Chatwoot and n8n**

Copy `AUTHENTICATION_API_KEY`, `CHATWOOT_URL` and `CHATWOOT_TOKEN` from `Evolution API`, and `PRIVATE_WEBHOOK_URL` from `n8n`:

```bash
URL=https://<evolution-domain>
KEY=<AUTHENTICATION_API_KEY>
INST=support-x7k2q9   # hard to guess, see Security

curl -X POST "$URL/instance/create" -H "apikey: $KEY" -H "content-type: application/json" -d '{
  "instanceName": "'$INST'", "integration": "WHATSAPP-BAILEYS", "qrcode": true,
  "chatwootAccountId": "1", "chatwootToken": "<CHATWOOT_TOKEN>", "chatwootUrl": "<CHATWOOT_URL>",
  "chatwootSignMsg": true, "chatwootReopenConversation": true, "chatwootConversationPending": false,
  "chatwootImportContacts": true, "chatwootImportMessages": true, "chatwootDaysLimitImportMessages": 7,
  "chatwootAutoCreate": true
}'

curl -X POST "$URL/n8n/create/$INST" -H "apikey: $KEY" -H "content-type: application/json" -d '{
  "enabled": true, "webhookUrl": "<PRIVATE_WEBHOOK_URL>whatsapp",
  "basicAuthUser": "<user>", "basicAuthPass": "<password>",
  "triggerType": "all", "expire": 0, "keywordFinish": "#stop", "delayMessage": 1000, "unknownMessage": "",
  "listeningFromMe": false, "stopBotFromMe": true, "keepOpen": false, "debounceTime": 5
}'
```

Evolution API creates a Chatwoot inbox named after the instance, with its webhook pointing back to Evolution API. Send the password as `basicAuthPass`: Evolution API 2.3.7 drops a field named `basicAuthPassword`.

In the manager instead: open `https://<evolution-domain>/manager` (server URL and API key), create the instance (channel **Baileys**), then **Integrations → Chatwoot** (URL, account `1`, token, **Auto create** on) and **Integrations → n8n** (webhook URL, basic auth, trigger, **Stop bot from me** on).

**4. Pair the number**

Scan the QR code in the manager with WhatsApp (**Settings → Linked devices → Link a device**), or use a pairing code:

```bash
curl "$URL/instance/connect/$INST?number=5511999999999" -H "apikey: $KEY"
```

Enter the returned `pairingCode` in WhatsApp under **Linked devices → Link with phone number instead**.

**5. Bot first, human when needed**

- The bot answers every message, and agents see both sides in the Chatwoot conversation.
- With **Stop bot from me** (`stopBotFromMe`) on, an agent reply sent from Chatwoot is meant to pause the bot for that contact, because Evolution API treats it as a message from you. Replies from the phone are meant to do the same. Neither was tested with a paired phone, so check it once with your real number (see Testing). If the bot keeps answering, pause it yourself (below).
- Give the chat back to the bot:

```bash
curl -X POST "$URL/n8n/changeStatus/$INST" -H "apikey: $KEY" -H "content-type: application/json" \
  -d '{"remoteJid":"5511999999999@s.whatsapp.net","status":"opened"}'
```

`"status":"paused"` pauses the bot for that contact (from an n8n HTTP Request node or by hand; we tested `opened`, not `paused`), `"status":"closed"` ends the session (the next message starts a new one), `"delete"` removes it. In the 2.3.7 source, a paused session stays paused until you change it; `expire` doesn't reopen it (not tested). The customer can end the bot session with `keywordFinish`.

API reference: https://doc.evolution-api.com, https://developers.chatwoot.com, https://docs.n8n.io

## Security

- In Evolution API 2.3.7, `/chatwoot/webhook/<instance>` (the URL Chatwoot calls with agent replies) has no API-key check. Anyone who knows an instance name can make that number send messages. Use long, random instance names and don't publish them.
- The built-in `EVOLUTION` test channel accepts messages on `/webhook/evolution` without the API key, so anyone who knows such an instance's number can inject messages and trigger its bot. Use `WHATSAPP-BAILEYS` instances for real numbers and production bots.
- `ADMIN_ACCESS_TOKEN` gives full access to the Chatwoot account. To rotate it, change the variable (Chatwoot applies it on restart), then link each instance again, because Evolution API stores the token per instance.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Chatwoot | `ADMIN_EMAIL` | `admin@example.com` | Chatwoot admin login |
| Chatwoot | `ADMIN_NAME`, `ACCOUNT_NAME`, `DEFAULT_LOCALE` | `Admin`, `My Company`, `en` | Used on the first start |
| n8n | `N8N_INSTANCE_OWNER_EMAIL` | `admin@example.com` | n8n owner login |
| n8n | `N8N_INSTANCE_OWNER_MANAGED_BY_ENV` | `true` | `false` stops resetting the owner on start |
| n8n | `GENERIC_TIMEZONE` | not set (UTC) | Timezone of Schedule triggers |
| Evolution API | `DATABASE_SAVE_DATA_*`, `LANGUAGE`, `TZ`, `LOG_LEVEL` | `true`, `en`, `UTC`, ... | |

To send Chatwoot emails (invitations, password resets), add Chatwoot's `SMTP_*` and `MAILER_SENDER_EMAIL` variables to `Chatwoot`.

### Generated

| Service | Variable | Notes |
|---|---|---|
| Evolution API | `AUTHENTICATION_API_KEY` | Global API key (`apikey` header) and manager login |
| Chatwoot | `ADMIN_PASSWORD` | Used on the first start only; change it later in Chatwoot |
| Chatwoot | `ADMIN_ACCESS_TOKEN` | Admin API token, applied on every start. Change it here, not on the profile page |
| Chatwoot | `SECRET_KEY_BASE`, `ACTIVE_RECORD_ENCRYPTION_*` | **Never change after the first deploy** |
| n8n | `N8N_OWNER_PASSWORD` | Owner password; change it here |
| n8n | `N8N_ENCRYPTION_KEY` | Encrypts stored credentials, shared with the worker. **Never change after the first deploy** |

### Auto-configured (do not change)

| Service | Variable | Why |
|---|---|---|
| Evolution API | `N8N_ENABLED`, `CHATWOOT_ENABLED` | Turn on `/n8n/*`, `/chatwoot/*` and the manager pages |
| Evolution API | `CHATWOOT_IMPORT_DATABASE_CONNECTION_URI` | Chatwoot's Postgres (`sslmode=disable`), for import and duplicate checks |
| Evolution API | `CHATWOOT_URL`, `CHATWOOT_ACCOUNT_ID`, `CHATWOOT_TOKEN` | For you to copy; Evolution API doesn't read them |
| Evolution API | `SERVER_URL` | Chatwoot calls `SERVER_URL/chatwoot/webhook/<instance>` |
| n8n | `PRIVATE_WEBHOOK_URL`, `EVOLUTION_API_URL`, `EVOLUTION_API_KEY`, `CHATWOOT_API_URL`, `CHATWOOT_ACCOUNT_ID`, `CHATWOOT_API_TOKEN` | For you to copy into Evolution API and n8n nodes |
| n8n, n8n-worker | `EXECUTIONS_MODE=queue`, `DB_POSTGRESDB_*`, `QUEUE_BULL_REDIS_*` | Queue mode on the private network |
| Chatwoot | `CHATWOOT_RUN_SH` | Prepares the database, creates the admin, sets the token, closes onboarding |
| n8n | `N8N_RUN_SH` | Hashes `N8N_OWNER_PASSWORD` and starts n8n |

## Custom domains

- Evolution API: set `SERVER_URL=https://your-domain`. Existing inboxes keep the old webhook URL; edit it in Chatwoot under **Settings → Inboxes → (inbox) → Configuration**.
- Chatwoot: set `FRONTEND_URL=https://your-domain`.
- n8n: set `N8N_HOST`, `WEBHOOK_URL` (with trailing `/`) and `N8N_EDITOR_BASE_URL` on `n8n`. Bots on the private webhook URL keep working.

## Upgrading

- Evolution API: change the tag. Avoid `latest`, `homolog` and `-rc`; read the license notes of new releases first.
- Chatwoot: a newer `-ce` tag; the start script runs the migrations.
- n8n: change `n8n`, `n8n-worker` and `n8n-runner` to the same version.

Back up the three Postgres services first.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `401` from Evolution API | The `apikey` header is missing or wrong |
| No inbox in Chatwoot | `autoCreate` was off, or the URL / token is wrong; use `CHATWOOT_URL` and `CHATWOOT_TOKEN` as given |
| The bot doesn't answer | Workflow not published, webhook path wrong (`/webhook/...`, not `/webhook-test/...`), basic auth mismatch (`basicAuthPass`), or no `output` in the response. Check n8n's execution list |
| The bot stopped for one contact | An agent or the phone replied with `stopBotFromMe` on; reopen with `/n8n/changeStatus` |
| The bot keeps answering after an agent replied | `stopBotFromMe` is off on the n8n bot, or the session's contact id differs from the number Chatwoot replies to (seen on the test channel). Pause the session with `/n8n/changeStatus` and `"status":"paused"` |
| Agent replies don't reach WhatsApp | The inbox webhook must be `https://<evolution-domain>/chatwoot/webhook/<instance>` |
| Chatwoot API 401 with the token | It was reset on the profile page; restart `Chatwoot` to re-apply `ADMIN_ACCESS_TOKEN` |
| Code node times out | `n8n-runner` isn't running or its tag differs from `n8n-worker` |
| The QR code expires | Call `/instance/connect/<name>` again |

WhatsApp may ban numbers that send bulk or unsolicited messages. Evolution API, Chatwoot and n8n are not affiliated with WhatsApp or Meta.

## License

- Evolution API: Apache License 2.0 with extra [conditions](https://github.com/EvolutionAPI/evolution-api/blob/main/LICENSE): keep the logo and copyright in the manager, and a product built on it must say so where administrators can see it.
- Chatwoot: [MIT](https://github.com/chatwoot/chatwoot/blob/develop/LICENSE) for the Community Edition used here.
- n8n: [Sustainable Use License](https://github.com/n8n-io/n8n/blob/master/LICENSE.md); self-hosting for your own business is allowed, selling n8n as a hosted service is not.

## Testing

Tested on 2026-11-10 with a test deploy of the template draft: all 11 services healthy, 90 checks passed.

- **Auth:** Evolution API refused instance, `/n8n/*` and `/chatwoot/*` endpoints without a key and with a wrong key (401). Chatwoot's onboarding page was closed; its API refused anonymous requests, a wrong token and a wrong password, and accepted `ADMIN_PASSWORD` and the seeded `ADMIN_ACCESS_TOKEN` right after deploy. n8n showed no setup screen, refused an anonymous owner setup, anonymous API calls and a wrong password, and accepted the generated owner password. Workers and databases had no public domain or TCP proxy.
- **One instance, both integrations:** an instance on Evolution API's built-in EVOLUTION test channel was linked with `/chatwoot/set` (copy values, `autoCreate`) and `/n8n/create` (private webhook URL, basic auth, `stopBotFromMe`). The workflow (Webhook with basic auth → HTTP Request to Chatwoot's private API with the seeded token → Code node → Respond to Webhook) refused calls without basic auth.
- **Bot and inbox together:** a simulated incoming message ran the n8n execution on the worker, created the Chatwoot conversation, and Evolution API stored and sent the bot's reply. The reply appeared in the same Chatwoot conversation as an outgoing message, after the customer's message, and was sent only once (Chatwoot's webhook didn't echo it back). The bot session stayed open, and a second message got a second reply.
- **Human takeover:** an agent reply posted in Chatwoot reached Evolution API's send path. When the session was keyed by the same number the reply was sent to, the bot session became `paused`, the next customer message reached Chatwoot without running the workflow, and `/n8n/changeStatus` with `opened` brought the bot back. On the test channel, a contact sent as `<number>@s.whatsapp.net` gets a session under the full JID, while Chatwoot replies go to the bare number, so that session was **not** paused. This is a test-channel artifact, as far as we can tell (Baileys normalizes numbers to JIDs), but it was not confirmed with a real number.
- **Redeploy:** after redeploying Evolution API, Chatwoot, n8n, the worker and Evolution Postgres, the n8n login, the active workflow, the Chatwoot token, the instance and both integrations were kept, and a new contact's message got through to n8n and Chatwoot with the reply mirrored.

Not tested: no QR code was scanned and no pairing code entered, so real WhatsApp messages, media, `@lid` contacts, contact and history import, and the pause on a real `WHATSAPP-BAILEYS` instance (including replies from the phone) were not exercised. AI Agent nodes, SMTP, custom domains and worker replicas were not tested.
