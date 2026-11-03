# Typebot

Self-hosted [Typebot](https://github.com/baptisteArno/typebot.io) on Railway: a visual chatbot builder for lead forms, quizzes, support bots and AI chats that you embed on your site or connect to WhatsApp. Sign-in works right after deploy, without setting up an email provider.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/typebot-3?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
               You (browser)                 Your visitors
                   │ HTTPS                        │ HTTPS
                   ▼                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ Railway project                                                  │
│                                                                  │
│  typebot-builder :3000 (public)     typebot-viewer :3000 (public)│
│   editor, sign-in, API                runs your published bots   │
│     │  │  │                              │                       │
│     │  │  └─ SMTP :1025 ─► mailpit :8025 (public, password)       │
│     │  │                    catches sign-in emails                │
│     │  └──────────── Postgres :5432 (volume) ◄─┤                  │
│     └─────────────── Redis    :6379 (volume) ◄─┤                  │
│     │                                          │                  │
│     └── uploads ──► Bucket (Railway Bucket, private) ◄─ files     │
│                                                    :8080 (public) │
│                     serves only public/ (images in your bots)     │
└──────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| typebot-builder | `baptistearno/typebot-builder:3.19` | Bot editor, sign-in, results, API (public) |
| typebot-viewer | `baptistearno/typebot-viewer:3.19` | Runs published bots for your visitors (public) |
| mailpit | `axllent/mailpit:v1.33` | Catches the emails Typebot sends, such as sign-in links, and shows them on a password-protected page (public) |
| files | `rclone/rclone:1.75.2` | Read-only web server for the bucket's `public/` folder (public) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Bots, results, users (private) |
| Redis | `redis:8.10` | Sessions and rate limits (private) |
| Bucket | Railway Bucket | Uploaded images, videos and files |

## What this template does differently

- **Sign-in works without an email provider.** Typebot only signs you in with an emailed link. Other templates need working SMTP settings at deploy time, and when they're wrong nobody can sign in. Here the emails go to Mailpit: open the `mailpit` URL, log in as `admin` with `MAILPIT_PASSWORD`, and click the link. Switch to a real provider any time (see below).
- **Railway Bucket instead of MinIO.** No MinIO, MinIO console and bucket-setup container to run. Railway Buckets are private, and Typebot needs public URLs for images in your bots, so the small `files` service serves only the `public/` folder: no folder listing, and nothing outside `public/`.
- **Sign-up closed.** Only `ADMIN_EMAIL` and people you invite can create an account.
- **Pinned, tested versions.** Typebot 3.19, Postgres 18, Redis 8.10, Mailpit 1.33, rclone 1.75. The builder and viewer must stay on the same version.
- **All features on.** `DEFAULT_WORKSPACE_PLAN=UNLIMITED`, so self-hosted workspaces aren't limited to the free plan.

## After deploy

1. Open the `typebot-builder` URL and enter your `ADMIN_EMAIL`.
2. Open the `mailpit` URL, log in as `admin` with the `MAILPIT_PASSWORD` variable of `mailpit`, open the "Sign in to Typebot" email and click the link.
3. Build a bot and publish it. It runs on the `typebot-viewer` URL; embed it from the **Share** tab.

## Variables

### User-configurable (typebot-builder)

| Variable | Default | Notes |
|---|---|---|
| `ADMIN_EMAIL` | (required) | You sign in with it. Admin role and unlimited plan. Several emails: comma-separated |
| `DISABLE_SIGNUP` | `true` | `false` lets anyone with the URL create an account |
| `DEFAULT_WORKSPACE_PLAN` | `UNLIMITED` | `FREE` limits new workspaces like Typebot Cloud's free plan |
| `NEXT_PUBLIC_BOT_FILE_UPLOAD_MAX_SIZE` | `10` | Largest file a visitor can upload in a bot, in MB |
| `SMTP_*`, `NEXT_PUBLIC_SMTP_FROM` | Mailpit | See "Sending real emails" |

The viewer takes these values from the builder through references.

### Generated

| Service | Variable | Notes |
|---|---|---|
| typebot-builder | `ENCRYPTION_SECRET` | Encrypts credentials stored in bots (API keys, OpenAI keys). **Never change it after the first deploy** |
| mailpit | `MAILPIT_PASSWORD` | Password for the Mailpit page, user `admin` |
| typebot-builder | `SMTP_PASSWORD` | Password Typebot uses to send to Mailpit |

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | |
| `REDIS_URL` | `${{Redis.REDIS_URL}}?family=0` | `family=0` is needed for Railway's IPv6 private network |
| `NEXTAUTH_URL` | `https://${{typebot-builder.RAILWAY_PUBLIC_DOMAIN}}` | Must match the builder's public URL. Update it if you add a custom domain |
| `NEXT_PUBLIC_VIEWER_URL` | `https://${{typebot-viewer.RAILWAY_PUBLIC_DOMAIN}}` | Where bots run. Update it if you add a custom domain to the viewer |
| `S3_*` | `${{Bucket.*}}` | The start command removes `https://` from `S3_ENDPOINT`, because Typebot expects a host name |
| `S3_PUBLIC_CUSTOM_DOMAIN` | `https://${{files.RAILWAY_PUBLIC_DOMAIN}}` | Public URLs of uploaded files point to the `files` service |
| `RCLONE_S3_*`, `BUCKET` (files) | `${{Bucket.*}}` | Bucket access for the file server |

## Sending real emails

Mailpit catches every email; nothing reaches real inboxes. That is fine for signing in yourself. For invitations, results notifications and other people signing in, use a real SMTP provider. On `typebot-builder` set:

| Variable | Example (port 587, STARTTLS) | Example (port 465, TLS) |
|---|---|---|
| `SMTP_HOST` | `smtp.resend.com` | `smtp.gmail.com` |
| `SMTP_PORT` | `587` | `465` |
| `SMTP_SECURE` | `false` | `true` |
| `SMTP_IGNORE_TLS` | `false` | `false` |
| `SMTP_USERNAME` / `SMTP_PASSWORD` | from your provider | from your provider |
| `NEXT_PUBLIC_SMTP_FROM` | `Typebot <bot@yourdomain.com>` | |

The viewer picks them up through references. After that you can delete the `mailpit` service.

## Custom domains

Add the domain to the service in Railway, then update the URL variables on `typebot-builder`: `NEXTAUTH_URL` for the builder, `NEXT_PUBLIC_VIEWER_URL` for the viewer, `S3_PUBLIC_CUSTOM_DOMAIN` for `files`. Files uploaded before the change keep their old URLs, so keep the old Railway domains as well.

## Upgrading

Change the image tag of **both** `typebot-builder` and `typebot-viewer` to the same version. The builder runs database migrations on start. Read the [release notes](https://github.com/baptisteArno/typebot.io/releases) first.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| No sign-in email in Mailpit | Check `SMTP_*` on `typebot-builder` still point to Mailpit, and the `mailpit` logs |
| "Too many requests" when signing in | Typebot limits sign-in emails per address. Wait a few minutes |
| "Sign up disabled" | The email isn't in `ADMIN_EMAIL` and has no invitation. Add it to `ADMIN_EMAIL` or invite it from a workspace |
| Images in bots don't load | Check the `files` service is running and `S3_PUBLIC_CUSTOM_DOMAIN` points to its URL |
| `files` doesn't start | Its start command writes `public/healthz` to the bucket to check access. Check the `RCLONE_S3_*` variables |
| Viewer restarts once after the first deploy | It started before the builder finished the database migrations. It recovers on its own |
| "Failed to trigger onboarding email workflow" in builder logs | Typebot Cloud's onboarding emails; not used when self-hosting. Harmless |

## Testing

Tested on 2026-11-04 with test deploys, first of the template config and then of the template draft: all six services healthy. A sign-in link requested in the UI arrived in Mailpit, and the link signed in `ADMIN_EMAIL`. An image uploaded through the builder's upload API was readable at its public URL on the `files` service. `files` returned 404 for a folder listing and for `private/` paths, and Mailpit returned 401 without its password.
