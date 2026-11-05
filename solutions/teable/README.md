# Teable

Self-hosted [Teable](https://github.com/teableio/teable) on Railway: an open-source, no-code database with a spreadsheet interface, an alternative to Airtable. The admin account is created for you at deploy and public sign-up is off, so nobody else can claim your instance. Data lives in Postgres, attachments on a volume, every secret is generated, and the version is pinned and tested.

This template uses Teable's official image, which includes the paid features. **Paid features stay locked until you add a license**; everything else works without one. If you only want the open-source build, use [Teable Community](../teable-community/) instead.

<!-- Deploy button: add after publishing, using railway.com/deploy/<railway_code>?referralCode=... (see railway-ops templates.yaml) -->

## Architecture

```
                 You / your team / API clients
                            │ HTTPS
                            ▼
┌──────────────────────────────────────────────────────────┐
│ Railway project                                          │
│                                                          │
│  teable :3000 (public)                                   │
│    web app, REST API, real-time collaboration            │
│    attachments on a volume (/app/.assets)                │
│        │                         │                       │
│        ▼                         ▼                       │
│  Postgres :5432            Redis :6379                   │
│  (private, volume)         (private, volume)             │
│  tables, records, users    cache, sessions, job queues   │
└──────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| teable | `ghcr.io/teableio/teable:release.2026-11-05T12-40-53Z.3790` | Web app and API (public). Runs database migrations on start. Attachments on a volume |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Every table and record, users, spaces (private) |
| Redis | `redis:8.10` | Cache, sessions and job queues, `noeviction` and append-only file on a volume (private) |

## What this template does differently

- **Admin account created at deploy.** On a fresh Teable install, the first person to sign up becomes the instance admin, and anyone can sign up after that. This template signs up the admin on first start with your `ADMIN_EMAIL` and a generated `ADMIN_PASSWORD`, creates a first space, and then turns off "Allow creating new accounts". Strangers get "The current instance disallow sign up by the administrator".
- **No public default keys.** If its secrets aren't set, Teable starts with keys that are in its public git history and logs a security warning. This template generates `SECRET_KEY`, the sandbox token secret and every encryption key and IV, so the warning doesn't appear.
- **Pinned version.** A fixed Teable release instead of `latest`, plus Postgres 18 and Redis 8.10. Teable releases several times a week and migrates the database on start, so you upgrade when you choose.
- **Redis for cache, sessions and queues**, with `noeviction` and an append-only file on a volume, and no public TCP proxy.
- **Attachments on a volume**, so uploads survive redeploys.
- **Private networking** for Postgres and Redis; the self-hosted telemetry report is off; healthcheck on `/health`.

Teable runs the web app, API and an automation sandbox in one container; in our test it used about 1.7 GB of RAM while idle.

## Teable or Teable Community?

| | Teable (this template) | [Teable Community](../teable-community/) |
|---|---|---|
| Image | `ghcr.io/teableio/teable` (official) | `ghcr.io/teableio/teable-community` |
| License | AGPL-3.0 Community features, plus paid features under Teable's commercial terms | AGPL-3.0 only |
| Tables, views, forms, links, formulas, collaboration, REST API | Yes | Yes |
| Paid features (see below) | Locked until you add a license | Not included |
| Automation script sandbox | Included | Not included |
| Telemetry | License telemetry report, turned off here (`TELEMETRY_REPORT_DISABLED=true`) | No license telemetry |

Both templates use the same setup: admin created at deploy, sign-up off, generated secrets, Postgres, Redis and a volume.

## Paid features and license

Without a license this instance runs Teable's free feature set. A license unlocks the features of your self-hosted plan; Teable's docs list them per page, for example the admin audit log, instance-wide automation run monitoring, separate customer-managed databases for a space (BYODB), admin announcements and AI features. See the [self-hosted pricing page](https://app.teable.ai/public/pricing?host=self-hosted) for what each plan includes.

Teable licenses are not set through an environment variable. To activate one:

1. Log in as the admin, click the space name in the upper left, open **System Admin → Self-hosted license** and copy the **Instance ID**.
2. Subscribe on the [pricing page](https://app.teable.ai/public/pricing?host=self-hosted) and enter the Instance ID; you get a **License Key**.
3. Paste the License Key under **System Admin → Self-hosted license** and activate it. Optionally turn on **Auto-renew**; Teable first checks that the instance can reach its license server.

The Instance ID is stored in Postgres, so it stays the same across redeploys and upgrades. Paid plans count seats per instance (users with Editor role or higher). When a license expires, the instance goes back to the free feature set and keeps all data. See Teable's [license guide](https://help.teable.ai/en/deploy/activate).

## After deploy

1. Open the `teable` URL and log in with `ADMIN_EMAIL` and the `ADMIN_PASSWORD` variable.
2. Open the first space (`SPACE_NAME`), create a base and start a table, or import a CSV or Excel file.
3. Add your team (see below).
4. For integrations, create a token under **Personal access tokens** in the account menu (click your name), and use the REST API (`/api/...`).

## Adding users

Public sign-up is off. To add people:

- **Email invitations:** set the email variables (below), then invite people from the space. New users register through the link in the email. Shared invitation links don't work while sign-up is off.
- **Without email:** open **System Admin** (click the space name in the upper left), go to **Instance settings** and turn on **Allow creating new accounts**. Let people sign up, then turn it off again.

## Variables

### User-configurable

| Variable | Default | Notes |
|---|---|---|
| `ADMIN_EMAIL` | (required) | Email of the admin account. You log in with it |
| `ADMIN_PASSWORD` | generated | Read it after deploy. It's applied only when the admin is created on first start |
| `SPACE_NAME` | `My Space` | Name of the first space, created on first start |

To send emails (invitations, password resets, notifications), add `BACKEND_MAIL_HOST`, `BACKEND_MAIL_PORT`, `BACKEND_MAIL_SECURE`, `BACKEND_MAIL_SENDER`, `BACKEND_MAIL_SENDER_NAME`, `BACKEND_MAIL_AUTH_USER` and `BACKEND_MAIL_AUTH_PASS` to `teable`. See Teable's [email docs](https://help.teable.ai/en/deploy/email).

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `SECRET_KEY` | generated | Signs logins and sessions, and encrypts stored credentials. **Never change it after the first deploy** |
| `BACKEND_*_ENCRYPTION_KEY`, `BACKEND_*_ENCRYPTION_IV` | generated | Encrypt attachment links, access tokens, email links and external database URLs. **Never change them after the first deploy** |
| `SANDBOX_JWT_SECRET` | generated | Signs tokens for the automation script sandbox inside the container |
| `TEABLE_SETUP_JS` | script | Run by the start command to create the admin and first space and turn off sign-up on first start. Later starts log `owner already exists, skipping` |
| `PUBLIC_ORIGIN` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL, no trailing slash. Update it if you add a custom domain |
| `PRISMA_DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Private network |
| `BACKEND_CACHE_PROVIDER`, `BACKEND_CACHE_REDIS_URI` | `redis`, `${{Redis.REDIS_URL}}` | Private network |
| `BACKEND_STORAGE_PROVIDER` | `local` | Attachments on the volume at `/app/.assets` |
| `TELEMETRY_REPORT_DISABLED` | `true` | Self-hosted telemetry report off |
| `NEXT_ENV_IMAGES_ALL_REMOTE` | `true` | Lets Teable show images from any URL |
| `PORT` | `3000` | |

## Custom domain

Add the domain to the `teable` service, then set `PUBLIC_ORIGIN=https://your-domain` (no trailing slash) and redeploy. With the wrong `PUBLIC_ORIGIN`, imports and image uploads fail.

## Upgrading

Teable publishes date-based release tags (`release.<date>.<build>`) and a `latest` channel. Pick a newer tag from [GitHub Packages](https://github.com/teableio/teable/pkgs/container/teable) and change the image tag on `teable`. Teable migrates the database on start and can't go back to an older version after that, so back up Postgres first (see Teable's [upgrade guide](https://help.teable.ai/en/deploy/upgrade)).

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Login fails with the generated password | The admin is created on the first start only. If you changed `ADMIN_PASSWORD` or `ADMIN_EMAIL` later, use the old values |
| The sign-up page lets anyone register on a fresh deploy | The admin wasn't created. Check the `teable` logs for `[owner-setup]`; `public sign-up turned off: ok` means it worked |
| "The current instance disallow sign up by the administrator" | Expected. See [Adding users](#adding-users) |
| Imports or image uploads fail | `PUBLIC_ORIGIN` doesn't match the URL you use, or ends with `/` |
| `ERR_PNPM_CATALOG_ENTRY_NOT_FOUND_FOR_SPEC` in the logs during migration | Comes from Teable's image and doesn't stop it; the migration still completes |
| Attachment links or access tokens stop working after a change | An encryption key or `SECRET_KEY` was changed. Restore the old value |

## Testing

Tested on 2026-11-05 with Teable `release.2026-11-05T12-40-53Z.3790` (the `latest` stable release that day) in throwaway Railway projects: all three services healthy (Teable at about 1.7 GB of RAM while idle), and the start command created the admin and first space and turned off sign-up (`[owner-setup] public sign-up turned off: ok`), with no security warning about default keys. Requests without a login were refused (401), a stranger's sign-up was refused, a wrong password was refused, and the admin logged in as instance admin. Through the API, a base and a table with text, number and attachment fields were created, records were added, and a file was uploaded to a record and read back. After redeploying Teable, Postgres and Redis, the login, the records and the attachment were still there, and the setup step skipped itself. On 2026-11-06 the template draft was deployed and checked in a browser: the admin logged in, and System Admin (Instance settings, Self-hosted license with the Instance ID) and Personal access tokens opened as described.
