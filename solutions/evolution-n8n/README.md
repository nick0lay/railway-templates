# Evolution API + n8n

WhatsApp automations and AI agents on Railway: [Evolution API](https://github.com/evolution-foundation/evolution-api) connects a WhatsApp number by scanning a QR code, with no Meta Business approval, and [n8n](https://github.com/n8n-io/n8n) runs the workflows. Incoming WhatsApp messages call an n8n webhook, and whatever the workflow answers goes back to the chat. n8n runs in queue mode with a worker and an external task runner. Both apps are pinned stable releases, the n8n integration is already turned on in Evolution API, and every public page needs a key or a login.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/evolution-api-23-n8n-247?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
   WhatsApp users          You (browser)                  Your apps
        │                    │ HTTPS                       │ apikey header
        ▼                    ▼                             ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ Railway project                                                          │
│                                                                          │
│  Evolution API :8080 (public, API key) ── POST webhook, basic auth ──┐   │
│   WhatsApp sessions, manager /manager    (private network)           │   │
│      │        │          ▲                                           ▼   │
│      ▼        ▼          │ HTTP Request nodes      n8n :5678 (public, owner login)
│  Evolution  Evolution    │ (private network)        editor, webhooks, API│
│  Postgres   Redis        │                            │ enqueue          │
│  (private)  (private)    │                            ▼                  │
│                          │                       n8n Redis :6379 (private)
│                          │                            │ jobs             │
│                          └──────────── n8n-worker (private) ──► n8n Postgres
│                                         │ task broker :5679   :5432 (private)
│                                         ▼                                │
│                                   n8n-runner (private)                   │
│                                   JavaScript + Python Code nodes         │
└──────────────────────────────────────────────────────────────────────────┘
        │
        ▼
 WhatsApp servers (outbound)
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Evolution API | `evoapicloud/evolution-api:v2.3.7` | WhatsApp REST API and manager UI (public, API key). Calls your n8n webhook for each chat |
| Evolution Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Instances, WhatsApp sessions, messages, contacts, bot sessions (private) |
| Evolution Redis | `redis:8.10` | Evolution API cache (private) |
| n8n | `n8nio/n8n:2.47.3` | Editor, REST API and webhooks; puts executions on the queue (public, owner login) |
| n8n-worker | `n8nio/n8n:2.47.3` | Runs all executions from the queue, including manual ones (private) |
| n8n-runner | `n8nio/runners:2.47.3` | Runs Code node JavaScript and Python for the worker, isolated from n8n (private) |
| n8n Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Workflows, credentials, executions, binary data (private) |
| n8n Redis | `redis:8.10` | Execution queue, append-only file on a volume (private) |

## What this template does differently

- **The n8n owner exists before anyone can open the page.** n8n normally lets the first visitor create the owner account, so a fresh public instance can be claimed by someone else. Here the owner is created from `N8N_INSTANCE_OWNER_EMAIL` and the generated `N8N_OWNER_PASSWORD` when n8n starts, before it listens.
- **Queue mode with an external task runner.** The main instance only serves the editor and webhooks; `n8n-worker` runs every execution, and Code nodes run in the separate `n8n-runner` container, with the official images and identical tags. Add worker replicas when you need more throughput.
- **n8n integration on in Evolution API.** `N8N_ENABLED=true`, nothing else. No other integration is turned on.
- **Private wiring, ready to copy.** `n8n` has `PRIVATE_WEBHOOK_URL` (the webhook base Evolution API calls over the private network), `EVOLUTION_API_URL` (Evolution API's private address) and `EVOLUTION_API_KEY`.
- **Separate databases.** Evolution API and n8n each get their own Postgres and Redis. n8n's Redis holds the job queue and needs `noeviction` and persistence; Evolution's is a cache. A Redis or Postgres restart for one app doesn't touch the other.
- **No n8n volume needed.** In queue mode n8n keeps binary data in Postgres, the encryption key is a variable, and community nodes you install from the UI are reinstalled after a redeploy (`N8N_REINSTALL_MISSING_PACKAGES=true`).
- **Auth on every public service.** Evolution API needs the generated global API key, n8n needs the owner login. Worker, runner and databases have no public domain or TCP proxy.
- **Pinned, tested versions:** Evolution API 2.3.7 (newer images need a license activation), n8n 2.47.3 (the `stable` tag on the day of testing), Postgres 18, Redis 8.10.

## After deploy

**1. Log in to n8n**

Open the `n8n` URL and log in with `N8N_INSTANCE_OWNER_EMAIL` and the `N8N_OWNER_PASSWORD` variable of the `n8n` service.

The owner is reset from these two variables on every start, so change the password in Railway, not in n8n's settings. To manage the owner in n8n instead, set `N8N_INSTANCE_OWNER_MANAGED_BY_ENV=false` on `n8n` after the first start.

**2. Build the workflow**

1. Create a workflow with a **Webhook** trigger: method `POST`, a path such as `whatsapp`, **Authentication: Basic Auth** with a new credential (any user name and a long password), **Respond: Using 'Respond to Webhook' Node**.
2. Add your logic: an AI Agent, an HTTP Request, a Code node.
3. End with **Respond to Webhook**, responding with JSON that has an `output` field: `{"output": "the text to send back"}`. Evolution API sends `output` (or `answer`) to the chat. No `output` means no reply.
4. **Publish** (activate) the workflow.

Evolution API posts this body to the webhook for each message:

```json
{
  "chatInput": "the message text",
  "sessionId": "per-chat session id",
  "remoteJid": "5511999999999@s.whatsapp.net",
  "pushName": "contact name",
  "keyId": "message id",
  "fromMe": false,
  "quotedMessage": null,
  "instanceName": "main",
  "serverUrl": "https://<evolution-domain>",
  "apiKey": "<the instance token>"
}
```

`apiKey` is the token of that instance, not the global key; with it a workflow can call Evolution API back for that instance (send media, mark as read, read the contact). Audio messages arrive as `[audio] <transcription>` only if you set up Evolution's OpenAI integration.

**3. Connect WhatsApp**

1. Copy `AUTHENTICATION_API_KEY` from the `Evolution API` service variables.
2. Open `https://<evolution-domain>/manager`, enter the server URL `https://<evolution-domain>` and the API key.
3. Create an instance (channel **Baileys**), open it and scan the QR code with WhatsApp: **Settings → Linked devices → Link a device**.

**4. Attach the workflow**

In the manager, open the instance and add a bot under **Integrations → n8n**:

- **Webhook URL:** `PRIVATE_WEBHOOK_URL` of `n8n` followed by your path, for example `http://n8n.railway.internal:5678/webhook/whatsapp`. The public `https://<n8n-domain>/webhook/whatsapp` works too.
- **Basic auth user and password:** the ones from your Webhook credential.
- **Trigger:** all messages, or a keyword.

Send a message to your number from another phone. The same with the API (tested path):

```bash
URL=https://<evolution-domain>
KEY=<AUTHENTICATION_API_KEY>
HOOK=<PRIVATE_WEBHOOK_URL>whatsapp

# Instance with QR code (base64 image in the response)
curl -X POST "$URL/instance/create" -H "apikey: $KEY" -H "content-type: application/json" \
  -d '{"instanceName":"main","integration":"WHATSAPP-BAILEYS","qrcode":true}'

# Send every incoming message to the n8n workflow
curl -X POST "$URL/n8n/create/main" -H "apikey: $KEY" -H "content-type: application/json" \
  -d "{\"enabled\":true,\"webhookUrl\":\"$HOOK\",\"basicAuthUser\":\"evolution\",\"basicAuthPass\":\"<password>\",
       \"triggerType\":\"all\",\"expire\":20,\"keywordFinish\":\"#stop\",\"delayMessage\":1000,\"unknownMessage\":\"\",
       \"listeningFromMe\":false,\"stopBotFromMe\":true,\"keepOpen\":false,\"debounceTime\":5}"

# List bots
curl "$URL/n8n/find/main" -H "apikey: $KEY"
```

Use `basicAuthPass` for the password: Evolution API 2.3.7 validates a field called `basicAuthPassword` but stores and sends `basicAuthPass`, so a password sent as `basicAuthPassword` is dropped and n8n answers 401. `expire` closes a chat's session after that many minutes without a message, `keywordFinish` lets the user end it, `stopBotFromMe` pauses the bot when you answer from the phone yourself, and `debounceTime` waits that many seconds to merge quick consecutive messages into one call.

**5. Call Evolution API from n8n**

To send messages from any workflow (broadcasts, reminders, replies from other triggers), use an **HTTP Request** node with the URL `EVOLUTION_API_URL` of `n8n` plus the endpoint, for example `http://evolution-api.railway.internal:8080/message/sendText/main`, and a **Header Auth** credential: name `apikey`, value `EVOLUTION_API_KEY`. Copy both values from the `n8n` variables; n8n 2.x blocks `$env` in expressions by default.

The community node [n8n-nodes-evolution-api](https://www.npmjs.com/package/n8n-nodes-evolution-api) adds an "Evolution API" node; install it from **Settings → Community nodes** if you prefer it. It is not preinstalled: it is an unverified package, and n8n's env-managed package list would lock that settings page and remove packages you add yourself.

API reference: https://doc.evolution-api.com and https://docs.n8n.io

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| n8n | `N8N_INSTANCE_OWNER_EMAIL` | `admin@example.com` | Owner login. Change it to your own before deploying |
| n8n | `N8N_INSTANCE_OWNER_MANAGED_BY_ENV` | `true` | `false` stops resetting the owner on start; manage it in n8n |
| n8n | `N8N_INSTANCE_OWNER_FIRST_NAME`, `N8N_INSTANCE_OWNER_LAST_NAME` | `Instance`, `Owner` | |
| n8n | `GENERIC_TIMEZONE` | not set (UTC) | Timezone of Schedule triggers, for example `Europe/Berlin`; shared with worker and runner |
| n8n-runner | `N8N_RUNNERS_MAX_CONCURRENCY`, `N8N_RUNNERS_TASK_TIMEOUT` | `5`, `300` | Code node tasks at once, seconds per task |
| Evolution API | `AUTHENTICATION_API_KEY` | generated | Global API key and manager login. Change it to rotate the key |
| Evolution API | `DATABASE_SAVE_DATA_*` | `true` | Store messages, contacts, chats, labels and history |
| Evolution API | `LANGUAGE`, `TZ`, `LOG_LEVEL` | `en`, `UTC`, `ERROR,WARN,INFO,LOG,WEBHOOKS` | |

### Generated

| Service | Variable | Notes |
|---|---|---|
| Evolution API | `AUTHENTICATION_API_KEY` | 64 hex characters, sent as the `apikey` header |
| n8n | `N8N_OWNER_PASSWORD` | Owner password. Change it here to change the password |
| n8n | `N8N_ENCRYPTION_KEY` | Encrypts stored credentials; the worker uses the same key. **Never change it after the first deploy** |
| n8n-worker | `N8N_RUNNERS_AUTH_TOKEN` | Shared secret between worker and runner |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Evolution API | `N8N_ENABLED` | `true` | Turns on `/n8n/*` and the manager's n8n page |
| Evolution API | `SERVER_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Webhook and media links; also sent to n8n as `serverUrl` |
| Evolution API | `DATABASE_CONNECTION_URI`, `CACHE_REDIS_URI` | `${{Evolution Postgres.DATABASE_URL}}`, `${{Evolution Redis.REDIS_URL}}` | Private network |
| n8n | `N8N_RUN_SH` | start script | Hashes `N8N_OWNER_PASSWORD` (bcrypt) and starts n8n |
| n8n | `PRIVATE_WEBHOOK_URL` | `http://${{RAILWAY_PRIVATE_DOMAIN}}:5678/webhook/` | For you to copy into Evolution API |
| n8n | `EVOLUTION_API_URL`, `EVOLUTION_API_KEY` | `http://${{Evolution API.RAILWAY_PRIVATE_DOMAIN}}:${{Evolution API.PORT}}`, `${{Evolution API.AUTHENTICATION_API_KEY}}` | For you to copy into n8n credentials and nodes |
| n8n | `WEBHOOK_URL`, `N8N_HOST`, `N8N_EDITOR_BASE_URL` | public domain | Update them with a custom domain |
| n8n, n8n-worker | `EXECUTIONS_MODE` | `queue` | |
| n8n | `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS` | `true` | Manual runs from the editor also go to the worker, so Code nodes always use the runner |
| n8n, n8n-worker | `DB_POSTGRESDB_*` | `${{n8n Postgres.*}}` | |
| n8n, n8n-worker | `QUEUE_BULL_REDIS_*` | `${{n8n Redis.*}}` | `QUEUE_BULL_REDIS_DUALSTACK=true` for Railway's private network |
| n8n-worker | `N8N_RUNNERS_MODE`, `N8N_RUNNERS_BROKER_LISTEN_ADDRESS` | `external`, `::` | The runner connects to the worker's task broker over the private network |
| n8n-runner | `N8N_RUNNERS_TASK_BROKER_URI` | `http://${{n8n-worker.RAILWAY_PRIVATE_DOMAIN}}:5679` | |

The official runner image allows the `crypto` built-in and the `moment` package in JavaScript Code nodes, and the Python standard library is restricted. Other packages need a custom runner image.

## Custom domains

- Evolution API: add the domain, set `SERVER_URL=https://your-domain`.
- n8n: add the domain, then set `N8N_HOST=your-domain`, `WEBHOOK_URL=https://your-domain/` and `N8N_EDITOR_BASE_URL=https://your-domain` on `n8n`. The worker reads `WEBHOOK_URL` from `n8n`. Bots attached with the private webhook URL keep working.

## Scaling

Add replicas to `n8n-worker` for more parallel executions. Each worker replica has its own task broker and a runner connects to one broker, so plan one `n8n-runner` replica per worker replica if your workflows use Code nodes (replicas were not part of our test).

## Upgrading

- Evolution API: change the image tag. It migrates its database on start. Avoid `latest`, `homolog` and `-rc` tags; check the license notes of new releases first.
- n8n: change `n8n`, `n8n-worker` **and** `n8n-runner` to the same version (for example `n8nio/n8n:2.48.1` and `n8nio/runners:2.48.1`). The main instance migrates the database on start. Avoid `latest`, `next` and `beta`.

Read the release notes ([Evolution API](https://github.com/evolution-foundation/evolution-api/releases), [n8n](https://docs.n8n.io/release-notes/)) and back up both Postgres services first.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `401 Unauthorized` from Evolution API | The `apikey` header is missing or wrong |
| The bot doesn't answer | Check the workflow is published, the webhook URL ends with the workflow's path (`/webhook/...`, not `/webhook-test/...`), the basic auth matches, and the workflow responds with an `output` field. The execution list in n8n and the Evolution API logs show the call |
| n8n returns 401 to Evolution API | Basic auth mismatch; the password must be sent as `basicAuthPass` |
| The bot answers once and then ignores the user | The session expired (`expire`) or the user sent `keywordFinish` |
| The bot stops after you answered from the phone | `stopBotFromMe` is on; that is intended for human takeover |
| Can't log in to n8n | Use `N8N_INSTANCE_OWNER_EMAIL` and `N8N_OWNER_PASSWORD` from the `n8n` variables; a password changed in n8n's settings is reset on restart |
| Code node waits and times out | `n8n-runner` isn't running or its tag differs from `n8n-worker` |
| Executions stay queued | `n8n-worker` isn't running; check its logs and `QUEUE_BULL_REDIS_*` |
| `$env` access denied in an expression | n8n 2.x blocks it; paste the value into a credential instead |
| The QR code expires | Call `/instance/connect/<name>` again or reopen the instance in the manager |

Use the `WHATSAPP-BAILEYS` integration (QR code) for real numbers. In Evolution API 2.3.7 the built-in `EVOLUTION` test channel accepts messages on `/webhook/evolution` without the API key, so anyone who knows such an instance's number could trigger its bot. Don't attach production bots to `EVOLUTION` instances.

WhatsApp may ban numbers that send bulk or unsolicited messages. Evolution API and n8n are not affiliated with WhatsApp or Meta.

## License

- Evolution API: Apache License 2.0 with extra [conditions](https://github.com/EvolutionAPI/evolution-api/blob/main/LICENSE): keep the logo and copyright in the manager, and a product built on it must say so where administrators can see it.
- n8n: [Sustainable Use License](https://github.com/n8n-io/n8n/blob/master/LICENSE.md); self-hosting for your own business is allowed, selling n8n as a hosted service is not.

## Testing

Tested on 2026-11-10 with a test deploy of the template draft: all eight services healthy. Evolution API refused instance and n8n endpoints without a key and with a wrong key (401). n8n showed no setup screen, refused an anonymous owner setup, its API without a login and a wrong password, and accepted the generated owner password. A workflow created through the n8n API (Webhook with basic auth, an HTTP Request to Evolution API's private address, a JavaScript Code node, Respond to Webhook) answered with `output`, and refused calls without basic auth; a Python Code node ran too. An Evolution API instance on the built-in EVOLUTION channel got an n8n bot pointing at the private webhook URL. A simulated incoming message ran the workflow on the worker with the contact, instance, token and server URL in the payload, and Evolution API stored the workflow's reply. The community node `n8n-nodes-evolution-api` installed from the UI also reached the worker. After redeploying n8n, the worker, Evolution API and both databases, the login, the active workflow, its credential, the instance and the bot were still there, the community node was reinstalled, and a second message got its reply. The QR code was not scanned, so real WhatsApp messages were not sent or received.
