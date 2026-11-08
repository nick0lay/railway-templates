# NocoDB

Self-hosted [NocoDB](https://github.com/nocodb/nocodb) on Railway: an open-source Airtable alternative that turns a database into a collaborative spreadsheet with grid, kanban, gallery and form views, plus a REST API. This template runs the official NocoDB image with PostgreSQL for its data and a Railway Bucket for file attachments. The admin account is created at deploy, sign-up is invite-only, and the version is pinned and tested.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/nocodb-minio-console-and-storage?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
                 You and your team (browser, API)
                              │ HTTPS
                              ▼
┌───────────────────────────────────────────────────────────────┐
│ Railway project                                               │
│                                                               │
│  NocoDB :8080 (public, login required)                        │
│      │                                  │ S3 API              │
│      ▼                                  ▼                     │
│  Postgres :5432 (private)          Bucket (Railway Bucket)    │
│    bases, tables, users,             attachments, private;    │
│    settings; volume                  browsers get signed links│
└───────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| NocoDB | `nocodb/nocodb:2026.10.1` | Spreadsheet UI and API (public, login required) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:17` | NocoDB's metadata and your tables (private) |
| Bucket | Railway Bucket | File attachments (private) |

## What this template does

- **Admin at deploy.** NocoDB creates the super admin from `NC_ADMIN_EMAIL` and the generated `NC_ADMIN_PASSWORD` on first start, so nobody else can claim the instance.
- **Invite-only sign-up.** A small start-up script logs in as the admin and turns on NocoDB's "invite only" sign-up setting. Strangers get "Not allowed to signup"; people you invite can join. You can change this later in Account settings.
- **Attachments in a Railway Bucket.** Uploads go through NocoDB into the bucket. The bucket is private; NocoDB gives browsers signed links that expire (`NC_ATTACHMENT_EXPIRE_SECONDS`, 2 hours). Files survive redeploys and don't fill a volume.
- **Private database.** Postgres has no public domain or TCP proxy.
- **Pinned version** instead of `latest`, with a healthcheck on `/api/v1/health`.

### Changes from the earlier version of this template

Earlier versions used MinIO, a MinIO Console and a bucket-init sidecar, plus Redis. MinIO's open-source repository was archived in 2026, so storage moved to a Railway Bucket. Redis was dropped: NocoDB's job queue (Bull) ignores the `family` option in the Redis URL and looks up IPv4 addresses only, while Railway's private network uses IPv6, so current NocoDB versions crash-loop with `Connection is closed`. Without Redis, NocoDB uses its built-in cache and queue, which is fine for a single instance. Existing deployments keep their services; this change only affects new deploys.

## After deploying

1. Open the **NocoDB** service and click its domain.
2. Sign in with `NC_ADMIN_EMAIL` and `NC_ADMIN_PASSWORD` from the NocoDB service's **Variables** tab.
3. Change the password in **Account settings** if you like. Changing the variable later has no effect.
4. Invite your team from **Team & Settings → Users**. Without an email server, copy the invite link NocoDB shows and send it yourself, or add SMTP variables (`NC_SMTP_HOST`, `NC_SMTP_PORT`, `NC_SMTP_FROM`, `NC_SMTP_USERNAME`, `NC_SMTP_PASSWORD`).

## Environment variables (NocoDB)

| Variable | Default | Description |
|----------|---------|-------------|
| `NC_ADMIN_EMAIL` | `admin@example.com` | Super admin email, used on first start. Set your own before deploying |
| `NC_ADMIN_PASSWORD` | generated, 32 chars | Super admin password |
| `NC_PUBLIC_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL used in links and emails. Update it if you add a custom domain |
| `NC_AUTH_JWT_SECRET` | generated | Signs login tokens |
| `NC_DB` | private Postgres | Metadata database |
| `NC_S3_*` | Railway Bucket references | Attachment storage (bucket, endpoint, region, keys, path-style) |
| `NC_ATTACHMENT_EXPIRE_SECONDS` | `7200` | Lifetime of signed attachment links |
| `NC_DISABLE_TELE` | `true` | Turns off NocoDB's telemetry |
| `NC_SETUP_JS` | start-up script | Switches sign-up to invite-only once the admin exists. Leave as is |

## Upgrading

Change the NocoDB image tag in the service settings to a newer release from [NocoDB's releases](https://github.com/nocodb/nocodb/releases) and redeploy. NocoDB migrates its metadata on start. Back up Postgres first.

## Backups

- **Postgres** holds everything except attachments: use Railway's volume backups or `pg_dump`.
- **Bucket** holds attachments: copy it with any S3 tool (`rclone`, `aws s3 sync`) using the bucket's credentials.

## Testing

Tested on 2026-11-08 with a clean deploy of this config:

- Health check 200. The API without a login, a wrong password and an unknown user were refused, and so was a stranger's sign-up ("Not allowed to signup").
- The admin signed in as super admin, and the invite-only setting was on.
- A base, a table with an attachment column and 3 rows were created through the API. An uploaded file was stored in the Railway Bucket and downloaded through its signed link without logging in; a tampered signature and the unsigned object URL were refused.
- After redeploying NocoDB and Postgres, the admin, the rows and the attachment were still there.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Not allowed to signup` | Expected: sign-up is invite-only. Invite the person from Team & Settings, or turn invite-only off in Account settings |
| Attachments don't load | Signed links expire after `NC_ATTACHMENT_EXPIRE_SECONDS`; reload the page for fresh links. Check the `NC_S3_*` variables still reference the Bucket |
| `nocodb-setup: admin sign-in failed` in logs | You changed the admin password. The sign-up setting was saved on first start, so this is harmless |
| Crash loop with `Connection is closed` | A Redis URL was added. Remove `NC_REDIS_URL` (see "Changes" above) |

## Resources

- [NocoDB documentation](https://nocodb.com/docs)
- [NocoDB environment variables](https://nocodb.com/docs/self-hosting/environment-variables)
- [Railway Buckets](https://docs.railway.com/guides/storage-buckets)
