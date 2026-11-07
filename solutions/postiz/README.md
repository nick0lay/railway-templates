# Postiz

Self-hosted [Postiz](https://github.com/gitroomhq/postiz-app) on Railway: an open-source social media scheduler (Buffer and Hootsuite alternative) for X, LinkedIn, Bluesky, Mastodon, Instagram, Facebook, TikTok, YouTube, Reddit, Threads and 20+ more channels. The admin account is created at deploy, public sign-up is off, and Temporal, which runs scheduled posts, comes with its own database. Only Postiz is public. Versions are pinned and tested.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/postiz-1?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
                       You / your team
                         │ HTTPS
                         ▼
┌──────────────────────────────────────────────────────────────┐
│ Railway project                                              │
│                                                              │
│  Postiz :5000 (public, login required)                       │
│    nginx → web app :4200, API :3000, orchestrator (worker)   │
│    volume /uploads (media)                                   │
│       │                 │                    │               │
│       ▼                 ▼                    ▼               │
│  Postgres :5432     Redis :6379        Temporal :7233        │
│  (private)          (private)          (private)             │
│  posts, users,      cache, throttling  scheduled-post        │
│  channels           volume /data       workflows             │
│  volume                                    │                 │
│                                            ▼                 │
│                                       Temporal DB :5432      │
│                                       (private, volume)      │
└──────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Postiz | `ghcr.io/gitroomhq/postiz-app:v2.25.3` | Web app, API and orchestrator worker in one container (public, login required) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:17` | Postiz database (private) |
| Redis | `redis:8.10` | Cache and rate limits, append-only file on a volume (private) |
| Temporal | `temporalio/auto-setup:1.29.7` | Workflow engine that runs scheduled posts; creates its schema on first start (private) |
| Temporal DB | `ghcr.io/railwayapp-templates/postgres-ssl:17` | Temporal persistence and workflow search (private) |

## What this template does differently

- **Admin account created at deploy.** On a fresh Postiz, anyone who opens the site can register. This template creates the admin from `POSTIZ_ADMIN_EMAIL` and a generated `POSTIZ_ADMIN_PASSWORD` within seconds of the API starting, and keeps `DISABLE_REGISTRATION=true`, so nobody else can sign up.
- **Login works on the Railway domain.** Postiz scopes its login cookie to the parent domain, which is `railway.app` for a `*.up.railway.app` address, and browsers reject it: you submit the login form and stay on the login page. This template sets `NOT_SECURED=true`, so the browser stores the login for your exact domain instead. After you move to a custom domain, delete `NOT_SECURED` to get httpOnly login cookies.
- **Temporal without Elasticsearch.** Workflow search runs on Temporal's PostgreSQL, so there's no 1–4 GB Elasticsearch service to pay for. Temporal's setup normally adds sample search attributes; on PostgreSQL that uses up the text-attribute slots and the Postiz API fails with `cannot have more than 3 search attribute of type Text`. This template turns them off (`SKIP_ADD_CUSTOM_SEARCH_ATTRIBUTES=true`).
- **Nothing private is public.** Temporal has no login of its own, so neither Temporal nor its UI gets a public domain. Postgres, Redis and Temporal are reachable only over the private network.
- **Data persists.** Uploads on the Postiz volume, Postiz data in Postgres, Redis with an append-only file, and workflow history in Temporal DB, all on volumes. `JWT_SECRET` is generated, so redeploys don't log anyone out.
- **Pinned versions and a healthcheck** on the Postiz API (`/` on port 3000).

## After deploy

1. Wait until the Postiz logs show `admin-setup: admin ... created` (about 2–3 minutes on the first start).
2. Open the Postiz URL and log in with `POSTIZ_ADMIN_EMAIL` and the `POSTIZ_ADMIN_PASSWORD` variable.
3. Add channels. Most networks need you to create an app with them and set its keys on the Postiz service (for example `X_API_KEY` and `X_API_SECRET`, `LINKEDIN_CLIENT_ID` and `LINKEDIN_CLIENT_SECRET`), then redeploy Postiz. Use `https://<your domain>/integrations/social/<provider>` as the callback URL. Bluesky, Mastodon, Telegram and a few others connect without app keys. See [the Postiz provider docs](https://docs.postiz.com/providers).
4. To add teammates, set `DISABLE_REGISTRATION=false`, send invites from **Settings → Team**, and set it back to `true` once they have joined.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Postiz | `POSTIZ_ADMIN_EMAIL` | (required) | Email of the admin account. You log in with it |
| Postiz | `POSTIZ_ADMIN_PASSWORD` | generated | Read it after deploy. Applied only when the admin is created on first start |
| Postiz | `POSTIZ_ADMIN_COMPANY` | `My Company` | Name of the admin's workspace |
| Postiz | `DISABLE_REGISTRATION` | `true` | Set to `false` only while invited teammates sign up |
| Postiz | `MAIN_URL`, `FRONTEND_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Change both when you add a custom domain |
| Postiz | `NEXT_PUBLIC_BACKEND_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}/api` | Change it with the two above |
| Postiz | `NOT_SECURED` | `true` | Needed on `*.up.railway.app`. Delete it after you switch to a custom domain (and update the three URLs above) |
| Postiz | `STORAGE_PROVIDER` | `local` | `cloudflare` stores media in R2; then set the `CLOUDFLARE_*` variables from the Postiz docs |
| Postiz | Channel keys | (unset) | `X_API_KEY`, `LINKEDIN_CLIENT_ID`, `OPENAI_API_KEY` (AI assistant) and others from the [Postiz configuration reference](https://docs.postiz.com/configuration/reference) |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Postiz | `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Private network |
| Postiz | `REDIS_URL` | `redis://default:${{Redis.REDIS_PASSWORD}}@${{Redis.RAILWAY_PRIVATE_DOMAIN}}:6379` | Private network |
| Postiz | `TEMPORAL_ADDRESS` | `${{Temporal.RAILWAY_PRIVATE_DOMAIN}}:7233` | Private network |
| Postiz | `JWT_SECRET` | generated | Signs logins. Changing it logs everyone out |
| Postiz | `PORT` | `3000` | The API's port; the healthcheck uses it. The public domain points to nginx on 5000 |
| Postiz | `BACKEND_INTERNAL_URL` | `http://localhost:3000` | API address inside the container |
| Postiz | `UPLOAD_DIRECTORY`, `NEXT_PUBLIC_UPLOAD_DIRECTORY` | `/uploads` | The volume |
| Postiz | `IS_GENERAL`, `RUN_CRON`, `NX_ADD_PLUGINS` | | Upstream defaults |
| Postiz | `POSTIZ_SETUP_SH` | script | Creates the admin on first start |
| Temporal | `DB`, `DB_PORT`, `POSTGRES_SEEDS`, `POSTGRES_USER`, `POSTGRES_PWD` | Temporal DB | Persistence |
| Temporal | `ENABLE_ES` | `false` | Search on PostgreSQL |
| Temporal | `SKIP_ADD_CUSTOM_SEARCH_ATTRIBUTES` | `true` | Leaves room for the attributes Postiz registers |
| Temporal | `BIND_ON_IP`, `TEMPORAL_BROADCAST_ADDRESS`, `TEMPORAL_ADDRESS` | | Single-node server on the private network |

## Hardware and cost

Postiz runs three Node.js processes and uses about 1.5 GB of RAM at idle; Temporal about 200 MB; each Postgres and Redis under 100 MB. The stack fits the Hobby plan. Usage is billed by Railway for what the services use.

## Upgrading

Change the Postiz image tag (for example `ghcr.io/gitroomhq/postiz-app:v2.26.0`) and redeploy. Postiz updates its database schema on start. Read the [release notes](https://github.com/gitroomhq/postiz-app/releases) first. Keep Temporal on `auto-setup:1.29.x`; it is the last line of that image.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Postiz logs `Backend failed to start` with `cannot have more than 3 search attribute of type Text` | Temporal added its sample search attributes. Set `SKIP_ADD_CUSTOM_SEARCH_ATTRIBUTES=true` on Temporal; on an existing Temporal DB, also remove them with `temporal operator search-attribute remove` |
| After signing in you stay on the login page | `NOT_SECURED` was removed while Postiz still runs on a `*.up.railway.app` domain. Set it back to `true`, or use a custom domain |
| Login fails with the generated password | The admin is created on the first start only. If you changed `POSTIZ_ADMIN_PASSWORD` or `POSTIZ_ADMIN_EMAIL` later, use the old values |
| `admin-setup: ... skipped` and you can't log in | An account was created before the admin, for example with `DISABLE_REGISTRATION=false`. Log in with that account |
| Invited teammates see "Registration is disabled" | Set `DISABLE_REGISTRATION=false` while they sign up |
| Connecting a channel fails | That network's app keys are missing or the callback URL in the app doesn't match your domain |
| Everyone is logged out after a redeploy | `JWT_SECRET` was changed or removed |

## License

Postiz is [AGPL-3.0](https://github.com/gitroomhq/postiz-app/blob/main/LICENSE). Temporal is [MIT](https://github.com/temporalio/temporal/blob/main/LICENSE).

## Testing

Tested on 2026-11-07 with Postiz v2.25.3 and Temporal 1.29.7 in throwaway Railway projects. All five services were healthy, and the admin was created 2 seconds after the API started. Only Postiz had a public domain. Requests without a login got 401, a stranger's registration was refused ("Registration is disabled"), a wrong password was refused, and the admin logged in through the API and in a browser, staying logged in after a reload. An image upload was stored and served from `/uploads`. A post scheduled 75 seconds ahead for a channel with a fake token was picked up by Temporal at its time and ended as an error with a notification, which shows the worker runs scheduled posts. After redeploying all five services, the login, the post, the media entry and the uploaded file were all still there. Without `NOT_SECURED`, the browser login stayed on the login page because the cookie was set for `railway.app`. With Temporal's sample search attributes left on, the API failed to start. Not tested: posting to real social networks, the AI assistant, team invites and custom domains.
