# Evolution API + Typebot

WhatsApp chatbots on Railway without code: [Typebot](https://github.com/baptisteArno/typebot.io) is the visual flow builder, and [Evolution API](https://github.com/evolution-foundation/evolution-api) connects a WhatsApp number by scanning a QR code, with no Meta Business approval. Incoming WhatsApp messages start your Typebot flow and its answers go back to the chat. Both apps are pinned stable releases, the Typebot integration is already turned on in Evolution API, and every public page needs a key or a login.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/evolution-api-23-typebot-319?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
   WhatsApp users          You (browser)                     Bot API calls
        │                    │ HTTPS                          │ apikey header
        ▼                    ▼                                ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ Railway project                                                          │
│                                                                          │
│  Evolution API :8080 (public, API key)  ── startChat / continueChat ──┐  │
│   WhatsApp sessions, manager /manager                                 │  │
│      │                │                                               ▼  │
│      ▼                ▼                       typebot-viewer :3000 (public)│
│  Evolution         Evolution                   runs published flows      │
│  Postgres :5432    Redis :6379                      │                    │
│  (private)         (private)                        │                    │
│                                                     ▼                    │
│  typebot-builder :3000 (public, sign-in) ──► Typebot Postgres :5432      │
│   flow editor, results, API      │           Typebot Redis :6379         │
│                                  │           (private)                   │
│                                  ├─ SMTP ─► mailpit :8025 (public,       │
│                                  │           password) sign-in codes     │
│                                  └─ uploads ─► Bucket ◄─ files :8080     │
│                                                (public, read-only        │
│                                                 public/ folder)          │
└──────────────────────────────────────────────────────────────────────────┘
        │
        ▼
 WhatsApp servers (outbound)
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Evolution API | `evoapicloud/evolution-api:v2.3.7` | WhatsApp REST API and manager UI (public, API key). Calls the Typebot viewer for each chat |
| Evolution Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Instances, WhatsApp sessions, messages, contacts, bot sessions (private) |
| Evolution Redis | `redis:8.10` | Evolution API cache (private) |
| typebot-builder | `baptistearno/typebot-builder:3.19` | Flow editor, sign-in, results, API (public) |
| typebot-viewer | `baptistearno/typebot-viewer:3.19` | Runs published flows; Evolution API talks to it (public) |
| mailpit | `axllent/mailpit:v1.33` | Catches Typebot's sign-in emails on a password-protected page (public) |
| files | `rclone/rclone:1.76.0` | Read-only web server for the bucket's `public/` folder: images and files used in flows (public) |
| Typebot Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Flows, results, users (private) |
| Typebot Redis | `redis:8.10` | Typebot sessions and rate limits (private) |
| Bucket | Railway Bucket | Uploaded images, videos and files |

## What this template does differently

- **Typebot integration on and set to the right API.** `TYPEBOT_ENABLED=true` and `TYPEBOT_API_VERSION=latest`. Evolution API 2.3's code defaults to `old`, which uses Typebot's deprecated `/api/v1/sendMessage` endpoint; `latest` uses the current `startChat`/`continueChat` API.
- **The viewer URL is ready to paste.** Evolution API has a `TYPEBOT_URL` variable with the viewer's address, so you don't have to look it up when you attach a flow.
- **Separate databases.** Evolution API and Typebot both run Prisma migrations in the `public` schema of their database. In a shared database each app would see the other's migrations as unknown, so each gets its own Postgres and Redis.
- **Sign-in without an email provider.** Typebot signs in with an emailed code. The code goes to Mailpit; open the `mailpit` URL with its password and copy it.
- **Auth on every public service.** Evolution API needs the generated global API key, Typebot sign-up is closed to `ADMIN_EMAIL` and people you invite, and Mailpit has a generated password. Databases have no public TCP proxy.
- **WhatsApp sessions in Postgres**, so a Redis restart doesn't log your number out, and messages, contacts and chats are stored for the API and manager.
- **Pinned, tested versions:** Evolution API 2.3.7 (the image's `latest` tag is a release candidate), Typebot 3.19, Postgres 18, Redis 8.10.

## After deploy

**1. Sign in to Typebot**

1. Open the `typebot-builder` URL and enter your `ADMIN_EMAIL`.
2. Open the `mailpit` URL, log in as `admin` with the `MAILPIT_PASSWORD` variable of `mailpit`, open "Sign in to Typebot" and enter the code (or click the link).

**2. Build and publish a flow**

1. Create a typebot, add text bubbles and inputs, and click **Publish**.
2. Copy its public ID from the **Share** tab (the last part of the share link, for example `my-whatsapp-bot`).

Evolution API fills these Typebot variables when a chat starts, if your flow declares them: `remoteJid` (the contact's WhatsApp ID), `pushName` (their name), `instanceName`, `ownerJid`, `serverUrl` and `apiKey`. `apiKey` is Evolution API's global key; only declare it if the flow needs to call Evolution API back, and don't show it in a message.

**3. Connect WhatsApp**

1. Copy `AUTHENTICATION_API_KEY` from the `Evolution API` service variables.
2. Open `https://<evolution-domain>/manager`, enter the server URL `https://<evolution-domain>` and the API key.
3. Create an instance (channel **Baileys**), open it and scan the QR code with WhatsApp: **Settings → Linked devices → Link a device**.

**4. Attach the flow**

In the manager, open the instance and add a bot in its Typebot integration settings:

- **URL:** the `TYPEBOT_URL` variable of `Evolution API` (the viewer URL, without a trailing slash)
- **Typebot (flow ID):** the public ID from step 2
- **Trigger:** all messages, or a keyword (for example equals `hi`)

The API calls below are the tested path; the manager form sets the same fields.

Send the trigger to your number from another phone. The same with the API:

```bash
URL=https://<evolution-domain>
KEY=<AUTHENTICATION_API_KEY>
VIEWER=<TYPEBOT_URL>

# Instance with QR code (base64 image in the response)
curl -X POST "$URL/instance/create" -H "apikey: $KEY" -H "content-type: application/json" \
  -d '{"instanceName":"main","integration":"WHATSAPP-BAILEYS","qrcode":true}'

# Attach the published flow; it starts when someone sends "hi"
curl -X POST "$URL/typebot/create/main" -H "apikey: $KEY" -H "content-type: application/json" \
  -d "{\"enabled\":true,\"url\":\"$VIEWER\",\"typebot\":\"my-whatsapp-bot\",
       \"triggerType\":\"keyword\",\"triggerOperator\":\"equals\",\"triggerValue\":\"hi\",
       \"expire\":20,\"keywordFinish\":\"#stop\",\"delayMessage\":1000,\"unknownMessage\":\"Sorry, I didn't get that\",
       \"listeningFromMe\":false,\"stopBotFromMe\":true,\"keepOpen\":false,\"debounceTime\":10}"

# List bots and open sessions
curl "$URL/typebot/find/main" -H "apikey: $KEY"
```

`expire` closes a chat's session after that many minutes without a reply; `keywordFinish` lets the user end it; `stopBotFromMe` pauses the bot when you answer from the phone yourself. Instead of the public URL you can also use the viewer's private address, `http://typebot-viewer.railway.internal:3000`, which skips the public network.

API reference: https://doc.evolution-api.com and https://docs.typebot.io

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| typebot-builder | `ADMIN_EMAIL` | (required) | You sign in to Typebot with it. Several emails: comma-separated |
| typebot-builder | `DISABLE_SIGNUP` | `true` | `false` lets anyone with the URL create an account |
| typebot-builder | `SMTP_*`, `NEXT_PUBLIC_SMTP_FROM` | Mailpit | Set to a real provider to send invitations and notifications |
| Evolution API | `AUTHENTICATION_API_KEY` | generated | Global API key and manager login. Change it to rotate the key |
| Evolution API | `DATABASE_SAVE_DATA_*` | `true` | Store messages, contacts, chats, labels and history |
| Evolution API | `TYPEBOT_SEND_MEDIA_BASE64` | not set | `true` sends media from flows as base64 instead of a URL |
| Evolution API | `LANGUAGE`, `TZ`, `LOG_LEVEL` | `en`, `UTC`, `ERROR,WARN,INFO,LOG,WEBHOOKS` | |

### Generated

| Service | Variable | Notes |
|---|---|---|
| Evolution API | `AUTHENTICATION_API_KEY` | 64 hex characters, sent as the `apikey` header |
| typebot-builder | `ENCRYPTION_SECRET` | Encrypts credentials stored in flows. **Never change it after the first deploy** |
| mailpit | `MAILPIT_PASSWORD` | Mailpit page, user `admin` |
| typebot-builder | `SMTP_PASSWORD` | Typebot's login to Mailpit |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Evolution API | `TYPEBOT_ENABLED` | `true` | Turns on `/typebot/*` and the manager's Typebot page |
| Evolution API | `TYPEBOT_API_VERSION` | `latest` | Calls `/api/v1/typebots/{id}/startChat`, the API of Typebot 2.x and 3.x |
| Evolution API | `TYPEBOT_URL` | `https://${{typebot-viewer.RAILWAY_PUBLIC_DOMAIN}}` | For you to copy; Evolution API doesn't read it. Each bot stores its own URL |
| Evolution API | `SERVER_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Webhook and media links; also passed to flows as `serverUrl` |
| Evolution API | `DATABASE_CONNECTION_URI` | `${{Evolution Postgres.DATABASE_URL}}` | Private network |
| Evolution API | `CACHE_REDIS_URI` | `${{Evolution Redis.REDIS_URL}}` | Private network |
| Evolution API | `CACHE_REDIS_SAVE_INSTANCES` | `false` | Keeps WhatsApp sessions in Postgres |
| typebot-builder, typebot-viewer | `DATABASE_URL` | `${{Typebot Postgres.DATABASE_URL}}` | |
| typebot-builder, typebot-viewer | `REDIS_URL` | `${{Typebot Redis.REDIS_URL}}?family=0` | `family=0` lets the client use Railway's IPv6 private network |
| typebot-builder, typebot-viewer | `NEXTAUTH_URL`, `NEXT_PUBLIC_VIEWER_URL` | builder and viewer public URLs | Update them with a custom domain |
| typebot-builder, typebot-viewer, files | `S3_*`, `RCLONE_S3_*`, `S3_PUBLIC_CUSTOM_DOMAIN` | `${{Bucket.*}}`, `files` URL | Uploads go to the bucket; `files` serves the `public/` folder |

## Custom domains

- Evolution API: add the domain, set `SERVER_URL=https://your-domain`.
- Typebot: add the domains, then set `NEXTAUTH_URL` (builder) and `NEXT_PUBLIC_VIEWER_URL` (viewer) on `typebot-builder`. Bots attached in Evolution API keep the URL they were created with: edit them, or keep the Railway viewer domain as well.

## Upgrading

- Evolution API: change the image tag (for example `evoapicloud/evolution-api:v2.4.0` once it's stable). It migrates its database on start. Avoid `latest`, `homolog` and `-rc` tags.
- Typebot: change **both** `typebot-builder` and `typebot-viewer` to the same tag. The builder migrates the database on start.

Read the release notes ([Evolution API](https://github.com/evolution-foundation/evolution-api/releases), [Typebot](https://github.com/baptisteArno/typebot.io/releases)) and back up both Postgres services first.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `401 Unauthorized` from Evolution API | The `apikey` header is missing or wrong |
| "Typebot is disabled" | `TYPEBOT_ENABLED` on `Evolution API` isn't `true` |
| The bot doesn't answer | Check the bot's URL is the **viewer** URL (not the builder), without a trailing slash, the public ID matches a **published** flow, and the trigger matches the message. Evolution API logs show the call |
| Logs show requests to `/api/v1/sendMessage` | `TYPEBOT_API_VERSION` isn't `latest`; that is Typebot's deprecated API |
| The bot answers once and then ignores the user | The session expired (`expire`) or the user sent `keywordFinish`. Change them in the bot settings |
| The bot stops after you answered from the phone | `stopBotFromMe` is on; that is intended for human takeover |
| No sign-in email in Mailpit | Check `SMTP_*` on `typebot-builder` still point to Mailpit; "Too many requests" means wait a few minutes |
| The QR code expires | Call `/instance/connect/<name>` again or reopen the instance in the manager |
| Images in flows don't load | Check the `files` service is running and `S3_PUBLIC_CUSTOM_DOMAIN` points to it |

WhatsApp may ban numbers that send bulk or unsolicited messages. Evolution API and Typebot are not affiliated with WhatsApp or Meta.

## License

- Evolution API: Apache License 2.0 with extra [conditions](https://github.com/EvolutionAPI/evolution-api/blob/main/LICENSE): keep the logo and copyright in the manager, and a product built on it must say so where administrators can see it.
- Typebot: [Functional Source License 1.1](https://github.com/baptisteArno/typebot.io/blob/main/LICENSE) (FSL-1.1-Apache-2.0); self-hosting for your own use is allowed, offering it as a competing hosted service is not.

## Testing

Tested on 2026-11-10 with a test deploy of the template draft: all nine services healthy. Evolution API refused listing instances, creating an instance and the Typebot endpoints without a key and with a wrong key (401). A new instance returned a QR code, and the manager page loaded. Typebot's sign-in page and the viewer's health endpoint answered; Mailpit refused requests without its password. Signing in as `ADMIN_EMAIL` with the code caught by Mailpit worked, and a flow created and published through the Typebot API answered on the viewer. The flow was attached to the instance with `/typebot/create`, once with the public viewer URL and once with the private address, and starting it for a test contact made Evolution API open a Typebot chat session in both cases. The QR code was not scanned, so real WhatsApp messages were not sent or received.
