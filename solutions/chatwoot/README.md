# Chatwoot

Self-hosted [Chatwoot](https://github.com/chatwoot/chatwoot) on Railway: an open-source customer support inbox for website live chat, email, WhatsApp, Instagram, Facebook, Telegram and API channels. The admin account is created at deploy, the public first-run setup page is closed, sign-up is off, and PostgreSQL and Redis are reachable only over the private network. Versions are pinned and tested.

## Architecture

```
            Agents (dashboard)        Website visitors (chat widget)
                     │ HTTPS                  │ HTTPS
                     ▼                        ▼
┌───────────────────────────────────────────────────────────┐
│ Railway project                                           │
│                                                           │
│  Chatwoot :3000 (public, login required for the dashboard)│
│    Rails web server + Sidekiq worker in one service       │
│    volume /app/storage (attachments)                      │
│        │                          │                       │
│        ▼                          ▼                       │
│  Postgres :5432 (private)    Redis :6379 (private)        │
│    pgvector, all data          jobs, live updates, cache  │
│    volume                      volume                     │
└───────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Chatwoot | `chatwoot/chatwoot:v4.19.1-ce` | Dashboard, API, chat widget and background jobs (public, login required) |
| Postgres | `pgvector/pgvector:0.8.7-pg16` | Conversations, contacts, accounts, settings (private) |
| Redis | `redis:8.2.11-alpine` | Sidekiq queues, live updates, cache (private) |

## What this template does differently

- **No one can claim your instance.** A fresh Chatwoot opens `/installation/onboarding`, where the first visitor creates the super admin. This template creates the admin from `ADMIN_EMAIL` and a generated `ADMIN_PASSWORD` on the first start, and closes that page on every start.
- **Sign-up is off.** The public account sign-up API returns 404; agents join only when you invite them.
- **Database prepared on every start.** The schema is loaded on the first start, and migrations run automatically after an image upgrade, so there is no manual `rails db:chatwoot_prepare` step.
- **One service for web and worker.** Railway volumes belong to one service. If Rails and Sidekiq run as separate services with local storage, files the worker saves (email and messaging attachments) end up on a volume the web server can't read. Here both processes run in the Chatwoot service and share `/app/storage`. If either process stops, the container exits and Railway restarts it.
- **Private database and Redis.** Neither has a public domain or TCP proxy.
- **Generated secrets.** `SECRET_KEY_BASE` and the three Active Record encryption keys (needed for two-factor sign-in) are generated at deploy.
- **Pinned versions and a healthcheck** on `/api`, which also reports whether Postgres and Redis are reachable.

## After deploy

1. Open the Chatwoot URL and sign in with `ADMIN_EMAIL` and the `ADMIN_PASSWORD` variable (Chatwoot service → Variables).
2. Add an inbox under **Settings → Inboxes**. For website chat, choose **Website**, then paste the script it shows into your site.
3. Invite agents under **Settings → Agents**. Invitations are sent by email, so add SMTP variables first (below). Without email, set an agent's password in the super admin console at `/super_admin` (sign in with the admin account).
4. Change your password under **Profile settings**, and turn on two-factor sign-in there if you want it.

## Email (optional)

Chatwoot sends invitations, password resets and notifications by email. Add these variables to the Chatwoot service and redeploy:

| Variable | Example |
|---|---|
| `MAILER_SENDER_EMAIL` | `Support <support@yourdomain.com>` |
| `SMTP_ADDRESS` | `smtp.resend.com` |
| `SMTP_PORT` | `587` |
| `SMTP_USERNAME` | provider user |
| `SMTP_PASSWORD` | provider password or API key |
| `SMTP_AUTHENTICATION` | `login` |
| `SMTP_ENABLE_STARTTLS_AUTO` | `true` |
| `SMTP_DOMAIN` | `yourdomain.com` |

Without `SMTP_ADDRESS`, everything else works, but emails are not sent. Incoming email (email inboxes) also needs IMAP or an inbound provider; see [Chatwoot's environment variable docs](https://developers.chatwoot.com/self-hosted/configuration/environment-variables).

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Chatwoot | `ADMIN_EMAIL` | (required) | Email of the admin account. You sign in with it |
| Chatwoot | `ADMIN_PASSWORD` | generated | Read it after deploy. Applied only when the admin is created on the first start |
| Chatwoot | `ADMIN_NAME` | `Admin` | Display name of the admin |
| Chatwoot | `ACCOUNT_NAME` | `My Company` | Name of the first Chatwoot account |
| Chatwoot | `FRONTEND_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL used in links, emails and the widget script. Change it when you add a custom domain |
| Chatwoot | `DEFAULT_LOCALE` | `en` | Default language |
| Chatwoot | `RAILS_MAX_THREADS` | `5` | Web server threads |
| Chatwoot | `SIDEKIQ_CONCURRENCY` | `10` | Background job threads |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Chatwoot | `SECRET_KEY_BASE` | generated | Signs sessions. Changing it logs everyone out |
| Chatwoot | `ACTIVE_RECORD_ENCRYPTION_*` | generated | Encrypts two-factor secrets. Changing them breaks two-factor sign-in |
| Chatwoot | `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USERNAME`, `POSTGRES_PASSWORD`, `POSTGRES_DATABASE` | from the Postgres service | Private network |
| Chatwoot | `REDIS_URL` | `redis://default:...@${{Redis.RAILWAY_PRIVATE_DOMAIN}}:6379` | Private network |
| Chatwoot | `ACTIVE_STORAGE_SERVICE` | `local` | Attachments on the service's volume. To use S3 instead, see [Chatwoot's storage docs](https://developers.chatwoot.com/self-hosted/deployment/storage/s3-bucket) |
| Chatwoot | `RAILS_ENV`, `NODE_ENV`, `INSTALLATION_ENV`, `RAILS_LOG_TO_STDOUT`, `LOG_LEVEL`, `PORT` | | Production mode, logs to Railway, port 3000 |
| Chatwoot | `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` | `30` | Lets Sidekiq finish running jobs on redeploy |
| Chatwoot | `CHATWOOT_RUN_SH` | script | Start script: prepares the database, creates the admin, closes the setup page, runs Sidekiq and Rails |
| Postgres | `POSTGRES_PASSWORD` | generated | Database password |
| Redis | `REDIS_PASSWORD` | generated | Redis password |

## Upgrading

Change the Chatwoot image tag (for example `chatwoot/chatwoot:v4.20.0-ce`) and redeploy. Migrations run on start. Read the [release notes](https://github.com/chatwoot/chatwoot/releases) first, and back up Postgres before a major version. To use the Enterprise Edition image (free features plus paid ones with a license), drop the `-ce` suffix.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Deploy fails with `ADMIN_EMAIL and ADMIN_PASSWORD must be set` | The admin is created on the first start. Set both variables and redeploy |
| Deploy fails while creating the admin with a password error | Chatwoot requires an uppercase letter, a lowercase letter, a number and a special character. The generated password has all four; a password you set must too |
| Sign-in fails with the generated password | The admin is created on the first start only. If you changed `ADMIN_PASSWORD` or `ADMIN_EMAIL` later, use the old values, or reset the password in `/super_admin` |
| Invitations and password resets never arrive | No SMTP settings. See **Email** above |
| Widget script points to the wrong address | `FRONTEND_URL` still has the Railway domain. Set it to your custom domain and redeploy |
| Everyone is logged out after a redeploy | `SECRET_KEY_BASE` was changed or removed |

## License

Chatwoot Community Edition is [MIT](https://github.com/chatwoot/chatwoot/blob/develop/LICENSE). The Enterprise Edition image adds code under Chatwoot's enterprise license.

## Testing

Tested on 2026-11-07 with Chatwoot v4.19.1 (Community Edition) in a throwaway Railway project. All three services were healthy about a minute after deploy, and the admin account was created on the first start. API requests without a login, a wrong password, a stranger's sign-up and the first-run setup page were refused, and Postgres and Redis had no public endpoint. The admin signed in, created a website inbox, and a visitor message sent through the chat widget API appeared in the agent's conversation list. An agent reply with an image attachment was delivered, Sidekiq ran the related jobs (including attachment analysis) and the attachment downloaded from its public URL. After redeploying all three services, the admin was left unchanged, the setup page stayed closed, and the conversation and attachment were still there. Not tested: the browser dashboard (only its API), email, and messaging channels other than the website widget.
