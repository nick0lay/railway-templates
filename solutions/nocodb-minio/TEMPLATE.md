# Deploy and Host NocoDB on Railway

NocoDB is an open-source Airtable alternative: it turns a database into a collaborative spreadsheet with grid, kanban, gallery and form views, automations and a REST API. This template runs the official NocoDB image (2026.10.1) with PostgreSQL and a Railway Bucket for file attachments.

## About Hosting NocoDB

The template deploys NocoDB, a private PostgreSQL database and a Railway Bucket. NocoDB is the only public service and requires a login. The super admin is created at deploy from `NC_ADMIN_EMAIL` and a generated `NC_ADMIN_PASSWORD`, and sign-up is switched to invite-only right after, so nobody else can claim the instance. Uploads go through NocoDB into the private bucket, and browsers get signed links that expire, so attachments survive redeploys without a volume. Postgres has no public domain or TCP proxy. The NocoDB version is pinned and the stack was tested end to end: logins, refused strangers, tables, attachments and redeploys.

## Common Use Cases

- Replace Airtable with a self-hosted spreadsheet database
- Project tracking, CRM and inventory with kanban, gallery and form views
- Collect data with shareable forms
- A REST API on top of your tables for apps and automations
- A spreadsheet UI for an existing Postgres or MySQL database

## Dependencies for NocoDB Hosting

- PostgreSQL (included, private)
- Railway Bucket (included, private) for attachments

### Deployment Dependencies

- [NocoDB on GitHub](https://github.com/nocodb/nocodb)
- [NocoDB Docker image](https://hub.docker.com/r/nocodb/nocodb)
- [NocoDB environment variables](https://nocodb.com/docs/self-hosting/environment-variables)

### Implementation Details

After the deploy finishes:

1. Open the NocoDB service's domain.
2. Sign in with `NC_ADMIN_EMAIL` and `NC_ADMIN_PASSWORD` from the NocoDB service's Variables tab. Set `NC_ADMIN_EMAIL` to your own address before deploying; changing it later has no effect.
3. Invite your team from Team & Settings. Without an email server, copy the invite link and send it yourself, or add `NC_SMTP_*` variables.

Attachment links are signed and expire after `NC_ATTACHMENT_EXPIRE_SECONDS` (2 hours by default). To upgrade, change the image tag to a newer NocoDB release and redeploy; back up Postgres first.

This template no longer includes MinIO (its open-source repository was archived in 2026) or Redis (NocoDB's job queue can't reach Redis over Railway's IPv6 private network, and NocoDB runs fine without it on one instance).

## Why Deploy NocoDB on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying NocoDB on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
