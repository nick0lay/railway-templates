# Evolution API + Dify

WhatsApp AI agents and RAG chatbots on Railway. [Evolution API](https://github.com/evolution-foundation/evolution-api) connects a WhatsApp number when you scan a QR code; no Meta Business approval is needed. [Dify](https://github.com/langgenius/dify) builds the bot: chatflows, agents, knowledge bases (RAG) and 100+ model providers in a visual editor. Each incoming WhatsApp message goes to a Dify app over Railway's private network, and Dify's answer goes back to the chat.

Both apps are pinned to stable releases, and the Dify integration is already turned on in Evolution API. The Dify admin account is created at deploy time, and every public page needs a key or a login.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/evolution-api-23-dify-119?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
   WhatsApp users          You (browser)                     Your apps
        │                    │ HTTPS                          │ apikey / Bearer app key
        ▼                    ▼                                ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│ Railway project                                                               │
│                                                                               │
│  Evolution API :8080 (public, API key)    Dify :8080 gateway (public, admin login)
│   sessions, manager /manager                │ /console/api /api /v1 /files ...│
│      │      │     │ POST /v1/chat-messages  │            │ /        │ /e/    │
│      │      │     └────(private)─────► dify-api :5001 ◄──┘   dify-web  plugin-daemon
│      ▼      ▼                            │  │  │  │          :3000     :5002   │
│  Evolution Evolution          Dify Postgres │  │  └─► dify-sandbox :8194      │
│  Postgres  Redis              Dify Vector ◄─┘  │      (Code nodes)            │
│                               (pgvector)       ▼            │                 │
│                               Dify Redis ◄── dify-worker, dify-beat           │
│                               Bucket (files) ◄──┘           │                 │
│  ▲ HTTP Request nodes                                        ▼                │
│  └──────────────────────────────── dify-ssrf-proxy :3128 ──► internet         │
└───────────────────────────────────────────────────────────────────────────────┘
```

Only `Evolution API` and the `Dify` gateway are public. Every other service, all three databases, Redis and the Bucket stay private.

## Services

| Service | Source | Role |
|---------|--------|------|
| Evolution API | `evoapicloud/evolution-api:v2.3.7` | WhatsApp REST API and manager UI (public, API key). Calls the Dify app for each chat |
| Evolution Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Instances, WhatsApp sessions, messages, bot sessions |
| Evolution Redis | `redis:8.10` | Evolution API cache |
| Dify | `nginx:1.30.6-alpine` | Gateway: one public origin for the console, the APIs and plugin hooks (public, admin login) |
| dify-api | `langgenius/dify-api:1.19.0` | Console and service API, runs migrations, creates the admin account |
| dify-worker | `langgenius/dify-api:1.19.0` | Celery worker: document indexing, workflow storage, mail |
| dify-beat | `langgenius/dify-api:1.19.0` | Celery beat: scheduled tasks |
| dify-web | `langgenius/dify-web:1.19.0` | Console UI and published web apps |
| dify-sandbox | `langgenius/dify-sandbox:0.2.15` | Runs Python and JavaScript Code nodes |
| dify-plugin-daemon | `langgenius/dify-plugin-daemon:0.6.14-local` | Runs model provider and tool plugins (volume for installed plugins) |
| dify-ssrf-proxy | `ubuntu/squid:6.6-24.04_beta` | Outbound proxy for HTTP nodes and Code nodes; blocks private addresses except Evolution API |
| Dify Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Dify data (`railway` database) and plugin data (`dify_plugin`) |
| Dify Vector | `pgvector/pgvector:0.8.7-pg16` | Vector store for knowledge bases |
| Dify Redis | `redis:8.10` | Cache, sessions and the Celery queue |
| Bucket | Railway Bucket | Uploaded files, knowledge base documents, workspace keys |

## What this template does differently

- **The Dify admin exists before anyone can open the page.** Fresh Dify lets the first visitor create the admin at `/install`. Here a start-up script on `dify-api` creates the admin from `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD` (variables of the `Dify` service) as soon as the API is up. `/install` is also guarded by a generated `INIT_PASSWORD`, so nobody can claim the instance even before the script runs.
- **No Weaviate, no MinIO.** Knowledge bases use pgvector in its own Postgres, and files go to a Railway Bucket. The MinIO repository was archived upstream, and its Docker Hub images are gone.
- **One public origin.** Dify's console uses `__Host-` cookies, and two separate `*.up.railway.app` domains can't share them. The nginx gateway serves the UI, the APIs and plugin endpoints from one domain, following upstream's routes.
- **Dify integration on in Evolution API.** `DIFY_ENABLED=true`, nothing else.
- **Private wiring, ready to copy.** The `Dify` service has `DIFY_PRIVATE_API_URL` (`http://dify-api.railway.internal:5001/v1`), the API URL Evolution API calls. The SSRF proxy allows Evolution API's private address, so Dify HTTP Request nodes can call Evolution back without leaving Railway.
- **No default secrets.** Upstream compose ships fixed keys for the plugin daemon, the sandbox and the inner API. Here every one is generated per deploy.
- **Pinned, tested versions:** Evolution API 2.3.7 (newer images need a license activation), Dify 1.19.0 with the sandbox and plugin daemon versions its compose file pins.

Not included: the Agent V2 backend and its local sandbox (new in Dify 1.19 and off here: `NEXT_PUBLIC_ENABLE_AGENT_V2=false`), the collaboration websocket and the plugin remote-debugging port. Classic Agent apps, chatflows, workflows and knowledge bases work without them.

## After deploy

**1. Log in to Dify**

Open the `Dify` URL and log in with `ADMIN_EMAIL` and `ADMIN_PASSWORD` from the `Dify` service variables. The script runs once: later edits to these variables do nothing. Change the password in Dify (avatar → Account).

**2. Add a model**

Go to **Settings → Model Provider** and install a provider (OpenAI, Anthropic, Gemini, Ollama, OpenRouter...) from the Marketplace. Paste its API key. Without a model, LLM and Agent nodes fail with `Provider ... does not exist`.

**3. Build the app**

Create a **Chatflow**, a **Chatbot** or an **Agent** and click **Publish**. Then open **API Access → API Key → Create** and copy the `app-...` key.

Evolution API sends these inputs with every message: `remoteJid`, `pushName`, `instanceName`, `serverUrl` and `apiKey` (the instance token). To use them, add them as Start-node fields in a chatflow, with a max length of at least 256. A shorter field makes Dify reject long values such as `serverUrl`.

**4. Connect WhatsApp**

1. Copy `AUTHENTICATION_API_KEY` from the `Evolution API` service variables.
2. Open `https://<evolution-domain>/manager` and enter the server URL `https://<evolution-domain>` and the key.
3. Create an instance (channel **Baileys**). Scan the QR code with WhatsApp: **Settings → Linked devices → Link a device**. To use a pairing code instead, call `GET /instance/connect/<name>?number=<phone with country code>` and type the returned code on the phone under **Link with phone number**.

**5. Attach the Dify app**

In the manager, open the instance and add a bot under **Integrations → Dify**:

- **Type:** Chatbot for chatflows and chatbots, Agent for agent apps, Text Generator for completion apps.
- **API URL:** `DIFY_PRIVATE_API_URL` of the `Dify` service. The public `https://<dify-domain>/v1` works too.
- **API key:** the `app-...` key.
- **Trigger:** all messages or a keyword.

The same calls with the API:

```bash
URL=https://<evolution-domain>
KEY=<AUTHENTICATION_API_KEY>

# Instance with QR code (base64 image in the response)
curl -X POST "$URL/instance/create" -H "apikey: $KEY" -H "content-type: application/json" \
  -d '{"instanceName":"main","integration":"WHATSAPP-BAILEYS","qrcode":true}'

# Or a pairing code for a number
curl "$URL/instance/connect/main?number=5511999999999" -H "apikey: $KEY"

# Send every incoming message to the Dify app
curl -X POST "$URL/dify/create/main" -H "apikey: $KEY" -H "content-type: application/json" \
  -d '{"enabled":true,"botType":"chatBot","apiUrl":"http://dify-api.railway.internal:5001/v1",
       "apiKey":"app-...","triggerType":"all","expire":20,"keywordFinish":"#stop","delayMessage":1000,
       "unknownMessage":"","listeningFromMe":false,"stopBotFromMe":true,"keepOpen":false,"debounceTime":5}'

# List bots
curl "$URL/dify/find/main" -H "apikey: $KEY"
```

`botType` is `chatBot`, `agent` or `textGenerator`. Evolution API 2.3.7 also accepts `workflow` but never calls Dify for it, so a Workflow app gets no messages. Wrap the workflow in a chatflow, or call it from a chatflow. Each WhatsApp chat keeps its own Dify conversation (`conversation_id` is stored in the bot session). `expire` closes a session after that many minutes without a message. `stopBotFromMe` pauses the bot when you reply from the phone, and `debounceTime` merges quick messages into one.

**6. Call Evolution API from Dify**

In an HTTP Request node, use `http://<Evolution API private domain>:8080/message/sendText/{{#start.instanceName#}}` with the header `apikey: {{#start.apiKey#}}`. The instance token arrives as the `apiKey` input. The private domain is in the `Evolution API` service's `RAILWAY_PRIVATE_DOMAIN`.

API reference: https://doc.evolution-api.com and https://docs.dify.ai

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Dify | `ADMIN_EMAIL` | `admin@example.com` | Admin login. Change it to your own before deploying |
| dify-api | `ADMIN_NAME` | `Admin` | |
| dify-worker | `CELERY_WORKER_AMOUNT` | `4` | Parallel background tasks |
| dify-sandbox | `WORKER_TIMEOUT`, `ENABLE_NETWORK` | `15`, `true` | Code node time limit, internet access through the proxy |
| dify-ssrf-proxy | `SQUID_CONFIG` | squid rules | Add `acl ... dstdomain` + `http_access allow` lines to let Dify reach more private services |
| Evolution API | `AUTHENTICATION_API_KEY` | generated | Global API key and manager login |
| Evolution API | `LANGUAGE`, `TZ`, `LOG_LEVEL` | `en`, `UTC`, `ERROR,WARN,INFO,LOG,WEBHOOKS` | |

### Generated

| Service | Variable | Notes |
|---|---|---|
| Dify | `ADMIN_PASSWORD` | Initial admin password. Used once |
| dify-api | `INIT_PASSWORD` | Guards `/install` |
| dify-api | `SECRET_KEY` | Signs sessions; worker and beat use the same key. **Never change it after the first deploy** |
| dify-plugin-daemon | `SERVER_KEY`, `DIFY_INNER_API_KEY` | Keys between dify-api and the plugin daemon |
| dify-sandbox | `API_KEY` | Key dify-api uses to run code |
| Evolution API | `AUTHENTICATION_API_KEY` | 64 hex characters, sent as the `apikey` header |

### Auto-configured (do not change)

| Service | Variable | Value |
|---|---|---|
| Evolution API | `DIFY_ENABLED` | `true`: turns on `/dify/*` and the manager's Dify page |
| Dify | `DIFY_PRIVATE_API_URL`, `DIFY_PUBLIC_API_URL` | Paste into Evolution API's Dify bot |
| Dify | `NGINX_CONFIG`, `GATEWAY_START_SH` | Gateway routes and start script |
| dify-api | `DIFY_SETUP_PY` | Script that creates the admin account once |
| dify-api, worker, beat | `CONSOLE_*`, `APP_*`, `SERVICE_API_URL`, `FILES_URL`, `TRIGGER_URL`, `ENDPOINT_URL_TEMPLATE` | Public gateway domain |
| dify-api, worker, beat | `DB_*`, `REDIS_*`, `CELERY_BROKER_URL`, `PGVECTOR_*`, `S3_*` | Dify Postgres, Dify Redis, Dify Vector, Bucket |
| dify-api, worker, beat | `DISABLE_TELEMETRY` | `true` |

## Custom domains

- Evolution API: add the domain, then set `SERVER_URL=https://your-domain`.
- Dify: add the domain on the `Dify` service. Then replace `${{Dify.RAILWAY_PUBLIC_DOMAIN}}` with your domain in the URL variables of `dify-api`, `dify-worker`, `dify-beat` and `dify-web`.

## Upgrading

- Evolution API: change the image tag; it migrates on start. Avoid `latest`, `homolog` and `-rc` tags, and read the license notes of new releases.
- Dify: change `dify-api`, `dify-worker`, `dify-beat` and `dify-web` to the same version, and the sandbox and plugin daemon to the versions in that release's `docker/docker-compose.yaml`. dify-api migrates the database on start.

Back up both Postgres services first.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `401 Unauthorized` from Evolution API | The `apikey` header is missing or wrong |
| The bot doesn't answer | Check that the app is published, the key is the app's `app-...` key, `botType` matches the app type (not `workflow`) and a model is set up. Evolution API's logs show Dify's error |
| `Provider ... does not exist` | No model provider installed; see step 2 |
| Dify returns 400 about an input | A Start-node field is shorter than Evolution's value; raise its max length to 256 |
| HTTP node can't reach a private service | The SSRF proxy blocks private addresses except Evolution API; add the host to `SQUID_CONFIG` |
| Can't log in to Dify | Use `ADMIN_EMAIL` and `ADMIN_PASSWORD` from the `Dify` variables; `dify-api` logs show `[dify-setup]`. After a password change in Dify, the variable is stale |
| Documents stay "queuing" | `dify-worker` isn't running; check its logs |
| Plugin install fails | Check `dify-plugin-daemon` logs; it needs internet access and time to install Python packages |
| The QR code expires | Call `/instance/connect/<name>` again or reopen the instance in the manager |

Use the `WHATSAPP-BAILEYS` integration (QR code or pairing code) for real numbers. In Evolution API 2.3.7, the built-in `EVOLUTION` test channel takes messages on `/webhook/evolution` without checking the API key. Anyone who knows such an instance's number could trigger its bot. Keep production bots on `WHATSAPP-BAILEYS` instances, not `EVOLUTION` ones.

WhatsApp may ban numbers that send bulk or unsolicited messages. Evolution API and Dify are not affiliated with WhatsApp or Meta.

## License

- Evolution API: Apache License 2.0 with extra [conditions](https://github.com/EvolutionAPI/evolution-api/blob/main/LICENSE). Keep the logo and copyright in the manager, and a product built on it must say so where administrators can see it.
- Dify: [Dify Open Source License](https://github.com/langgenius/dify/blob/main/LICENSE), based on Apache 2.0 with conditions. Don't run it as a multi-tenant service without a commercial license, and keep the Dify logo and copyright in the console.

## Testing

Tested on 2026-11-10 with two test deploys of the template draft: all 14 services healthy, migrations done and the admin created at first start. Evolution API refused instance and Dify endpoints without a key and with a wrong key (401). Dify reported setup finished, refused an anonymous setup and init (403), its console API without a login (401) and a wrong password, and accepted the generated admin password. The plugin daemon answered through dify-api. A text file uploaded to an economy-mode knowledge base was stored in the Bucket, indexed by the worker and found by keyword search.

A Chatflow built through Dify's API (Start with Evolution's inputs, an HTTP Request to Evolution API's private address through the SSRF proxy, a Python Code node, an Answer) was published. Its API key worked on the public `/v1` API, and a wrong or missing key got 401. A Chat app with no model returned `Provider openai does not exist.`. An Evolution API instance on the built-in EVOLUTION channel got a Dify bot (Chatbot, private API URL). A simulated incoming message created a Dify conversation for that contact, and Evolution API stored the reply `Dify got: hello dify first | python 42 | evolution open | from E2E`. That reply came from the sandbox, a private call back to Evolution API and Evolution's inputs. After redeploying dify-api, the worker, the plugin daemon, both Postgres services and Evolution API, the login, the app, the knowledge base, the instance and the bot were still there, the setup script did nothing, and a second message got its reply. The published template deployed with all services healthy.

Not tested:
- A real LLM provider, and so LLM, Agent and RAG answers.
- Embedding-based (high-quality) knowledge bases, which are the only path that uses pgvector.
- Plugin installation from the Marketplace.
- Agent bots (streaming mode).
- The SSRF proxy blocking other private hosts.
- Custom domains.
- Real WhatsApp traffic: the QR code was not scanned, and no pairing code was requested.
