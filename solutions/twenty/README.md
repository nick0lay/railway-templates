# Twenty

Self-hosted [Twenty](https://github.com/twentyhq/twenty) on Railway: an open-source CRM, a modern alternative to Salesforce and HubSpot. The owner account and workspace are created for you at deploy, so nobody else can claim your instance. Data lives in Postgres, files in a Railway Bucket, and the version is pinned and tested.

<!-- Deploy button: add after publishing, using railway.com/deploy/<railway_code>?referralCode=... (see railway-ops templates.yaml) -->

## Architecture

```
                     You / your team / API clients
                               │ HTTPS
                               ▼
┌──────────────────────────────────────────────────────────────┐
│ Railway project                                              │
│                                                              │
│  twenty :3000 (public)          twenty-worker                │
│    web app, GraphQL/REST API      background jobs, cron      │
│        │        │                   │        │               │
│        ▼        ▼                   ▼        ▼               │
│  Postgres :5432          Redis :6379          Bucket (S3)    │
│  (private, volume)       (private, volume)    files          │
│  records, users          cache, job queues                   │
└──────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| twenty | `twentycrm/twenty:v2.55.0` | Web app and API (public). Runs database migrations on start |
| twenty-worker | `twentycrm/twenty:v2.55.0` | Background jobs and scheduled tasks (`yarn worker:prod`) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | CRM data, users, workspace (private) |
| Redis | `redis:8.10` | Cache and job queues, `noeviction` and append-only file on a volume (private) |
| Bucket | Railway Bucket | Uploaded files, shared by the server and the worker |

## What this template does differently

- **Owner account and workspace created at deploy.** On a fresh Twenty install, whoever opens the URL first creates the workspace and becomes the server admin. This template creates the owner on first start with your `ADMIN_EMAIL` and a generated `ADMIN_PASSWORD`, and activates the workspace. After that, Twenty refuses sign-ups without an invitation.
- **Pinned version.** Twenty 2.55.0, Postgres 18 and Redis 8.10 instead of `latest`. Twenty releases often and migrates the database on start, so you upgrade when you choose.
- **Both secrets generated.** `APP_SECRET` and `ENCRYPTION_KEY` (which encrypts connected-account tokens) are generated once and shared with the worker.
- **Redis set up for job queues.** `noeviction`, as Twenty requires for its queues, and an append-only file on a volume so queued jobs survive restarts. Redis has no public TCP proxy.
- **Files in a Railway Bucket**, so the server and the worker see the same files.
- **Private networking** for Postgres and Redis; telemetry off; healthcheck on `/healthz`.

## After deploy

1. Open the `twenty` URL and log in with `ADMIN_EMAIL` and the `ADMIN_PASSWORD` variable. On the first login, Twenty asks for your name and offers to invite your team; you can skip that.
2. Rename the workspace under **Settings → General** if you like (it starts as `WORKSPACE_NAME`).
3. Invite your team under **Settings → Members**. Invitations are sent by email, so set the email variables first (see below).
4. For integrations, create an API key or a webhook under **Settings → Developers**.

## Variables

### User-configurable

| Variable | Default | Notes |
|---|---|---|
| `ADMIN_EMAIL` | (required) | Email of the owner account. You log in with it |
| `ADMIN_PASSWORD` | generated | Read it after deploy. It's applied only when the owner is created on first start |
| `WORKSPACE_NAME` | `My workspace` | Name of the workspace created on first start |

To send emails (invitations, password resets), add to `twenty` and `twenty-worker`: `EMAIL_DRIVER=smtp`, `EMAIL_SMTP_HOST`, `EMAIL_SMTP_PORT`, `EMAIL_SMTP_USER`, `EMAIL_SMTP_PASSWORD`, `EMAIL_FROM_ADDRESS`, `EMAIL_FROM_NAME`. Gmail and Microsoft sync and sign-in need their own OAuth variables; see Twenty's [self-hosting docs](https://twenty.com/developers/section/self-hosting).

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `APP_SECRET`, `ENCRYPTION_KEY` | generated | Sign logins and encrypt stored tokens. **Never change them after the first deploy** |
| `TWENTY_SETUP_JS` | script | Run by the start command to create the owner and workspace on first start. Later starts log `owner-setup: skipped: User already exists` |
| `SERVER_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL. Update it if you add a custom domain |
| `PG_DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Private network |
| `REDIS_URL` | `${{Redis.REDIS_URL}}?family=0` | Private network (IPv6) |
| `STORAGE_TYPE`, `STORAGE_S3_*` | `s3`, `${{Bucket.*}}` | Files in the Railway Bucket |
| `DISABLE_DB_MIGRATIONS`, `DISABLE_CRON_JOBS_REGISTRATION` | `true` on the worker | Migrations and cron registration run on `twenty` |
| `TELEMETRY_ENABLED` | `false` | Twenty telemetry off |
| `PORT`, `NODE_PORT` | `3000` | |

## Custom domain

Add the domain to the `twenty` service, then set `SERVER_URL=https://your-domain` on `twenty` (the worker reads it from there).

## Upgrading

Change the image tag on both `twenty` and `twenty-worker` (for example `twentycrm/twenty:v2.56.0`). The `twenty` service migrates the database on start; Twenty can't go back to an older version after that. Upgrade one minor version at a time if you skipped several, and read the [release notes](https://github.com/twentyhq/twenty/releases) first.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Login fails with the generated password | The owner is created on the first start only. If you changed `ADMIN_PASSWORD` or `ADMIN_EMAIL` later, use the old values |
| The sign-up / create-workspace page appears for a fresh deploy | The owner wasn't created. Check the `twenty` logs for `owner-setup:`; `workspace ACTIVE` means it worked |
| "New workspace setup is disabled" when someone signs up | Expected: invite them from Settings → Members |
| Links in emails or OAuth redirects point to the wrong host | `SERVER_URL` doesn't match your domain |
| Jobs (email sync, workflows) don't run | Check that `twenty-worker` is running and uses the same image tag as `twenty` |
| Connected accounts stop working after a change | `ENCRYPTION_KEY` was changed. Restore the old value |

## Testing

Tested on 2026-11-04 with Twenty 2.55.0 in throwaway Railway projects, from the config and then from the template draft: all four services healthy, and the owner and workspace were created at first start (`owner-setup: workspace ACTIVE`). The API refused requests without a login, a stranger's sign-up was refused ("New workspace setup is disabled"), a wrong password was refused, and the owner logged in as server admin. A company and a linked person were created through the GraphQL API, and a file was uploaded and read back. The worker processed scheduled jobs. After a redeploy, the owner login, the records and the file were still there, and the setup step skipped itself. In the browser, the owner logged in, finished Twenty's first-login steps, and reached Settings → General, Members and Developers.
