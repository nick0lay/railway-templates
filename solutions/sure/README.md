# Sure

Self-hosted [Sure](https://github.com/we-promise/sure) on Railway: an open-source personal finance and budgeting app, the community successor of Maybe Finance. This template creates your owner account at deploy and keeps sign-ups closed, and runs the official image at a pinned version with a separate Sidekiq worker, Postgres and Redis on volumes, uploads in a Railway Bucket, and one set of generated secrets shared by web and worker.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/sure-076?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
                         You / your household
                               │ HTTPS
                               ▼
┌──────────────────────────────────────────────────────────────┐
│ Railway project                                              │
│                                                              │
│  Sure :3000 (public)               Sure Worker (private)     │
│    web app, login, /up healthcheck   Sidekiq: syncs, imports,│
│    migrates the database on start    rates, prices, AI jobs  │
│        │        │        │             │        │        │   │
│        ▼        ▼        ▼             ▼        ▼        ▼   │
│  Postgres :5432        Redis :6379          Bucket (S3)      │
│  (private, volume)     (private, volume)    receipts, files, │
│  accounts, entries     job queues, cache    imports, exports │
└──────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Sure | `ghcr.io/we-promise/sure:0.7.6-hotfix.1` | Web app (public). Runs `rails db:prepare` on every start, healthcheck `/up` |
| Sure Worker | `ghcr.io/we-promise/sure:0.7.6-hotfix.1` | Sidekiq background jobs: account syncs, imports, exchange rates and prices, scheduled jobs (private) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | All finance data (private, volume) |
| Redis | `redis:8.12` | Sidekiq queues and cache, `noeviction` and append-only file on a volume (private) |
| Bucket | Railway Bucket | Uploaded files (receipts, statements, imports, exports), shared by web and worker |

## What this template does differently

- **Owner account created at deploy, sign-ups closed.** On a fresh Sure install, whoever opens the URL first signs up and becomes the super admin. This template creates the owner (super admin) on first start from `OWNER_EMAIL` and a generated `OWNER_PASSWORD`, and sets `ONBOARDING_STATE=closed`, so nobody else can register. The setup step runs on every start but does nothing once a user exists.
- **Background worker included.** Sure needs Sidekiq for account syncs, imports, exchange rates and scheduled jobs. Without it, uploads and syncs sit in the queue forever.
- **One set of secrets for web and worker.** `SECRET_KEY_BASE` and the three `ACTIVE_RECORD_ENCRYPTION_*` keys are generated once on `Sure`, and the worker reads them from there. If the worker had different keys, it couldn't read the API keys and tokens the web app encrypted.
- **Pinned version.** Sure 0.7.6-hotfix.1 (the current `stable`), Postgres 18 and Redis 8.12 instead of `latest`. Sure migrates the database on start, so you upgrade when you choose.
- **Uploads in a Railway Bucket.** Railway volumes can't be shared between services, so files go to a bucket that both the web app and the worker can reach. Receipts and imports survive redeploys.
- **Private databases.** Postgres and Redis have volumes and no public TCP proxy; Redis has a generated password.
- **HTTPS behind Railway's proxy.** `RAILS_FORCE_SSL` and `RAILS_ASSUME_SSL` are on, so cookies are secure and plain HTTP redirects to HTTPS.
- **Healthcheck and restart policy.** Railway waits for `/up` before it switches traffic, and restarts a crashed service.
- **Registration control.** Open sign-ups later with `ONBOARDING_STATE` or in the app; see "After deploy".
- **Privacy defaults.** Sure's anonymous product-improvement monitoring is off (`POSTHOG_FEEDBACK_ENABLED=false`). Exchange rates and stock prices use Yahoo Finance, which needs no API key.

## After deploy

1. Open the `Sure` URL and log in with `OWNER_EMAIL` and the `OWNER_PASSWORD` variable from the `Sure` service. Change the password under **Settings → Security** if you like.
2. Finish the short onboarding (name, household, currency, goals).
3. Sign-ups are closed. To let family members join, switch **Settings → Self-Hosting → Onboarding** to **Invite-only** and invite them from your household settings (invitation emails need SMTP), or choose **Open** to let anyone register. The `ONBOARDING_STATE` variable is only the default: once you save the setting in the app, the app's value wins.
4. Add accounts and transactions by hand, or import CSV files under **Imports**.
5. Optional: add an OpenAI key (variable or **Settings → Self-Hosting**) for the AI assistant and auto-categorisation, and SMTP for password reset and invitation emails.

The Sidekiq dashboard is at `/sidekiq`. Only the super admin can open it; everyone else gets a 404.

## Variables

### User-configurable

| Variable | Default | Notes |
|---|---|---|
| `OWNER_EMAIL` | `admin@example.com` | Email of the owner (super admin) account created on first start. Set your own before deploying |
| `OWNER_PASSWORD` | generated | Read it after deploy. Used only when the owner is created; later changes have no effect |
| `ONBOARDING_STATE` | `closed` | `closed`, `invite_only` or `open`. Default for who can sign up; the app setting wins once saved |
| `OPENAI_ACCESS_TOKEN` | empty | Optional. Enables the AI assistant, AI rules and auto-categorisation. Usage costs money; set a spend limit with your provider |
| `OPENAI_MODEL`, `OPENAI_URI_BASE` | empty | Optional. Model name, or an OpenAI-compatible endpoint (OpenRouter, a self-hosted model) |
| `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_TLS_ENABLED`, `EMAIL_SENDER` | empty, `465`, `true` | Optional. Needed for password reset, invitations and email reports |
| `EXCHANGE_RATE_PROVIDER`, `SECURITIES_PROVIDER` | `yahoo_finance` | Or `twelve_data` with `TWELVE_DATA_API_KEY` |
| `POSTHOG_FEEDBACK_ENABLED` | `false` | Set `true` to send Sure's anonymous product-improvement monitoring |

Set these on `Sure`; the worker reads them from there. Sure supports more options (Anthropic, OIDC login, passkeys, bank connections); see the upstream [`.env.example`](https://github.com/we-promise/sure/blob/main/.env.example). Add them to both `Sure` and `Sure Worker`.

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `SECRET_KEY_BASE` | generated | Signs sessions. **Never change it after the first deploy** |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `..._DETERMINISTIC_KEY`, `..._KEY_DERIVATION_SALT` | generated | Encrypt stored API keys and tokens. **Never change them after the first deploy**, or encrypted data becomes unreadable |
| `SURE_OWNER_SETUP_RB` | script | Run by the start command (`rails runner`) to create the owner while no user exists. Later starts log `owner-setup: skipped: users already exist` |
| `SELF_HOSTED` | `true` | Self-hosted mode (no billing) |
| `DB_HOST`, `DB_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` | `${{Postgres.*}}` | Private network |
| `REDIS_URL` | `${{Redis.REDIS_URL}}/1` | Private network, database 1 as upstream uses |
| `ACTIVE_STORAGE_SERVICE`, `GENERIC_S3_*` | `generic_s3`, `${{Bucket.*}}` | Uploads in the Railway Bucket |
| `RAILS_FORCE_SSL`, `RAILS_ASSUME_SSL` | `true` | Railway's proxy terminates TLS |
| `APP_DOMAIN` | `${{RAILWAY_PUBLIC_DOMAIN}}` | Host in email links. Change it if you add a custom domain |
| `PORT` | `3000` | |

The worker's secrets are references to `Sure` (`${{Sure.SECRET_KEY_BASE}}` and so on), so both always match.

## Custom domain

Add the domain to the `Sure` service, then set `APP_DOMAIN=your-domain` on `Sure`. The worker reads it from there.

## Upgrading

Change the image tag on both `Sure` and `Sure Worker` to the same version (see [releases](https://github.com/we-promise/sure/releases); use the version tags, not the `-alpha` ones). `Sure` migrates the database on start. Take a Postgres backup first (Railway's volume backups, or `pg_dump`); a migrated database can't go back to an older version.

## Backups

Your data is in Postgres and the Bucket. Turn on volume backups for the Postgres service in Railway, and download a data export from Sure's settings now and then. Bucket files are not in the Postgres backup.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Login fails with the generated password | The owner is created on the first start only. If you changed `OWNER_EMAIL` or `OWNER_PASSWORD` later, use the old values. Check the `Sure` logs for `owner-setup:` |
| Family members can't sign up | Sign-ups are closed by default. Switch to Invite-only or Open in **Settings → Self-Hosting** |
| Imports, syncs or exchange rates never finish | `Sure Worker` isn't running or uses another image tag than `Sure`. Check its logs for `class=SyncJob ... done` |
| "ActiveRecord::Encryption::Errors::Decryption" in logs | A secret was changed after the first deploy. Restore the old `SECRET_KEY_BASE` / `ACTIVE_RECORD_ENCRYPTION_*` values |
| Redirect loop or "too many redirects" behind another proxy | Keep `RAILS_ASSUME_SSL=true` and make sure the proxy sends HTTPS |
| Password reset emails don't arrive | Set the SMTP variables and `EMAIL_SENDER` |
| Yahoo Finance prices missing | Yahoo rate-limits shared IPs at times; switch to `twelve_data` with an API key |

## License

Sure is licensed under the [GNU Affero General Public License v3.0](https://github.com/we-promise/sure/blob/main/LICENSE) (AGPL-3.0). If you modify Sure and let others use it over a network, you must offer them your modified source code. Sure is a fork of Maybe Finance and is not affiliated with or endorsed by Maybe Finance, Inc.; "Maybe" is a trademark of Maybe Finance, Inc. You are responsible for how you run the instance and for the financial data you store in it.

## Testing

Tested on 2026-11-18 with Sure 0.7.6-hotfix.1, deployed from the template draft into throwaway Railway projects: all four services healthy, the database migrated on first start, `/up` healthy and plain HTTP redirected to HTTPS. Web and worker had the same secrets; the worker, Postgres and Redis had no public domain or TCP proxy.

The owner was created as super admin on first start (`owner-setup: created super admin`). Logged out, every page redirected to the login page and `/sidekiq` returned 404. The sign-up page redirected to the login page, and a sign-up request with a valid CSRF token created no account. A wrong password was refused. The owner logged in with the generated password, finished onboarding and, as super admin, opened the Sidekiq dashboard. A cash account and an expense transaction were created through the web forms and listed on the Accounts and Transactions pages. A receipt image attached to the transaction was stored in the Bucket and downloaded back byte for byte. The worker processed the account's `SyncJob`.

After redeploying Sure, Postgres and Redis, the setup step skipped itself (`owner-setup: skipped: users already exist`), the owner logged in with the same password, and the account, the transaction and the receipt were still there. The worker reconnected to Redis and went on processing jobs.

Not tested: OpenAI features, SMTP and invitations, bank connections and market data providers.
