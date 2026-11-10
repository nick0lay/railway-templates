# Evolution API + Typebot + Chatwoot

WhatsApp support where a bot answers first and a person takes over when needed, all self-hosted on Railway. [Evolution API](https://github.com/evolution-foundation/evolution-api) connects a WhatsApp number by scanning a QR code, with no Meta Business approval. [Typebot](https://github.com/baptisteArno/typebot.io) runs your no-code flow: greeting, menu, FAQ, collecting order numbers. [Chatwoot](https://github.com/chatwoot/chatwoot) is the team inbox where agents see every message, including the bot's answers, and reply. When an agent replies, the bot pauses for that contact.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/evolution-api-23-typebot-319-chatwoot-41?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
  WhatsApp customers      Agents (browser)      You (flow editor)     Your apps
        │                   │ login               │ email code          │ apikey
        ▼                   ▼                     ▼                     ▼
┌────────────────────────────────────────────────────────────────────────────┐
│ Railway project                                                            │
│                                                                            │
│  Evolution API :8080 (public, API key) ── startChat / continueChat ──┐     │
│   WhatsApp sessions, /manager                                        ▼     │
│   │  │  │  ▲                                   typebot-viewer :3000 (public)│
│   │  │  │  └─ agent replies:                     runs published flows      │
│   │  │  │     /chatwoot/webhook/<instance>                                 │
│   │  │  └── every message + bot answers ──► Chatwoot :3000 (public, login) │
│   │  │       (private URL, API token)        Rails + Sidekiq               │
│   │  │                                        │            │               │
│   ▼  ▼                                        ▼            ▼               │
│  Evolution  Evolution                 Chatwoot Postgres  Chatwoot Redis    │
│  Postgres   Redis                     (pgvector)                           │
│                                                                            │
│  typebot-builder :3000 (public, sign-in) ─► Typebot Postgres, Typebot Redis│
│        │ SMTP ─► mailpit :8025 (public, password): sign-in codes           │
│        └ uploads ─► Bucket ◄─ files :8080 (public, read-only)              │
│                                                                            │
│  All Postgres and Redis services are private                               │
└────────────────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Evolution API | `evoapicloud/evolution-api:v2.3.7` | WhatsApp REST API and manager UI (public, API key). Calls Typebot and pushes messages into Chatwoot |
| Evolution Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Instances, WhatsApp sessions, messages, bot sessions (private) |
| Evolution Redis | `redis:8.10` | Evolution API cache (private) |
| Chatwoot | `chatwoot/chatwoot:v4.19.1-ce` | Agent inbox: Rails web and Sidekiq in one service, attachments on a volume (public, login) |
| Chatwoot Postgres | `pgvector/pgvector:0.8.7-pg16` | Chatwoot data (private) |
| Chatwoot Redis | `redis:8.2.11-alpine` | Sidekiq jobs, Action Cable, cache (private) |
| typebot-builder | `baptistearno/typebot-builder:3.19` | Flow editor, sign-in, results, API (public) |
| typebot-viewer | `baptistearno/typebot-viewer:3.19` | Runs published flows; Evolution API talks to it (public, like any published bot) |
| mailpit | `axllent/mailpit:v1.33` | Catches Typebot's sign-in emails (public, password) |
| files | `rclone/rclone:1.75.2` | Read-only server for the bucket's `public/` folder: media used in flows (public, no listing) |
| Typebot Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Flows, results, users (private) |
| Typebot Redis | `redis:8.10` | Typebot sessions and rate limits (private) |
| Bucket | Railway Bucket | Uploaded images, videos and files |

## How bot and human share a chat

Both integrations run on the same Evolution API instance:

1. A customer message goes to Chatwoot (always) and to Typebot, if it matches the bot's trigger or the contact already has an open bot session.
2. Typebot's answers are sent to WhatsApp and also added to the same Chatwoot conversation as outgoing messages, so agents see the whole chat.
3. When an agent replies in Chatwoot, the reply goes to WhatsApp and, with `stopBotFromMe: true`, the contact's Typebot session is **paused**. The bot stays quiet for that contact.
4. The bot takes over again when:
   - you call `POST /typebot/changeStatus/<instance>` with `{"remoteJid":"<number>@s.whatsapp.net","status":"opened"}` (continue the flow) or `"closed"` (end it; the next trigger starts it again), or
   - `expire` minutes pass after the last agent reply (each agent reply restarts the timer). The next customer message then starts a new bot session. Use a long `expire` (for example `1440`) for human support, or `0` to keep the bot paused until you change the status.

Resolving a conversation in Chatwoot does **not** resume the bot. To hand over from inside the flow, end the flow with a message like "An agent will answer here" and set `keepOpen: true`; the session then stays closed and the bot silent for that contact until you change its status. Keep `listeningFromMe: false`, otherwise agent replies would be fed to the bot as answers.

## After deploy

**1. Sign in**

- Chatwoot: open the `Chatwoot` URL, sign in with `ADMIN_EMAIL` and the `ADMIN_PASSWORD` variable of `Chatwoot`.
- Typebot: open the `typebot-builder` URL and enter its `ADMIN_EMAIL`. Open the `mailpit` URL, log in as `admin` with `MAILPIT_PASSWORD` (variable of `mailpit`), and use the code from "Sign in to Typebot".

**2. Build and publish a flow** in Typebot. Copy its public ID from the **Share** tab (for example `support-bot`). Evolution API fills the flow variables `remoteJid`, `pushName`, `instanceName`, `ownerJid`, `serverUrl` and `apiKey` if you declare them; `apiKey` is the global Evolution key, so never show it in a message.

**3. Create an instance linked to Chatwoot.** Copy `AUTHENTICATION_API_KEY`, `CHATWOOT_URL`, `CHATWOOT_TOKEN` and `TYPEBOT_URL` from the `Evolution API` variables.

```bash
URL=https://<evolution-domain>
KEY=<AUTHENTICATION_API_KEY>

curl -X POST "$URL/instance/create" -H "apikey: $KEY" -H "content-type: application/json" -d '{
  "instanceName": "support-x7k2q9", "integration": "WHATSAPP-BAILEYS", "qrcode": true,
  "chatwootAccountId": "1", "chatwootToken": "<CHATWOOT_TOKEN>", "chatwootUrl": "<CHATWOOT_URL>",
  "chatwootSignMsg": true, "chatwootReopenConversation": true, "chatwootConversationPending": false,
  "chatwootAutoCreate": true}'
```

Evolution API creates a Chatwoot inbox named after the instance. An existing instance is linked with `POST /chatwoot/set/<instance>` (same values, see the Evolution API docs), or in the manager under **Integrations → Chatwoot** with **Auto create** on.

**4. Pair the number.** Scan the QR code in `https://<evolution-domain>/manager` (WhatsApp → **Settings → Linked devices → Link a device**), or ask for a pairing code:

```bash
curl "$URL/instance/connect/support-x7k2q9?number=5511999999999" -H "apikey: $KEY"
```

Enter the returned `pairingCode` in WhatsApp under **Linked devices → Link with phone number instead**.

**5. Attach the flow** to the same instance:

```bash
curl -X POST "$URL/typebot/create/support-x7k2q9" -H "apikey: $KEY" -H "content-type: application/json" -d '{
  "enabled": true, "url": "<TYPEBOT_URL>", "typebot": "support-bot",
  "triggerType": "keyword", "triggerOperator": "equals", "triggerValue": "hi",
  "expire": 1440, "keywordFinish": "#stop", "delayMessage": 1000, "unknownMessage": "Sorry, I did not get that",
  "listeningFromMe": false, "stopBotFromMe": true, "keepOpen": false, "debounceTime": 3}'
```

Or in the manager: **Integrations → Typebot**, URL = `TYPEBOT_URL`, flow = the public ID, and turn on **Stop bot from me**. `triggerType: "all"` answers every new chat; with it, set `keepOpen: true` so a finished flow doesn't start again on the next message. A `debounceTime` of a few seconds also makes the customer's message appear in Chatwoot before the bot's answer.

**6. Try it.** Send `hi` to the number from another phone: the bot answers, and both messages appear in the Chatwoot inbox. Reply in Chatwoot and the bot stops for that contact.

API reference: https://doc.evolution-api.com, https://docs.typebot.io, https://developers.chatwoot.com

## Security

- Evolution API needs the generated global API key; Chatwoot an agent login (the admin and its API token are created at deploy time and the public onboarding page is closed); Typebot sign-up is limited to `ADMIN_EMAIL` and invited people; Mailpit has a password. The Typebot viewer and `files` are public by design: they serve published bots and their media.
- In Evolution API 2.3.7, `/chatwoot/webhook/<instance>` (where Chatwoot sends agent replies) has no API-key check. Use long, random-looking instance names and don't publish them.
- The built-in `EVOLUTION` test channel accepts messages on `/webhook/evolution` without the API key, so anyone who knows such an instance's number can inject messages and drive the bot. Put production bots on `WHATSAPP-BAILEYS` instances.
- `ADMIN_ACCESS_TOKEN` gives full access to the Chatwoot account. Rotate it on the `Chatwoot` service (applied on restart), then run `/chatwoot/set` again for each instance.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Chatwoot | `ADMIN_EMAIL` | `admin@example.com` | Chatwoot admin login. Change it before deploying |
| typebot-builder | `ADMIN_EMAIL` | (required) | Typebot login; comma-separate several emails |
| typebot-builder | `DISABLE_SIGNUP` | `true` | `false` lets anyone create a Typebot account |
| Chatwoot | `ADMIN_NAME`, `ACCOUNT_NAME`, `DEFAULT_LOCALE` | `Admin`, `My Company`, `en` | First start |
| Evolution API | `DATABASE_SAVE_DATA_*` | `true` | Store messages, contacts, chats |
| Evolution API | `LANGUAGE`, `TZ`, `LOG_LEVEL` | `en`, `UTC`, `ERROR,WARN,INFO,LOG,WEBHOOKS` | |

To send email (Chatwoot invitations, Typebot notifications), set Chatwoot's `SMTP_*` and `MAILER_SENDER_EMAIL`, and `SMTP_*` on `typebot-builder`.

### Generated

| Service | Variable | Notes |
|---|---|---|
| Evolution API | `AUTHENTICATION_API_KEY` | 64 hex characters, the `apikey` header and manager login |
| Chatwoot | `ADMIN_PASSWORD` | Used only on the first start |
| Chatwoot | `ADMIN_ACCESS_TOKEN` | Admin API token, applied on every start |
| Chatwoot | `SECRET_KEY_BASE`, `ACTIVE_RECORD_ENCRYPTION_*` | **Never change after the first deploy** |
| typebot-builder | `ENCRYPTION_SECRET` | **Never change after the first deploy** |
| mailpit | `MAILPIT_PASSWORD` | Mailpit page, user `admin` |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Evolution API | `TYPEBOT_ENABLED`, `CHATWOOT_ENABLED` | `true` | The only integrations turned on |
| Evolution API | `TYPEBOT_API_VERSION` | `latest` | Typebot's current `startChat` API (the code default `old` uses a deprecated endpoint) |
| Evolution API | `CHATWOOT_IMPORT_DATABASE_CONNECTION_URI` | `${{Chatwoot Postgres.DATABASE_URL}}?sslmode=disable` | Contact and history import, duplicate checks |
| Evolution API | `TYPEBOT_URL`, `CHATWOOT_URL`, `CHATWOOT_ACCOUNT_ID`, `CHATWOOT_TOKEN` | viewer URL, Chatwoot private URL, `1`, `${{Chatwoot.ADMIN_ACCESS_TOKEN}}` | For you to copy; Evolution API doesn't read them |
| Evolution API | `SERVER_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Chatwoot calls `SERVER_URL/chatwoot/webhook/<instance>` |
| Evolution API | `DATABASE_CONNECTION_URI`, `CACHE_REDIS_URI` | `${{Evolution Postgres.*}}`, `${{Evolution Redis.*}}` | Private network |
| Chatwoot | `CHATWOOT_RUN_SH` | start script | Migrations, admin, API token, closes onboarding |
| typebot-builder, typebot-viewer | `DATABASE_URL`, `REDIS_URL`, `NEXTAUTH_URL`, `NEXT_PUBLIC_VIEWER_URL`, `S3_*` | Typebot Postgres/Redis, public URLs, Bucket | |

## Custom domains

- Evolution API: set `SERVER_URL`; update each Chatwoot inbox webhook (**Settings → Inboxes → Configuration**).
- Chatwoot: set `FRONTEND_URL`. Evolution API keeps using the private URL.
- Typebot: set `NEXTAUTH_URL` and `NEXT_PUBLIC_VIEWER_URL` on `typebot-builder`; bots keep the URL they were created with, so edit them.

## Upgrading

Change image tags one app at a time and back up the Postgres services first. Evolution API: avoid `latest`, `homolog` and `-rc` tags (2.4 needs a license activation). Typebot: change `typebot-builder` and `typebot-viewer` together. Chatwoot: newer `-ce` tags; the start script migrates.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `401 Unauthorized` from Evolution API | Missing or wrong `apikey` header |
| "Typebot is disabled" / "Chatwoot is disabled" | `TYPEBOT_ENABLED` / `CHATWOOT_ENABLED` changed on `Evolution API` |
| The bot doesn't answer | Bot URL must be the **viewer** URL without trailing slash, the flow must be published, the trigger must match, and the contact's session must not be paused (`GET /typebot/fetchSessions/<botId>/<instance>`) |
| The bot never answers a contact again | Its session is paused or closed; `POST /typebot/changeStatus/<instance>` with `opened`, or `closed` to restart on the next trigger |
| The bot comes back while an agent is still helping | `expire` passed since the last agent reply; raise it or set `0` |
| The bot answers agent messages | `listeningFromMe` is on; turn it off |
| Bot answers missing in Chatwoot | Check the instance's Chatwoot settings are enabled (`GET /chatwoot/find/<instance>`) |
| No inbox in Chatwoot | `autoCreate` off, or wrong token / URL; use `CHATWOOT_URL` and `CHATWOOT_TOKEN` as given |
| Agent replies don't reach WhatsApp | The inbox webhook must be `https://<evolution-domain>/chatwoot/webhook/<instance>` |
| No Typebot sign-in email | It goes to Mailpit, not your mailbox |
| The QR code expires | Call `/instance/connect/<name>` again |

WhatsApp may ban numbers that send bulk or unsolicited messages. Evolution API, Typebot and Chatwoot are not affiliated with WhatsApp or Meta.

## License

- Evolution API: Apache License 2.0 with extra [conditions](https://github.com/EvolutionAPI/evolution-api/blob/main/LICENSE): keep the logo and copyright in the manager, and a product built on it must say so where administrators can see it.
- Typebot: [Functional Source License 1.1](https://github.com/baptisteArno/typebot.io/blob/main/LICENSE) (FSL-1.1-Apache-2.0); self-hosting for your own use is allowed, offering it as a competing hosted service is not.
- Chatwoot: [MIT](https://github.com/chatwoot/chatwoot/blob/develop/LICENSE) for the Community Edition used here.

## Testing

Tested on 2026-11-10 with a test deploy of the template draft: all twelve services healthy. Evolution API refused instance, Typebot and Chatwoot endpoints without a key and with a wrong key (401). Chatwoot's onboarding page was closed, its API refused anonymous requests, a wrong token and a wrong password, and accepted `ADMIN_PASSWORD` and the generated `ADMIN_ACCESS_TOKEN` right after deploy. Mailpit refused requests without its password; signing in to Typebot as `ADMIN_EMAIL` with the code caught by Mailpit worked, and a flow created and published through the Typebot API answered on the viewer. All six databases had no public domain or TCP proxy.

On one instance of Evolution API's built-in EVOLUTION test channel, linked to Chatwoot with one `/chatwoot/set` call (`autoCreate`, the exposed `CHATWOOT_*` values) and to the flow with `/typebot/create` (`TYPEBOT_URL`, keyword trigger, `stopBotFromMe`): a simulated incoming message started a Typebot session; the message and the bot's answer appeared in the same Chatwoot conversation, customer first; a second message continued the flow and its answer was mirrored too. An agent reply posted in Chatwoot reached Evolution API, paused the contact's bot session, the next customer message reached Chatwoot with no bot answer, and `/typebot/changeStatus` with `opened` made the bot answer again. After redeploying Evolution API, Chatwoot, the Typebot viewer and the three Postgres services, the token, the inbox, the instance's Chatwoot and Typebot settings were kept, and a new contact's message started the bot and reached Chatwoot again.

Not tested: no QR code was scanned and no pairing code entered, so real WhatsApp messages, media and history import were not exercised. The pause on agent reply was verified on the test channel with a contact addressed by bare number. With a full `<number>@s.whatsapp.net` contact the test channel sends bot answers to the bare number, Chatwoot's contact then switches to it and the agent reply did not pause the session; the `WHATSAPP-BAILEYS` channel sends to the full WhatsApp ID, so the pause should work there, but that was only checked in the source code, not with a real number (contacts that WhatsApp addresses by `@lid` were not checked either). Email sending (no SMTP) and custom domains were not tested.
