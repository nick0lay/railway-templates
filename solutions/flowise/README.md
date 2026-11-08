# Flowise

Self-hosted [Flowise](https://github.com/FlowiseAI/Flowise) on Railway: a visual builder for AI agents, chatbots and RAG pipelines that you run as an API or embed as a chat widget. The owner account is created for you at deploy, so nobody else can claim your instance. Data lives in Postgres and on a volume, and the version is pinned and tested.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/flowise-5?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
                 You / your apps / chat widget
                       │ HTTPS
                       ▼
┌──────────────────────────────────────────────────────┐
│ Railway project                                      │
│                                                      │
│  flowise :3000 (public)                              │
│    editor, REST API, prediction endpoints            │
│    volume /data: uploaded files, logs                │
│        │                                             │
│        ▼                                             │
│  Postgres :5432 (private, volume)                    │
│    flows, users, API keys, encrypted credentials     │
└──────────────────────────────────────────────────────┘
                       │
                       ▼
          LLM providers, vector stores, tools
```

## Services

| Service | Source | Role |
|---------|--------|------|
| flowise | `flowiseai/flowise:3.1.4` | Visual editor, API and chat endpoints (public) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Flows, users, API keys, credentials (private) |

## What this template does differently

- **Owner account created at deploy.** Flowise 3 no longer uses `FLOWISE_USERNAME`/`FLOWISE_PASSWORD`. On a fresh install, whoever opens the URL first creates the owner account and controls the instance. This template creates the owner on first start with your `ADMIN_EMAIL` and a generated `ADMIN_PASSWORD`, so the setup page is never exposed.
- **Persistent secrets.** The credential encryption key and the login, session and token secrets are generated once and kept in variables. Saved credentials stay readable and logins survive restarts.
- **Data persists.** Postgres on a volume for flows, users and credentials, and a volume for uploaded files. Tested: a credential, a flow and an uploaded file were still there after a redeploy.
- **Private database connection.** Flowise reaches Postgres over Railway's private network.
- **Pinned version, quiet logs.** Flowise 3.1.4 and Postgres 18 instead of `latest`; `info` log level; Flowise telemetry off.
- **Healthcheck** on `/api/v1/ping`, so Railway only routes traffic to a running instance.

## After deploy

1. Open the `flowise` URL and log in with `ADMIN_EMAIL` and the `ADMIN_PASSWORD` variable.
2. Add your model provider keys under **Credentials** (stored encrypted with `FLOWISE_SECRETKEY_OVERWRITE`).
3. Build a flow in **Agentflows** or **Chatflows**, or start from the **Marketplace** templates.
4. Create an API key under **API Keys** and **assign it to each flow** you call from outside (flow → API Endpoint → choose the key). See [Protect your flows](#protect-your-flows).
5. Call the flow from your app:

```bash
curl -X POST "https://<flowise-domain>/api/v1/prediction/<flow-id>" \
  -H "Authorization: Bearer $FLOWISE_API_KEY" -H "Content-Type: application/json" \
  -d '{"question": "Hello"}'
```

## Protect your flows

Flowise serves every flow at `/api/v1/prediction/<flow-id>` so that the embedded chat widget works. **A flow without an assigned API key answers anyone who knows its ID**, and each answer spends your LLM credits. Assign an API key to every flow you don't want public (flow → API Endpoint → API key). We tested both cases: a flow with a key refused requests without it, and a flow without a key answered them.

For a public chat widget, leave the key off that flow, and set **Rate Limit** and **Allowed Domains** under its **Configuration → General**.

## Variables

### User-configurable

| Variable | Default | Notes |
|---|---|---|
| `ADMIN_EMAIL` | (required) | Email of the owner account. You log in with it |
| `ADMIN_PASSWORD` | generated | Read it after deploy. It's applied only when the owner is created on first start |
| `LOG_LEVEL` | `info` | `debug` for troubleshooting |

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `FLOWISE_SECRETKEY_OVERWRITE` | generated | Encrypts saved credentials. **Never change it after the first deploy** |
| `JWT_AUTH_TOKEN_SECRET`, `JWT_REFRESH_TOKEN_SECRET`, `EXPRESS_SESSION_SECRET`, `TOKEN_HASH_SECRET` | generated | Sign logins, sessions, invite and reset tokens. Changing them logs everyone out |
| `FLOWISE_SETUP_BODY` | built from `ADMIN_EMAIL` and `ADMIN_PASSWORD` | Used by the start command to create the owner on first start. Later starts log `owner-setup HTTP 400`, which means the owner already exists |
| `APP_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Links in emails; also turns on secure login cookies |
| `DATABASE_TYPE`, `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`, `DATABASE_USER`, `DATABASE_PASSWORD` | `postgres`, `${{Postgres.*}}` | Private network |
| `SECRETKEY_PATH`, `BLOB_STORAGE_PATH`, `LOG_PATH` | `/data`, `/data/storage`, `/data/logs` | On the volume |
| `RAILWAY_RUN_UID` | `0` | The image runs as user `node`, but Railway volumes belong to root. Running as root lets Flowise write to the volume |
| `DISABLE_FLOWISE_TELEMETRY` | `true` | Flowise telemetry off |
| `PORT` | `3000` | |

## Users

Open-source Flowise has one account, the owner. Adding users, roles and workspaces is part of Flowise Enterprise (the user management API returns 403 without a license). Share the owner login, or give people API keys for specific flows.

The password can be changed under **Account Settings** while logged in. "Forgot password" needs email: set the SMTP variables (`SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_SECURE`, `SENDER_EMAIL`), see Flowise's [environment variables](https://docs.flowiseai.com/configuration/environment-variables).

## Tracing with Langfuse

Flowise sends traces to Langfuse per flow: open a flow → **Configuration → Advanced → Analytics → Langfuse**, and add a Langfuse credential with your Langfuse URL and project keys. You can point it at our [Langfuse v4 template](../langfuse/) (not tested with Flowise yet); if it runs in the same Railway project you can use its private address.

## Upgrading

Change the image tag (for example `flowiseai/flowise:3.1.5`). Flowise runs database migrations on start and can't go back to an older version after that. Read the [release notes](https://github.com/FlowiseAI/Flowise/releases) first.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Login fails with the generated password | The owner is created on the first start only. If you changed `ADMIN_PASSWORD` or `ADMIN_EMAIL` later, use the old values |
| The setup page appears instead of the login page | The owner wasn't created. Check the `flowise` logs for `owner-setup HTTP`: `201` means created, `400` means it already exists. Anything else, check that `ADMIN_EMAIL` is a valid address |
| Saved credentials stop working after a change | `FLOWISE_SECRETKEY_OVERWRITE` was changed. Restore the old value |
| Logs show `Error during initDatabase with file .../ReActAgentChat.js` or `.../AWSBedrock.js` | Upstream packaging issue in the Flowise 3.1.4 image: those few nodes don't load. Flowise starts and other nodes work |
| Out of memory | Flowise needs about 1 GB of RAM, more for large documents. Raise the service's memory limit |
| `EACCES` on `/data` | `RAILWAY_RUN_UID` must be `0` |

## Testing

Tested on 2026-11-04 with Flowise 3.1.4 in throwaway Railway projects, from the config and then from the template draft: both services healthy, and the owner account was created at first start (`owner-setup HTTP 201`). A stranger's sign-up was refused ("You can only have one organization"), requests without a login were refused, a wrong password was refused and the owner logged in, through the API and in the browser. A credential was saved encrypted. An agentflow ran through the API with an API key and refused requests without one. A file attachment was uploaded and read back. After a redeploy, the owner login, the credential, the flow and the file were all still there.
