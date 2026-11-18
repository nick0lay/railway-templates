# WAHA

Self-hosted [WAHA](https://github.com/devlikeapro/waha) (WhatsApp HTTP API) on Railway: a REST API for WhatsApp that links a number by scanning a QR code, like WhatsApp Web, with no Meta Business approval. It runs a pinned release on the browserless GOWS engine, keeps sessions, webhook settings and API keys in a private Postgres, and stores media files on a volume. The API key and the dashboard and Swagger passwords are generated.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/waha-202610?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
        Your apps, n8n, Chatwoot / browser (dashboard, Swagger)
                               │ HTTPS
                               │ X-Api-Key header (API), basic auth (dashboard, Swagger)
                               ▼
┌──────────────────────────────────────────────────────────────┐
│ Railway project                                              │
│                                                              │
│  WAHA :3000 (public)                                         │
│    REST API /api, dashboard /dashboard, Swagger /            │
│    GOWS engine (no browser), webhooks out                    │
│    volume /data (media files)                                │
│        │                                                     │
│        ▼                                                     │
│  Postgres :5432 (private, volume)                            │
│  sessions, session settings and webhooks, API keys, apps     │
└──────────────────────────────────────────────────────────────┘
                               │
                               ▼
                    WhatsApp servers (outbound)
```

## Services

| Service | Source | Role |
|---------|--------|------|
| WAHA | `devlikeapro/waha:gows-2026.10.1` | REST API, dashboard and Swagger (public) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Sessions, session settings, API keys (private). WAHA creates one database per session |

## What this template does differently

- **Pinned release, light image.** WAHA 2026.10.1 on the `gows` image: no Chromium, about 720 MB instead of 1 GB, and much less memory per session. Templates on `devlikeapro/waha` or `:latest` run the Chromium image and change version on every redeploy.
- **Auth on every surface.** The API key is required on all `/api` endpoints and on `/health`. The dashboard and Swagger each have their own generated password, separate from the API key. Only `/ping` is open, for the healthcheck.
- **Sessions in Postgres.** Sessions, their webhook settings and API keys created with the Keys API survive redeploys and can be backed up with Railway's Postgres backups.
- **Media on a volume.** Received files go to `/data/media` on a volume. Templates that leave them in `/app/.media` lose them on every redeploy, and the media links in old webhooks break.
- **Correct public URL.** `WAHA_BASE_URL` is your Railway domain over HTTPS, so `media.url` in webhook payloads can be downloaded from outside Railway.
- **Private database.** Postgres has no public TCP proxy.
- **Healthcheck** on `/ping` and restart on failure.

## After deploy

1. Copy `WAHA_API_KEY`, `WAHA_DASHBOARD_PASSWORD` and `WHATSAPP_SWAGGER_PASSWORD` from the `WAHA` service variables.
2. Open `https://your-domain/dashboard` and log in as `admin` with the dashboard password. Add the server: URL `https://your-domain`, API key `WAHA_API_KEY`.
3. Create and start a session, then scan its QR code with WhatsApp on your phone: **Settings → Linked devices → Link a device**.
4. Set a webhook in the session settings, send a test message, or connect n8n or Chatwoot.

The same steps with the API:

```bash
URL=https://your-domain
KEY=YOUR_API_KEY

# Create and start a session with a webhook
curl -X POST "$URL/api/sessions" -H "X-Api-Key: $KEY" -H "Content-Type: application/json" \
  -d '{"name":"default","start":true,"config":{"webhooks":[{"url":"https://your-app/webhook","events":["message","session.status"]}]}}'

# QR code as a PNG (or ?format=raw for the text value)
curl "$URL/api/default/auth/qr?format=image" -H "X-Api-Key: $KEY" -o qr.png

# After scanning: send a message
curl -X POST "$URL/api/sendText" -H "X-Api-Key: $KEY" -H "Content-Type: application/json" \
  -d '{"session":"default","chatId":"491234567890@c.us","text":"Hello from Railway"}'
```

To give an app access to one session only, create a session key with `POST /api/keys` (`{"isAdmin": false, "session": "default", "isActive": true}`) or in the dashboard.

API reference: Swagger at `https://your-domain/` (login `admin` with the Swagger password) and https://waha.devlike.pro/docs/overview/introduction/

## Variables

### User-configurable

| Variable | Default | Notes |
|---|---|---|
| `WAHA_API_KEY` | generated | Admin API key, sent as `X-Api-Key`. Change it to rotate the key. You can also store a hash: `sha512:HEX_HASH` |
| `WAHA_DASHBOARD_USERNAME`, `WAHA_DASHBOARD_PASSWORD` | `admin`, generated | Dashboard login at `/dashboard` |
| `WHATSAPP_SWAGGER_USERNAME`, `WHATSAPP_SWAGGER_PASSWORD` | `admin`, generated | Swagger login at `/` |
| `WAHA_DASHBOARD_ENABLED`, `WHATSAPP_SWAGGER_ENABLED` | `true` | Set to `false` to switch a panel off |
| `WHATSAPP_FILES_LIFETIME` | `0` | Seconds to keep received media files; `0` keeps them |
| `WAHA_LOG_LEVEL`, `WAHA_LOG_FORMAT` | `info`, `JSON` | Use `debug` when troubleshooting |
| `TZ` | `UTC` | Time zone |

Don't set `WAHA_API_KEY` or the passwords to common values such as `admin`, `waha` or `123`: WAHA ignores them and generates random ones on every start. Proxies, S3 media storage, workers, events and integrations use more variables; see the [configuration reference](https://waha.devlike.pro/docs/how-to/config/).

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `PORT`, `WHATSAPP_API_PORT` | `3000`, `${{PORT}}` | Port the domain routes to |
| `WHATSAPP_DEFAULT_ENGINE` | `GOWS` | The `gows` image has no browser, so `WEBJS` and `WPP` don't work in it |
| `WHATSAPP_SESSIONS_POSTGRESQL_URL` | `${{Postgres.DATABASE_URL}}` | Session storage over the private network. Removing it moves storage to the volume and loses existing sessions |
| `WAHA_LOCAL_STORE_BASE_DIR` | `/data/sessions` | Used only without the Postgres URL |
| `WHATSAPP_FILES_FOLDER`, `WAHA_MEDIA_STORAGE` | `/data/media`, `LOCAL` | Media files on the volume |
| `WAHA_BASE_URL`, `WAHA_PUBLIC_URL`, `WHATSAPP_API_SCHEMA` | `https://${{RAILWAY_PUBLIC_DOMAIN}}`, same, `https` | Media links in webhooks and the dashboard link. Change them if you add a custom domain |
| `WAHA_PRINT_QR` | `false` | QR codes are fetched from the API or dashboard, not the logs |

## Custom domain

Add the domain to the `WAHA` service, set `WAHA_BASE_URL` and `WAHA_PUBLIC_URL` to `https://your-domain` and redeploy.

## Upgrading

Change the image tag of the `WAHA` service, for example `devlikeapro/waha:gows-2026.11.1`, keeping the `gows-` prefix. Read the [changelog](https://waha.devlike.pro/docs/overview/changelog/) first and avoid the moving `latest`, `gows` and `dev` tags. To use the browser engine instead (`WEBJS`, needed for a few features), switch to `devlikeapro/waha:latest-VERSION`, set `WHATSAPP_DEFAULT_ENGINE=WEBJS` and give the service more memory; sessions linked with GOWS must be scanned again.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `401 Unauthorized` on `/api` | The `X-Api-Key` header is missing or wrong. Use `WAHA_API_KEY` or a key created with the Keys API |
| The browser asks for a login on `/` or `/dashboard` | Swagger and the dashboard use separate basic-auth logins: `admin` with `WHATSAPP_SWAGGER_PASSWORD` or `WAHA_DASHBOARD_PASSWORD` |
| The dashboard can't reach the server | Add the server in the dashboard with `https://your-domain` and the API key |
| The QR code keeps changing | QR codes expire after about 20 seconds. Fetch a new one, or scan from the dashboard |
| The session is `FAILED` | Nobody scanned the QR code in time, or WhatsApp unlinked the device. Restart the session and scan again |
| Media links in webhooks don't open | `WAHA_BASE_URL` doesn't match your domain, or the request is missing the API key (media downloads need it too) |

WhatsApp may ban numbers that send bulk or unsolicited messages. WAHA is not affiliated with WhatsApp or Meta.

## License

WAHA is licensed under the [Apache License 2.0](https://github.com/devlikeapro/waha/blob/core/LICENSE). Since version 2026.6.1 the features of the former paid WAHA Plus (unlimited sessions, all storages, API key management) are part of the free `devlikeapro/waha` image; there is no separate Plus image to buy. You are responsible for how you use WhatsApp through it.

## Testing

Tested on 2026-11-18 with WAHA 2026.10.1 (GOWS) in a throwaway Railway project deployed from the template: both services healthy. `/ping` answered without a key. The API (`/api/sessions`, `/api/keys`, `/api/server/version`, `/health`) refused requests without a key and with a wrong key, in the header and as a query parameter (401), and worked with the generated key. Swagger and the dashboard refused requests without a login, with a wrong password and with the other panel's password, and opened with their own. A session created with a webhook reached `SCAN_QR_CODE` and returned a QR code as text and as a PNG; the webhook was updated, WAHA posted events to it, and a session-scoped key could read its session but not create sessions or list keys. The QR code was not scanned, so sending and receiving messages were not tested. After redeploying WAHA and Postgres, the session, its webhook settings (URL, events, HMAC key, custom header) and the session key were still there, and the session started again with a new QR code.
