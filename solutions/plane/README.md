# Plane

Self-hosted [Plane](https://github.com/makeplane/plane) on Railway: open-source project management, an alternative to Jira and Linear. The instance admin is created for you at deploy and public sign-up is off, so nobody else can claim your instance. Data lives in Postgres, attachments in a Railway Bucket, and the version is pinned and tested.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/plane-2?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
                     You / your team / API clients
                               │ HTTPS
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│ Railway project                                                  │
│                                                                  │
│  Plane :80 (public), official all-in-one image                   │
│    built-in proxy: web app /, admin /god-mode, spaces /spaces,   │
│    API /api and /auth, real-time /live                           │
│    plus background worker, scheduler and migrations              │
│        │               │                 │            │          │
│        ▼               ▼                 ▼            ▼          │
│  Postgres :5432   Redis :6379     RabbitMQ :5672   Bucket (S3)   │
│  (private,        (private,       (private)        attachments   │
│   volume)          volume)        job queue                      │
└──────────────────────────────────────────────────────────────────┘
         Browsers upload and download attachments from the
         Bucket directly, with signed URLs from the API
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Plane | `makeplane/plane-aio-community:v1.4.3` | Web app, admin panel, spaces, API, worker, scheduler, real-time server and proxy in one container (public). Migrates the database on start |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Workspaces, projects, work items, users (private) |
| Redis | `redis:8.10` | Cache, append-only file on a volume (private) |
| RabbitMQ | `rabbitmq:3.13.7-alpine` | Queue for background jobs: activity history, notifications, emails, webhooks (private) |
| Bucket | Railway Bucket | Attachments, images and exports |

## What this template does differently

- **Instance admin created at deploy.** On a fresh Plane install, whoever opens `/god-mode` first becomes the instance admin. This template creates the admin on first start with your `ADMIN_EMAIL` and a generated `ADMIN_PASSWORD`, so the setup screen is closed before you open the URL.
- **Public sign-up off.** Only people invited to a workspace can create an account. You can turn sign-up on in the admin panel.
- **One app service.** Plane's official all-in-one image runs every Plane process behind its own proxy, so you get one public URL with no path routing to set up and one image tag to upgrade.
- **Attachments in a Railway Bucket**, with no MinIO to run. Browsers upload straight to the Bucket with signed URLs.
- **Pinned versions.** Plane 1.4.3, Postgres 18, Redis 8.10 and RabbitMQ 3.13.7 (the RabbitMQ line Plane's own compose file uses) instead of `stable` or `latest`.
- **Secrets generated.** `SECRET_KEY` and `LIVE_SERVER_SECRET_KEY` are generated once, so sessions survive redeploys.
- **Logs in Railway.** Plane's processes write to log files inside the container; the start command streams the error logs and the worker log to the Railway log view.
- **Private networking** for Postgres, Redis and RabbitMQ; healthcheck on `/api/instances/`.

## After deploy

1. Open the Plane URL and log in with `ADMIN_EMAIL` and the `ADMIN_PASSWORD` variable.
2. Create your workspace, then your first project.
3. Invite your team in the workspace settings under **Members**. Invited people can sign up with the invited email even though public sign-up is off. Without email set up, tell them to open the Plane URL and sign up with that email.
4. Manage the instance in the admin panel at `/god-mode` (log in with the same admin account): sign-up and login methods under **Authentication**, SMTP under **Email**, workspace creation under **Workspace**.
5. For integrations, create a token in your profile settings under **Developer → Personal Access Tokens** (`/settings/profile/api-tokens`).

## Variables

### User-configurable

| Variable | Default | Notes |
|---|---|---|
| `ADMIN_EMAIL` | (required) | Email of the instance admin. You log in with it |
| `ADMIN_PASSWORD` | generated | Read it after deploy. It's applied only when the admin is created on first start |
| `INSTANCE_NAME` | `Plane` | Instance name shown in the admin panel |
| `ENABLE_SIGNUP` | `0` | Public sign-up. Used on the first start only; later, change it in the admin panel under Authentication |
| `FILE_SIZE_LIMIT` | `5242880` | Largest upload in bytes (5 MB) |

SMTP, Google, GitHub and GitLab login are set up in the admin panel, not with variables.

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `SECRET_KEY`, `LIVE_SERVER_SECRET_KEY` | generated | Sign sessions and real-time connections. **Don't change them after the first deploy** |
| `PLANE_SETUP_PY` | script | Run by the start command to create the instance admin on first start. Later starts log `admin-setup: skipped, instance admin already exists` |
| `DOMAIN_NAME` | `${{RAILWAY_PUBLIC_DOMAIN}}` | Plane builds its URLs from it. Change it if you add a custom domain |
| `APP_PROTOCOL` | `https` | Railway serves the domain over HTTPS |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Private network |
| `REDIS_URL` | `${{Redis.REDIS_URL}}` | Private network |
| `AMQP_URL` | `amqp://...@${{RabbitMQ.RAILWAY_PRIVATE_DOMAIN}}:5672/plane` | Private network, credentials from the RabbitMQ service |
| `AWS_S3_ENDPOINT_URL`, `AWS_REGION`, `AWS_S3_BUCKET_NAME`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | `${{Bucket.*}}` | Attachments in the Railway Bucket |
| `PORT`, `SITE_ADDRESS` | `80`, `:80` | Plane's built-in proxy |
| `TERM` | `xterm` | The image's start script clears the terminal and needs a terminal type |

## Custom domain

Add the domain to the `Plane` service, then set `DOMAIN_NAME=your-domain` (without `https://`) and redeploy.

## Upgrading

Change the image tag of the `Plane` service (for example `makeplane/plane-aio-community:v1.5.0`). Plane migrates the database on start and can't go back to an older version after that. Read the [release notes](https://github.com/makeplane/plane/releases) first, and back up Postgres before a major upgrade.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| The first deploy takes several minutes | Plane migrates the database on the first start; the healthcheck passes when the API answers |
| Login fails with the generated password | The admin is created on the first start only. If you changed `ADMIN_PASSWORD` or `ADMIN_EMAIL` later, use the old values |
| `/god-mode` shows the admin setup screen | The admin wasn't created. Check the `Plane` logs for `admin-setup:` |
| "Sign up is disabled" for a teammate | Expected: invite their email to a workspace first, or turn sign-up on in the admin panel |
| Uploads fail | Check that the `AWS_*` variables still point to the Bucket, and that the file is under `FILE_SIZE_LIMIT` |
| Links in emails point to the wrong host | `DOMAIN_NAME` doesn't match your domain |
| Activity history or notifications don't appear | Background jobs aren't running. Check that RabbitMQ is running and look for `celery@` in the `Plane` logs |

## Testing

Tested on 2026-11-05 with Plane 1.4.3 in a throwaway Railway project, from the config: all four services healthy, and the instance admin was created at first start (`admin-setup: HTTP 302 instance admin created`). The web app and the admin panel loaded. The API refused requests without a login, a stranger's attempt to claim the instance admin was refused (`ADMIN_ALREADY_EXIST`), a stranger's sign-up was refused (`SIGNUP_DISABLED`) and a wrong password was refused. The admin logged in to the app and to the admin panel, created a workspace, a project and a work item, and attached a file: the file was uploaded to the Bucket with a signed URL and read back, and the Bucket answered a browser CORS preflight. An invited teammate signed up and logged in. The worker wrote the work item's activity history. After redeploying all services, the logins, the work item and the attachment were still there, the setup step skipped itself, and the worker processed new jobs. On 2026-11-06 the template draft was deployed and tested in a browser: the admin logged in, went through onboarding, and attached a PNG and a PDF to a work item; both were stored in the Bucket and downloaded back.
