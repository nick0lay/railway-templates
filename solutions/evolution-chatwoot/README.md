# Evolution API + Chatwoot

A shared WhatsApp inbox for your team on Railway: [Evolution API](https://github.com/evolution-foundation/evolution-api) connects a WhatsApp number by scanning a QR code, with no Meta Business approval, and [Chatwoot](https://github.com/chatwoot/chatwoot) gives your agents one inbox with assignment, labels, canned replies and private notes. Incoming WhatsApp messages become Chatwoot conversations, and agent replies go back to the chat. The Chatwoot admin account and its API token are created at deploy time, so linking a number to Chatwoot is one API call or one form, with the values already filled in as variables.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/evolution-api-23-chatwoot-419?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
   WhatsApp customers        Agents (browser)             Your apps
        │                      │ HTTPS, login               │ apikey header
        ▼                      ▼                            ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ Railway project                                                          │
│                                                                          │
│  Evolution API :8080 (public, API key) ── REST API, private network ──┐  │
│   WhatsApp sessions, manager /manager     (CHATWOOT_URL, token)       │  │
│      │      │      ▲                                                  ▼  │
│      │      │      └─ agent replies: POST /chatwoot/webhook/<instance>   │
│      │      │         (public URL)            Chatwoot :3000 (public, login)
│      │      │                                 Rails + Sidekiq, /app/storage
│      │      └─ history import, de-duplication ──┐    │          │       │
│      ▼      ▼     (CHATWOOT_IMPORT_DATABASE_...) ▼    ▼          ▼       │
│  Evolution  Evolution                     Chatwoot Postgres  Chatwoot Redis
│  Postgres   Redis                         :5432, pgvector    :6379       │
│  (private)  (private)                     (private)          (private)   │
└──────────────────────────────────────────────────────────────────────────┘
        │
        ▼
 WhatsApp servers (outbound)
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Evolution API | `evoapicloud/evolution-api:v2.3.7` | WhatsApp REST API and manager UI (public, API key). Pushes messages into Chatwoot |
| Evolution Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Instances, WhatsApp sessions, messages, contacts (private) |
| Evolution Redis | `redis:8.10` | Evolution API cache (private) |
| Chatwoot | `chatwoot/chatwoot:v4.19.1-ce` | Agent inbox: Rails web and Sidekiq in one service, attachments on a volume (public, login) |
| Chatwoot Postgres | `pgvector/pgvector:0.8.7-pg16` | Chatwoot data; Chatwoot needs the pgvector extension (private) |
| Chatwoot Redis | `redis:8.2.11-alpine` | Sidekiq jobs, Action Cable, cache (private) |

## What this template does differently

- **Chatwoot admin and API token at deploy time.** The start script creates the admin account from `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD`, closes the public onboarding page (so nobody else can claim the instance), and sets the admin's API access token to the generated `ADMIN_ACCESS_TOKEN` on every start.
- **Values ready to copy.** `Evolution API` has `CHATWOOT_URL` (Chatwoot's private address), `CHATWOOT_ACCOUNT_ID` (`1`) and `CHATWOOT_TOKEN` (a reference to `ADMIN_ACCESS_TOKEN`). Paste them into the instance's Chatwoot settings; Evolution API creates the inbox itself.
- **Chatwoot integration on in Evolution API.** `CHATWOOT_ENABLED=true`, plus `CHATWOOT_IMPORT_DATABASE_CONNECTION_URI` pointing at Chatwoot's Postgres, which Evolution API uses to import contacts and message history and to avoid duplicate messages. No other integration is turned on.
- **Separate databases.** Each app has its own Postgres and Redis. Chatwoot's Postgres has pgvector; Evolution API's is Railway's Postgres 18.
- **Auth on every public service.** Evolution API needs the generated global API key, Chatwoot an agent login. Databases have no public domain or TCP proxy.
- **Pinned, tested versions:** Evolution API 2.3.7 (newer images need a license activation), Chatwoot 4.19.1 CE.

## After deploy

**1. Sign in to Chatwoot**

Open the `Chatwoot` URL and sign in with `ADMIN_EMAIL` and the `ADMIN_PASSWORD` variable of the `Chatwoot` service. Invite your agents under **Settings → Agents** (without SMTP settings, invitation emails aren't sent; see Variables).

**2. Create a WhatsApp instance linked to Chatwoot (one call)**

Copy `AUTHENTICATION_API_KEY`, `CHATWOOT_URL`, `CHATWOOT_TOKEN` from the `Evolution API` variables, then:

```bash
URL=https://<evolution-domain>
KEY=<AUTHENTICATION_API_KEY>

curl -X POST "$URL/instance/create" -H "apikey: $KEY" -H "content-type: application/json" -d '{
  "instanceName": "sales-x7k2q9",
  "integration": "WHATSAPP-BAILEYS",
  "qrcode": true,
  "chatwootAccountId": "1",
  "chatwootToken": "<CHATWOOT_TOKEN>",
  "chatwootUrl": "<CHATWOOT_URL>",
  "chatwootSignMsg": true,
  "chatwootReopenConversation": true,
  "chatwootConversationPending": false,
  "chatwootImportContacts": true,
  "chatwootImportMessages": true,
  "chatwootDaysLimitImportMessages": 7,
  "chatwootAutoCreate": true
}'
```

Evolution API creates a Chatwoot inbox named after the instance, with its webhook pointing back to Evolution API. Pick an instance name that is hard to guess (see Security).

**3. Pair the number**

Either scan the QR code: open `https://<evolution-domain>/manager` (server URL `https://<evolution-domain>`, API key), open the instance and scan it with WhatsApp under **Settings → Linked devices → Link a device**. Or use a pairing code instead of the QR:

```bash
curl "$URL/instance/connect/sales-x7k2q9?number=5511999999999" -H "apikey: $KEY"
```

The response has a `pairingCode`; enter it in WhatsApp under **Linked devices → Link with phone number instead**. With `chatwootAutoCreate`, Evolution API also opens an "EvolutionAPI" bot conversation in the inbox, where it posts the QR code and status messages.

**Already have an instance?** Link it with one call:

```bash
curl -X POST "$URL/chatwoot/set/sales-x7k2q9" -H "apikey: $KEY" -H "content-type: application/json" \
  -d '{"enabled":true,"accountId":"1","token":"<CHATWOOT_TOKEN>","url":"<CHATWOOT_URL>","signMsg":true,
       "reopenConversation":true,"conversationPending":false,"importContacts":true,"importMessages":true,
       "daysLimitImportMessages":7,"autoCreate":true}'
```

Or in the manager: open the instance, **Integrations → Chatwoot**, turn it on, paste the Chatwoot URL, account id `1` and the token, turn on **Auto create**, and save.

Options: `signMsg` adds the agent's name to each reply, `reopenConversation` reuses the contact's last conversation instead of opening a new one, `conversationPending` puts new conversations in "Pending", `mergeBrazilContacts` merges Brazilian numbers with and without the 9th digit, `ignoreJids` (for example `["@g.us"]`) skips groups.

**4. Use it**

Messages to your number appear in the inbox. Agents reply in Chatwoot and the customer gets the reply on WhatsApp. Typing `/status`, `/init` or `/clearcache` in the bot conversation controls the instance.

API reference: https://doc.evolution-api.com and https://developers.chatwoot.com

## Security

- In Evolution API 2.3.7, `/chatwoot/webhook/<instance>` (the URL Chatwoot calls with agent replies) has no API-key check. Anyone who knows an instance name can post to it and make that number send messages. Use long, random-looking instance names and don't publish them.
- The built-in `EVOLUTION` test channel accepts messages on `/webhook/evolution` without the API key, so anyone who knows such an instance's number can inject messages. Use `WHATSAPP-BAILEYS` instances for real numbers and production bots.
- `ADMIN_ACCESS_TOKEN` gives full access to the Chatwoot account. Rotate it by changing the variable (Chatwoot restarts and applies it), then run `/chatwoot/set` again for each instance, because Evolution API stores the token per instance.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Chatwoot | `ADMIN_EMAIL` | `admin@example.com` | Admin login. Change it to your own before deploying |
| Chatwoot | `ADMIN_NAME`, `ACCOUNT_NAME` | `Admin`, `My Company` | Used on the first start |
| Chatwoot | `DEFAULT_LOCALE` | `en` | Dashboard and widget language |
| Chatwoot | `FRONTEND_URL` | public domain | Change it with a custom domain |
| Chatwoot | `ACTIVE_STORAGE_SERVICE` | `local` | Attachments on the volume; S3 needs Chatwoot's storage variables |
| Evolution API | `AUTHENTICATION_API_KEY` | generated | Global API key and manager login |
| Evolution API | `DATABASE_SAVE_DATA_*` | `true` | Store messages, contacts, chats, labels and history |
| Evolution API | `LANGUAGE`, `TZ`, `LOG_LEVEL` | `en`, `UTC`, `ERROR,WARN,INFO,LOG,WEBHOOKS` | |

To send emails (agent invitations, password resets), add Chatwoot's `SMTP_*` and `MAILER_SENDER_EMAIL` variables to `Chatwoot`.

### Generated

| Service | Variable | Notes |
|---|---|---|
| Chatwoot | `ADMIN_PASSWORD` | Admin password, used only on the first start; change it later in Chatwoot |
| Chatwoot | `ADMIN_ACCESS_TOKEN` | Admin API token, applied on every start. A token reset on the Chatwoot profile page is undone on restart; change it here |
| Chatwoot | `SECRET_KEY_BASE`, `ACTIVE_RECORD_ENCRYPTION_*` | **Never change after the first deploy** |
| Evolution API | `AUTHENTICATION_API_KEY` | 64 hex characters, sent as the `apikey` header |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Evolution API | `CHATWOOT_ENABLED` | `true` | Turns on `/chatwoot/*` and the manager's Chatwoot page |
| Evolution API | `CHATWOOT_IMPORT_DATABASE_CONNECTION_URI` | `${{Chatwoot Postgres.DATABASE_URL}}?sslmode=disable` | Contact and history import, duplicate checks. `sslmode=disable` because Evolution API asks for SSL and Chatwoot's Postgres serves none |
| Evolution API | `CHATWOOT_URL`, `CHATWOOT_ACCOUNT_ID`, `CHATWOOT_TOKEN` | `http://${{Chatwoot.RAILWAY_PRIVATE_DOMAIN}}:${{Chatwoot.PORT}}`, `1`, `${{Chatwoot.ADMIN_ACCESS_TOKEN}}` | For you to copy; Evolution API itself doesn't read them |
| Evolution API | `SERVER_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Chatwoot calls `SERVER_URL/chatwoot/webhook/<instance>` |
| Evolution API | `DATABASE_CONNECTION_URI`, `CACHE_REDIS_URI` | `${{Evolution Postgres.DATABASE_URL}}`, `${{Evolution Redis.REDIS_URL}}` | Private network |
| Chatwoot | `POSTGRES_*`, `REDIS_URL` | `${{Chatwoot Postgres.*}}`, `${{Chatwoot Redis.*}}` | Private network |
| Chatwoot | `CHATWOOT_RUN_SH` | start script | Prepares the database, creates the admin, sets the API token, closes onboarding, runs Sidekiq and Rails |

## Custom domains

- Evolution API: add the domain and set `SERVER_URL=https://your-domain`. Inboxes created before keep the old webhook URL; update it in Chatwoot under **Settings → Inboxes → (inbox) → Configuration**, or run `/chatwoot/set` again with `autoCreate` off and edit the webhook.
- Chatwoot: add the domain and set `FRONTEND_URL=https://your-domain`. Evolution API keeps using the private URL.

## Upgrading

- Evolution API: change the image tag. It migrates its database on start. Avoid `latest`, `homolog` and `-rc` tags; check the license notes of new releases first.
- Chatwoot: change the tag to a newer `-ce` release; the start script runs the migrations.

Back up both Postgres services first.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `401 Unauthorized` from Evolution API | The `apikey` header is missing or wrong |
| `Chatwoot is disabled` | `CHATWOOT_ENABLED` was changed on `Evolution API` |
| No inbox appears in Chatwoot | `autoCreate` was off, or the token / URL is wrong. Check the Evolution API logs; use `CHATWOOT_URL` and `CHATWOOT_TOKEN` exactly as given |
| Messages arrive but agent replies don't reach WhatsApp | The inbox webhook must be `https://<evolution-domain>/chatwoot/webhook/<instance>`; check it after changing `SERVER_URL` |
| Chatwoot API returns 401 with the token | The token was reset in Chatwoot's profile page; restart `Chatwoot` to re-apply `ADMIN_ACCESS_TOKEN` |
| Can't sign in to Chatwoot | Use `ADMIN_EMAIL` and `ADMIN_PASSWORD`; the password is only used on the first start, so a changed password stays changed |
| Duplicate contacts for Brazilian numbers | Set `mergeBrazilContacts: true` |
| The QR code expires | Call `/instance/connect/<name>` again, or type `/init` in the bot conversation |

WhatsApp may ban numbers that send bulk or unsolicited messages. Evolution API and Chatwoot are not affiliated with WhatsApp or Meta.

## License

- Evolution API: Apache License 2.0 with extra [conditions](https://github.com/EvolutionAPI/evolution-api/blob/main/LICENSE): keep the logo and copyright in the manager, and a product built on it must say so where administrators can see it.
- Chatwoot: [MIT](https://github.com/chatwoot/chatwoot/blob/develop/LICENSE) for the Community Edition used here.

## Testing

Tested on 2026-11-10 with a test deploy of the template draft: all six services healthy. Evolution API refused instance and Chatwoot endpoints without a key and with a wrong key (401). Chatwoot's onboarding page was closed, its API refused anonymous requests, a wrong token and a wrong password, and accepted `ADMIN_PASSWORD` and the generated `ADMIN_ACCESS_TOKEN` (administrator of account 1) right after deploy. An instance on Evolution API's built-in EVOLUTION test channel was linked with one `/chatwoot/set` call using `CHATWOOT_URL`, `CHATWOOT_ACCOUNT_ID` and `CHATWOOT_TOKEN` with `autoCreate`; Evolution API created the inbox over the private network with the webhook back to itself. A simulated incoming message became a Chatwoot conversation with the WhatsApp message id, and an agent reply posted in Chatwoot reached Evolution API and was stored as an outgoing message. Evolution API logged no errors from Chatwoot's database connection, which it uses for each message. After redeploying Chatwoot, Evolution API and both Postgres, the admin, the token, the inbox, the instance and its Chatwoot settings were kept, and a second message and reply went through.

Not tested: no QR code was scanned and no pairing code entered, so real WhatsApp messages, media, the QR posted into the bot conversation, and the contact and history import (it runs on a real phone's history sync) were not exercised. Agent invitations by email (no SMTP) and custom domains were not tested.
