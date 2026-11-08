# Deploy and Host Postiz on Railway

Postiz is an open-source social media scheduler, an alternative to Buffer and Hootsuite. Write a post once, schedule it for X, LinkedIn, Bluesky, Mastodon, Instagram, Facebook, TikTok, YouTube, Reddit, Threads, Pinterest, Discord, Telegram and 20+ more channels, and see it on a shared calendar with your team. It includes an AI writing assistant, a media library, analytics and a public API.

## About Hosting Postiz

Postiz runs a web app, an API and a background worker in one container. Scheduled posts are run by Temporal, a workflow engine with its own database; Postiz itself needs PostgreSQL and Redis, and a volume for uploaded media. On a fresh install anyone who opens the site can register and take over the instance, and Temporal's default setup adds sample search attributes that leave no room for the two Postiz needs, so the API fails to start.

This template runs the whole stack on Railway's private network: Postiz with the admin account created at deploy and public sign-up off, Temporal with its own PostgreSQL, PostgreSQL and Redis for Postiz, all on volumes, with pinned, tested versions.

## Common Use Cases

- Schedule posts to many social networks from one calendar
- Let a team or agency draft, review and publish posts for several brands
- Self-host a Buffer or Hootsuite alternative with no per-channel fees
- Automate posting from n8n, Make or your own code through the Postiz API
- Keep a library of images and videos for your posts

## Dependencies for Postiz Hosting

- PostgreSQL 17 (Postiz data) and a second PostgreSQL 17 for Temporal
- Redis 8
- Temporal 1.29 (runs scheduled posts)

### Deployment Dependencies

- Postiz: https://github.com/gitroomhq/postiz-app
- Postiz documentation: https://docs.postiz.com
- Connecting social channels: https://docs.postiz.com/providers
- Temporal: https://github.com/temporalio/temporal

### Implementation Details

**What you set:** `POSTIZ_ADMIN_EMAIL`, the email you log in with.

**After deploy:**

1. Wait until the Postiz logs show `admin-setup: admin ... created` (about 3 minutes on the first start).
2. Open the Postiz URL and log in with `POSTIZ_ADMIN_EMAIL` and the generated `POSTIZ_ADMIN_PASSWORD` variable.
3. Add channels. Each social network needs its own app keys (for example `X_API_KEY` and `X_API_SECRET`) set on the Postiz service; Bluesky, Mastodon, Telegram and a few others connect without them. See the Postiz provider docs.
4. To add teammates, set `DISABLE_REGISTRATION` to `false` while they create accounts from your invite, then set it back to `true`.

**This template:**

- Creates the admin account on first start and keeps public sign-up off, so a stranger can't claim the instance
- Makes the login work on the `*.up.railway.app` domain, where Postiz's default login cookie is rejected by browsers
- Runs Temporal on PostgreSQL with no Elasticsearch, and without the sample search attributes that block Postiz from starting
- Keeps PostgreSQL, Redis and Temporal private: only Postiz is public, and it requires a login
- Stores uploads on a volume, Postiz data in PostgreSQL and Redis on volumes, and workflow history in Temporal's PostgreSQL
- Generates `JWT_SECRET`, so redeploys don't log anyone out
- Pins Postiz v2.25.3, Temporal 1.29.7, PostgreSQL 17 and Redis 8.10, with a healthcheck on the Postiz API

**Notes:** Postiz uses about 1.5 GB of RAM; the whole stack fits the Hobby plan. Uploaded media stays on the Postiz volume; set `STORAGE_PROVIDER=cloudflare` and the `CLOUDFLARE_*` variables to use R2 instead. When you add a custom domain, change `MAIN_URL`, `FRONTEND_URL` and `NEXT_PUBLIC_BACKEND_URL` to it, and delete `NOT_SECURED` for httpOnly login cookies.

## Why Deploy Postiz on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Postiz on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
