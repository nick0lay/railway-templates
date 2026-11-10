# Evolution API + Flowise

AI agents on WhatsApp, built visually and deployed on Railway. [Evolution API](https://github.com/evolution-foundation/evolution-api) connects a WhatsApp number by scanning a QR code, with no Meta Business approval. [Flowise](https://github.com/FlowiseAI/Flowise) is a drag-and-drop builder for LLM agents, chatbots and RAG flows. Each incoming WhatsApp message goes to a Flowise flow, and the flow's answer is sent back to the chat. Both apps are pinned to stable releases, and the Flowise integration in Evolution API is already turned on. The Flowise owner account is created at deploy time, and every public page needs a key or a login.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/evolution-api-23-flowise-31?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
   WhatsApp users          You (browser)                  Your apps
        │                    │ HTTPS                       │ apikey header
        ▼                    ▼                             ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ Railway project                                                          │
│                                                                          │
│  Evolution API :8080 (public, API key)                                   │
│   WhatsApp sessions, manager /manager                                    │
│      │        │      │ POST /api/v1/prediction/<flow id>                 │
│      │        │      │ Bearer <Flowise API key> (private network)        │
│      │        │      ▼                                                   │
│      │        │   flowise :3000 (public, owner login; flows need a key)  │
│      │        │    editor, REST API, prediction endpoints                │
│      │        │    volume /data: uploads, logs                           │
│      ▼        ▼      │                                                   │
│  Evolution  Evolution    ▼                                               │
│  Postgres   Redis     Flowise Postgres :5432 (private)                   │
│  (private)  (private)  flows, users, API keys, credentials, chat history │
└──────────────────────────────────────────────────────────────────────────┘
        │                                  │
        ▼                                  ▼
 WhatsApp servers (outbound)      LLM providers, vector stores, tools
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Evolution API | `evoapicloud/evolution-api:v2.3.7` | WhatsApp REST API and manager UI (public, API key). Calls your Flowise flow for each chat |
| Evolution Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Instances, WhatsApp sessions, messages, contacts, bot sessions (private) |
| Evolution Redis | `redis:8.10` | Evolution API cache (private) |
| flowise | `flowiseai/flowise:3.1.4` | Visual editor, REST API and prediction endpoints (public, owner login) |
| Flowise Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Flows, users, API keys, encrypted credentials, chat history (private) |

## What this template does differently

- **The Flowise owner exists before anyone can open the page.** Flowise 3 lets the first visitor create the owner account. Here the owner is created from `ADMIN_EMAIL` and a generated `ADMIN_PASSWORD` on the first start, so the setup page is never exposed.
- **Flowise integration on in Evolution API.** `FLOWISE_ENABLED=true` and nothing else. No other integration is turned on.
- **Private wiring, ready to copy.** `flowise` has `PRIVATE_PREDICTION_URL`, the prediction base that Evolution API calls over the private network, and `EVOLUTION_API_URL`, Evolution API's private address.
- **Separate databases.** Evolution API and Flowise each have their own Postgres. Flowise runs as a single process and uses Redis only in its optional queue mode, so it gets no Redis. Evolution's Redis is its own cache.
- **Auth on every public service.** Evolution API needs the generated global API key and Flowise needs the owner login. The databases have no public domain or TCP proxy.
- **Pinned, tested versions:** Evolution API 2.3.7 (newer images need a license activation), Flowise 3.1.4, Postgres 18, Redis 8.10.

## After deploy

**What you set before deploying:** `ADMIN_EMAIL` on `flowise`, the email you log in with. It is required.

**1. Log in to Flowise**

Open the `flowise` URL and log in with `ADMIN_EMAIL` and the `ADMIN_PASSWORD` variable of the `flowise` service. Add your model provider keys under **Credentials**.

**2. Build the flow**

Build an **Agentflow** (or a Chatflow) that answers a question, for example Start → Agent with your LLM, tools and documents. Test it in the chat panel.

**3. Protect the flow with an API key**

Create a key under **API Keys**, then open the flow → **API Endpoint** (`</>`) → choose the key. **A flow without an assigned key answers anyone who knows its ID**, because Flowise serves `/api/v1/prediction/<id>` on the public domain too, and each answer spends your LLM credits.

**4. Connect WhatsApp**

1. Copy `AUTHENTICATION_API_KEY` from the `Evolution API` service variables.
2. Open `https://<evolution-domain>/manager`, enter the server URL `https://<evolution-domain>` and the API key.
3. Create an instance (channel **Baileys**) and pair your number. Either scan the QR code with WhatsApp (**Settings → Linked devices → Link a device**), or call `GET /instance/connect/<name>?number=<number with country code>` to get a pairing code and enter it under **Link with phone number instead**.

**5. Attach the flow**

In the manager, open the instance and add a bot under **Integrations → Flowise**:

- **API URL:** `PRIVATE_PREDICTION_URL` of `flowise` followed by the flow ID, for example `http://flowise.railway.internal:3000/api/v1/prediction/7c1d...`. The public `https://<flowise-domain>/api/v1/prediction/<id>` works too.
- **API Key:** the Flowise API key assigned to the flow. Evolution sends it as `Authorization: Bearer <key>`.
- **Trigger:** all messages, or a keyword.

Send a message to your number from another phone. The same steps with the API (this is the path we tested):

```bash
URL=https://<evolution-domain>
KEY=<AUTHENTICATION_API_KEY>
FLOW=<PRIVATE_PREDICTION_URL><flow id>

# Instance, then pairing code for your number (or scan the QR code in the response)
curl -X POST "$URL/instance/create" -H "apikey: $KEY" -H "content-type: application/json" \
  -d '{"instanceName":"main","integration":"WHATSAPP-BAILEYS","qrcode":true}'
curl "$URL/instance/connect/main?number=5511999999999" -H "apikey: $KEY"

# Send every incoming message to the Flowise flow
curl -X POST "$URL/flowise/create/main" -H "apikey: $KEY" -H "content-type: application/json" \
  -d "{\"enabled\":true,\"apiUrl\":\"$FLOW\",\"apiKey\":\"<Flowise API key>\",
       \"triggerType\":\"all\",\"expire\":20,\"keywordFinish\":\"#stop\",\"delayMessage\":1000,\"unknownMessage\":\"\",
       \"listeningFromMe\":false,\"stopBotFromMe\":true,\"keepOpen\":false,\"debounceTime\":5}"

# List bots
curl "$URL/flowise/find/main" -H "apikey: $KEY"
```

`expire` closes a chat's session after that many minutes without a message. `keywordFinish` lets the user end the session. `stopBotFromMe` pauses the bot when you answer from the phone yourself. `debounceTime` waits that many seconds and merges quick consecutive messages into one call.

**What Flowise receives**

Evolution API posts this body to the prediction URL and sends the `text` field of the answer to the chat:

```json
{
  "question": "the message text",
  "overrideConfig": {
    "sessionId": "5511999999999@s.whatsapp.net",
    "vars": { "messageId": "...", "fromMe": false, "remoteJid": "5511999999999@s.whatsapp.net",
              "pushName": "contact name", "instanceName": "main",
              "serverUrl": "https://<evolution-domain>", "apiKey": "<the instance token>" }
  }
}
```

- `sessionId` is the contact's WhatsApp ID, so flows with memory keep one conversation per contact, and Flowise's chat history lists conversations by phone number.
- Flowise ignores `vars` unless you allow them. Open the flow → **Configuration → Security → Override Configuration**, turn it on and enable the variables you want, such as `remoteJid`, `pushName` or `instanceName`. If a variable isn't listed, create it under **Variables** first (static, any value). After that, use them in nodes as `{{ $vars.remoteJid }}`.
- `apiKey` is the instance token, not the global key. With it, a flow tool can call Evolution API back for that instance, for example `EVOLUTION_API_URL` + `/message/sendMedia/<instanceName>` with an `apikey` header.

Image messages are passed to the flow as uploads. Audio arrives as `[audio] <transcription>` only if you set up Evolution's OpenAI integration (not part of this template).

API reference: https://doc.evolution-api.com and https://docs.flowiseai.com

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| flowise | `ADMIN_EMAIL` | (required) | Owner login, applied on the first start |
| flowise | `ADMIN_PASSWORD` | generated | Read it after deploy. Applied only when the owner is created; later, change it under Account Settings |
| flowise | `LOG_LEVEL` | `info` | `debug` for troubleshooting |
| Evolution API | `AUTHENTICATION_API_KEY` | generated | Global API key and manager login. Change it to rotate the key |
| Evolution API | `DATABASE_SAVE_DATA_*` | `true` | Store messages, contacts, chats, labels and history |
| Evolution API | `LANGUAGE`, `TZ`, `LOG_LEVEL` | `en`, `UTC`, `ERROR,WARN,INFO,LOG,WEBHOOKS` | |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Evolution API | `FLOWISE_ENABLED` | `true` | Turns on `/flowise/*` and the manager's Flowise page |
| Evolution API | `SERVER_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Webhook and media links; also sent to Flowise as `serverUrl` |
| Evolution API | `DATABASE_CONNECTION_URI`, `CACHE_REDIS_URI` | `${{Evolution Postgres.DATABASE_URL}}`, `${{Evolution Redis.REDIS_URL}}` | Private network |
| flowise | `PRIVATE_PREDICTION_URL` | `http://${{RAILWAY_PRIVATE_DOMAIN}}:${{PORT}}/api/v1/prediction/` | For you to copy into Evolution API |
| flowise | `EVOLUTION_API_URL` | `http://${{Evolution API.RAILWAY_PRIVATE_DOMAIN}}:${{Evolution API.PORT}}` | For you to copy into flow tools |
| flowise | `FLOWISE_SECRETKEY_OVERWRITE` | generated | Encrypts saved credentials. **Never change it after the first deploy** |
| flowise | `JWT_AUTH_TOKEN_SECRET`, `JWT_REFRESH_TOKEN_SECRET`, `EXPRESS_SESSION_SECRET`, `TOKEN_HASH_SECRET` | generated | Changing them logs everyone out |
| flowise | `FLOWISE_SETUP_BODY` | from `ADMIN_EMAIL`, `ADMIN_PASSWORD` | The start command uses it to create the owner on the first start |
| flowise | `DATABASE_*` | `${{Flowise Postgres.*}}` | Private network |
| flowise | `SECRETKEY_PATH`, `BLOB_STORAGE_PATH`, `LOG_PATH` | `/data`, `/data/storage`, `/data/logs` | On the volume |
| flowise | `RAILWAY_RUN_UID` | `0` | Lets Flowise write to the Railway volume |
| flowise | `APP_URL`, `PORT`, `DISABLE_FLOWISE_TELEMETRY` | public URL, `3000`, `true` | |

## Custom domains

- Evolution API: add the domain and set `SERVER_URL=https://your-domain`.
- Flowise: add the domain and set `APP_URL=https://your-domain`. Bots attached with the private prediction URL keep working.

## Upgrading

- Evolution API: change the image tag. It migrates its database on start. Avoid `latest`, `homolog` and `-rc` tags, and check the license notes of new releases first.
- Flowise: change the tag, for example `flowiseai/flowise:3.1.5`. Flowise migrates its database on start and can't go back to an older version afterwards.

Read the release notes ([Evolution API](https://github.com/evolution-foundation/evolution-api/releases), [Flowise](https://github.com/FlowiseAI/Flowise/releases)) and back up both Postgres services first.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `401 Unauthorized` from Evolution API | The `apikey` header is missing or wrong |
| `400 Flowise is disabled` | `FLOWISE_ENABLED` isn't `true` on `Evolution API` |
| The bot doesn't answer | Check that the API URL ends with the flow ID and that the API key is the one assigned to the flow. Flowise answers a wrong or missing key with `500 Unauthorized`, which shows in the Evolution API logs. The flow's chat history in Flowise shows whether the call arrived |
| `Flowise already exists` | That instance already has a bot with the same API URL and key. Edit the existing bot instead |
| `$vars.*` are empty in the flow | Allow those variables under **Configuration → Security → Override Configuration** |
| The bot answers once and then ignores the user | The session expired (`expire`) or the user sent `keywordFinish` |
| The bot stops after you answered from the phone | `stopBotFromMe` is on; that is intended for human takeover |
| Flowise shows the setup page or login fails | The owner is created on the first start only. Check the `flowise` logs for `owner-setup HTTP`: `201` means created, `400` means it already existed. Use the `ADMIN_EMAIL`/`ADMIN_PASSWORD` values from that first start |
| Saved credentials stop working | `FLOWISE_SECRETKEY_OVERWRITE` was changed. Restore the old value |
| The QR code expires | Call `/instance/connect/<name>` again or reopen the instance in the manager |

Use the `WHATSAPP-BAILEYS` integration (QR code or pairing code) for real numbers. In Evolution API 2.3.7 the built-in `EVOLUTION` test channel accepts messages on `/webhook/evolution` without the API key, so anyone who knows such an instance's number could trigger its bot and spend your LLM credits. Don't attach production bots to `EVOLUTION` instances.

WhatsApp may ban numbers that send bulk or unsolicited messages. Evolution API and Flowise are not affiliated with WhatsApp or Meta.

## License

- Evolution API: Apache License 2.0 with extra [conditions](https://github.com/EvolutionAPI/evolution-api/blob/main/LICENSE). Keep the logo and copyright in the manager, and a product built on it must say so where administrators can see it.
- Flowise: [Apache License 2.0](https://github.com/FlowiseAI/Flowise/blob/main/LICENSE.md). The enterprise directory is under a commercial license and isn't used.

## Testing

Tested on 2026-11-10 with a test deploy of the template draft:

- **Deploy and auth.** All five services came up healthy, and the Flowise owner was created at the first start (`owner-setup HTTP 201`). Evolution API refused instance and `/flowise/*` endpoints with no key or a wrong key (401). Flowise refused a stranger's sign-up, its API without a login and a wrong password, and accepted the generated owner password.
- **Flow.** We built an Agentflow through the Flowise API (Start → Direct Reply, so no LLM key was needed) and assigned it a Flowise API key. Its prediction endpoint refused calls with no key or a wrong key, and answered in `text` with the key.
- **Round trip.** An Evolution API instance on the built-in EVOLUTION channel got a Flowise bot pointing at the private prediction URL with that key. A simulated incoming message reached Flowise: the question was stored with the contact's WhatsApp ID as chat ID, and `instanceName` and `remoteJid` reached the flow once their override was enabled. Evolution API stored the bot session and the flow's reply.
- **Redeploy.** After redeploying Flowise, Evolution API and both databases, the login, the flow, its key, the instance and the bot were all still there, and a second message got its reply.

**Not tested:**
- No QR code or pairing code was used, so no real WhatsApp messages were sent or received.
- No flow with a real LLM was run.
- The manager's Flowise page and Flowise's Override Configuration screen were not used; both were set up through their APIs.
- Image and audio messages were not tried.
