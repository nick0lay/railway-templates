# Deploy and Host WAHA on Railway

WAHA (WhatsApp HTTP API) is an open-source REST API for WhatsApp. You link a number by scanning a QR code, like WhatsApp Web, with no Meta Business approval, then send and receive messages, media, groups and channels over HTTP, webhooks and websockets. It comes with a dashboard, Swagger docs and ready integrations for n8n and Chatwoot.

## About Hosting WAHA

WAHA is a Node.js server that keeps WhatsApp sessions open and exposes them as a REST API. It needs a public HTTPS URL for its API, dashboard and media links, an API key, and storage for session data so a restart doesn't log your numbers out.

This template runs a pinned WAHA release on the GOWS engine, which talks to WhatsApp over a websocket without a browser, so it needs much less memory than the Chromium image. Sessions, their webhook settings and API keys are stored in a private PostgreSQL database, and received media files are kept on a volume. The API key and the dashboard and Swagger passwords are generated.

## Common Use Cases

- WhatsApp chatbots and AI agents with n8n, Chatwoot or your own backend
- Order confirmations, reminders and alerts sent from your apps
- Receiving WhatsApp messages in your backend through webhooks
- Running several WhatsApp numbers from one server, each as its own session
- Customer support inboxes on WhatsApp

## Dependencies for WAHA Hosting

- PostgreSQL 18 (sessions, session settings, API keys)
- A volume for media files

### Deployment Dependencies

- WAHA: https://github.com/devlikeapro/waha
- Documentation: https://waha.devlike.pro
- Image: https://hub.docker.com/r/devlikeapro/waha

### Implementation Details

**What you set:** nothing. The API key and both passwords are generated.

**After deploy:**

1. Open the WAHA service variables and copy `WAHA_API_KEY`, `WAHA_DASHBOARD_PASSWORD` and `WHATSAPP_SWAGGER_PASSWORD`.
2. Open `https://your-domain/dashboard`, log in as `admin` with the dashboard password, then add your server with the URL `https://your-domain` and the API key.
3. Start a session and scan its QR code in WhatsApp under Settings, Linked devices.
4. Send messages with the `X-Api-Key` header:

```bash
curl -X POST "https://your-domain/api/sendText" \
  -H "X-Api-Key: YOUR_API_KEY" -H "Content-Type: application/json" \
  -d '{"session":"default","chatId":"491234567890@c.us","text":"Hello from Railway"}'
```

Swagger docs are at `https://your-domain/` (login `admin` with the Swagger password).

**This template:**

- Pins WAHA 2026.10.1 on the `gows` image (no browser) instead of the moving `latest` tag
- Requires the API key on every `/api` endpoint and on `/health`; only `/ping` is open, for the healthcheck
- Protects the dashboard and Swagger with their own generated passwords, separate from the API key
- Stores sessions, webhook settings and API keys in PostgreSQL, so redeploys keep your numbers linked and your webhooks configured
- Keeps received media files on a volume, so media links in webhooks still work after a redeploy
- Sets the public URL for media links to your Railway domain (HTTPS)
- Keeps PostgreSQL private, with no public TCP proxy
- Checks health on `/ping` and restarts on failure

**Notes:** WAHA Core is free and open source under the Apache License 2.0; since version 2026.6.1 the former Plus features (unlimited sessions, all storages, API key management) are part of the free image. If you add a custom domain, set `WAHA_BASE_URL` and `WAHA_PUBLIC_URL` to it. WhatsApp may ban numbers that send bulk or unsolicited messages. WAHA is not affiliated with WhatsApp or Meta; you are responsible for how you use it.

## Why Deploy WAHA on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying WAHA on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
