# Evolution API

Self-hosted [Evolution API](https://github.com/evolution-foundation/evolution-api) on Railway: a REST API for WhatsApp that connects by scanning a QR code, like WhatsApp Web, with no Meta Business approval needed. It runs a pinned stable release with Postgres for instances, messages and contacts and Redis for cache. The global API key is generated, and the WhatsApp sessions are stored in Postgres, so they survive redeploys.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/evolution-api-7?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
          Your apps, n8n, Typebot, Chatwoot / browser (manager)
                               │ HTTPS, apikey header
                               ▼
┌──────────────────────────────────────────────────────────────┐
│ Railway project                                              │
│                                                              │
│  Evolution API :8080 (public)                                │
│    REST API, manager UI at /manager, webhooks out            │
│    volume /evolution/instances                               │
│        │                          │                          │
│        ▼                          ▼                          │
│  Postgres :5432               Redis :6379                    │
│  (private, volume)            (private, volume)              │
│  instances, sessions,         cache                          │
│  messages, contacts, chats                                   │
└──────────────────────────────────────────────────────────────┘
                               │
                               ▼
                    WhatsApp servers (outbound)
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Evolution API | `evoapicloud/evolution-api:v2.3.7` | REST API and manager UI (public). Migrates the database on start |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Instances, WhatsApp sessions, messages, contacts, chats, labels (private) |
| Redis | `redis:8.10` | Cache, append-only file on a volume (private) |

## What this template does differently

- **Pinned stable release.** Evolution API 2.3.7, the latest stable release. The image's `latest` tag currently points to a 2.4.0 release candidate, so templates on `latest` run a pre-release.
- **Messages and contacts stored.** Evolution API stores messages, contacts and chats only when the `DATABASE_SAVE_*` variables are `true`. This template sets them, so the `findMessages`, `findContacts` and `findChats` endpoints and the manager's chat view have data.
- **Sessions in Postgres.** WhatsApp sessions are kept in Postgres, not Redis (`CACHE_REDIS_SAVE_INSTANCES=false`), so a Redis restart doesn't log your numbers out. A volume on `/evolution/instances` keeps instance files too.
- **Global API key generated** (64 hex characters). Every endpoint except the welcome page needs it in the `apikey` header.
- **Private databases.** Postgres and Redis have no public TCP proxy.
- **Telemetry off** and time zone UTC (the image defaults to `America/Sao_Paulo`).
- **Healthcheck** on `/` and restart on failure.

## After deploy

1. Copy `AUTHENTICATION_API_KEY` from the `Evolution API` service variables.
2. Open `https://<your-domain>/manager`, enter the server URL `https://<your-domain>` and the API key.
3. Create an instance (channel **Baileys**), then open it and scan the QR code with WhatsApp on your phone: **Settings → Linked devices → Link a device**. You can also use a pairing code with your phone number.
4. Send a test message, set a webhook, or connect n8n, Typebot or Chatwoot in the instance settings. For a ready-made chatbot stack, see [Evolution API + Typebot](../evolution-typebot/).

The same steps with the API:

```bash
URL=https://<your-domain>
KEY=<AUTHENTICATION_API_KEY>

# Create an instance; the response has a QR code as a base64 image
curl -X POST "$URL/instance/create" -H "apikey: $KEY" -H "content-type: application/json" \
  -d '{"instanceName":"main","integration":"WHATSAPP-BAILEYS","qrcode":true}'

# Get a fresh QR code (or a pairing code with ?number=<phone>)
curl "$URL/instance/connect/main" -H "apikey: $KEY"

# After scanning: send a message
curl -X POST "$URL/message/sendText/main" -H "apikey: $KEY" -H "content-type: application/json" \
  -d '{"number":"<phone with country code>","text":"Hello from Railway"}'
```

Each instance also gets its own API key (`hash` in the create response) that works only for that instance. Give that key to an app instead of the global key.

API reference: https://doc.evolution-api.com

## Variables

### User-configurable

| Variable | Default | Notes |
|---|---|---|
| `AUTHENTICATION_API_KEY` | generated | Global API key for every instance and for the manager. Change it to rotate the key |
| `DEL_INSTANCE` | `false` | Minutes before a disconnected instance is deleted; `false` keeps it |
| `DATABASE_SAVE_DATA_*`, `DATABASE_SAVE_MESSAGE_UPDATE` | `true` | Store new messages, status updates, contacts, chats, labels and history synced from the phone. Set to `false` to store less |
| `CORS_ORIGIN` | `*` | Browser origins allowed to call the API. Requests still need the API key |
| `LANGUAGE` | `en` | Language of the manager and system messages |
| `TZ` | `UTC` | Time zone for logs and schedules |
| `LOG_LEVEL` | `ERROR,WARN,INFO,LOG,WEBHOOKS` | Add `DEBUG,VERBOSE` when troubleshooting |
| `TELEMETRY_ENABLED` | `false` | Usage telemetry to the Evolution API project |
| `TYPEBOT_ENABLED`, `CHATWOOT_ENABLED`, `N8N_ENABLED`, `FLOWISE_ENABLED`, `OPENAI_ENABLED`, `DIFY_ENABLED` | `true` | Chatbot and inbox integrations, switched on so their tabs work in the manager. Each is still set up per instance. Set one to `false` to hide it |
| `TYPEBOT_API_VERSION` | `latest` | Typebot 3.x API (`startChat`). `old` uses Typebot's deprecated `sendMessage` endpoint |

Webhooks, RabbitMQ, SQS, S3 media storage and the global settings of the integrations above use more variables; see the [environment variable list](https://github.com/evolution-foundation/evolution-api/blob/2.3.7/.env.example). Most integrations can also be set per instance in the manager.

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `SERVER_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Used in webhook payloads and media links. Change it if you add a custom domain |
| `PORT`, `SERVER_PORT`, `SERVER_TYPE` | `8080`, `${{PORT}}`, `http` | Railway terminates HTTPS in front of the service |
| `DATABASE_PROVIDER` | `postgresql` | |
| `DATABASE_CONNECTION_URI` | `${{Postgres.DATABASE_URL}}` | Private network |
| `DATABASE_CONNECTION_CLIENT_NAME` | `evolution` | Separates installations that share a database |
| `CACHE_REDIS_ENABLED`, `CACHE_REDIS_URI` | `true`, `${{Redis.REDIS_URL}}` | Private network |
| `CACHE_REDIS_PREFIX_KEY` | `evolution` | Prefix for Redis keys |
| `CACHE_REDIS_SAVE_INSTANCES` | `false` | Keeps sessions in Postgres |
| `CACHE_LOCAL_ENABLED` | `false` | Redis is the cache |
| `AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES` | `true` | Lists instances in the manager |

## Custom domain

Add the domain to the `Evolution API` service, then set `SERVER_URL=https://your-domain` and redeploy. Update webhook URLs in the apps that call the API.

## Upgrading

Change the image tag of the `Evolution API` service (for example `evoapicloud/evolution-api:v2.4.0` once it's released). Evolution API migrates the database on start. Read the [release notes](https://github.com/evolution-foundation/evolution-api/releases) first and back up Postgres before upgrading; avoid `latest`, `homolog` and `-rc` tags in production.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `401 Unauthorized` | The `apikey` header is missing or wrong. Use `AUTHENTICATION_API_KEY`, or the instance's own key for that instance |
| The QR code doesn't appear or keeps changing | QR codes expire quickly and are replaced by new ones. Call `/instance/connect/<name>` again, or scan faster from the manager |
| The instance stays in `connecting` | Nobody scanned the QR code yet, or WhatsApp refused the link. Delete and recreate the instance, then scan again |
| Sending a message hangs | The instance isn't connected. Check `/instance/connectionState/<name>` first |
| The number was logged out after a while | WhatsApp unlinks devices that are idle for a long time or are flagged for spam. Scan the QR code again |
| The welcome page shows the manager link with `http://` | Cosmetic: Evolution API builds that link from the request. Open the manager with `https://` |
| Webhooks or media links point to the wrong host | `SERVER_URL` doesn't match your domain |

WhatsApp may ban numbers that send bulk or unsolicited messages. Evolution API is not affiliated with WhatsApp or Meta.

## License

Evolution API uses the Apache License 2.0 with extra [conditions](https://github.com/EvolutionAPI/evolution-api/blob/main/LICENSE): commercial use is allowed, but don't remove or change the logo and copyright in the manager, and a product built on Evolution API must say so where administrators can see it (for example on a settings or docs page). Otherwise the producer may require a commercial license.

## Testing

Tested on 2026-11-06 with Evolution API 2.3.7 in a throwaway Railway project, from the config: all three services healthy, and the database was migrated on the first start. The welcome page answered without a key. Listing instances, creating an instance and checking credentials were refused without a key and with a wrong key (401), and worked with the generated key. A new instance returned a QR code as a base64 image, and the connect endpoint returned fresh QR codes; the QR code was not scanned, so sending and receiving messages were not tested. The manager UI loaded at `/manager`. After redeploying all services, the instance was loaded back from Postgres, still waiting for its QR scan, and the database migration step found nothing to apply.
