# Odoo 20

Odoo Community 20 (CRM, sales, invoicing, accounting, inventory, purchase, manufacturing, projects and more) on the official image with PostgreSQL 18. The database and the administrator are created at deploy with a generated password, and the database manager is off.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/odoo-20?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

Want Claude or another AI agent to work in Odoo? See [Odoo 20 + MCP](../odoo-mcp/).

## Architecture

```
Browser
   │  HTTPS (Railway edge)
   ▼
┌──────────────────────────────┐   private network   ┌──────────────────────────────┐
│ Odoo (public)                │ ──────────────────▶ │ Postgres (private)           │
│ odoo:20.0-20261102 :8069     │     tcp :5432       │ postgres-ssl:18              │
│ threaded: HTTP + websocket   │                     │ user odoo, generated password│
│ volume /var/lib/odoo         │                     │ volume /var/lib/postgresql   │
└──────────────────────────────┘                     └──────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Odoo | `odoo:20.0-20261102` | Web app, websocket bus and scheduled actions in one threaded process (public). Filestore and sessions on a volume |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Database (private, no TCP proxy) |

## What this template does differently

| Problem in common Odoo setups | Here |
|-------------------------------|------|
| `/web/database/manager` open: the first visitor can set the master password, create, back up or drop databases | `list_db = False` and `dbfilter` fixed to one database: the manager, the selector and the `db` RPC service are disabled |
| `admin` / `admin` works on the public URL until someone changes it | The database is created with a generated `ODOO_ADMIN_PASSWORD`; `admin` / `admin` is refused |
| No master password, or a static one shared in a template | `admin_passwd` is a generated 32-character secret |
| Odoo 20 listens on 127.0.0.1 by default, so the service is unreachable | `http_interface = 0.0.0.0` |
| Empty SMTP port variables crash the start (`int('')`) | SMTP is optional; mail settings are written only when `SMTP_SERVER` is set |
| Floating `odoo:latest` tag | Dated tag pinned; all modules are updated automatically after you change it |
| `--init` on every start, or a database recreated by accident | The start script checks Postgres and creates the database only when it has no Odoo install; an existing database is never dropped |

## After deploy

1. Wait about a minute. The Odoo logs show `odoo-setup: database created; log in as admin with ODOO_ADMIN_PASSWORD`.
2. Open the Odoo domain and log in as `admin` with `ODOO_ADMIN_PASSWORD` (Odoo service, Variables tab).
3. Install apps from **Apps**. To have them installed at deploy, set `ODOO_INIT_MODULES` (for example `crm,sale_management,account,stock`) before the first deploy.
4. In **Preferences**, change the admin password and set a real e-mail address. Invite users in **Settings > Users**.

## Variables

### User-configurable (Odoo service)

| Variable | Default | Notes |
|----------|---------|-------|
| `ODOO_ADMIN_PASSWORD` | generated, 24 characters | First start only. Later, change it in Odoo |
| `ODOO_ADMIN_LOGIN` | `admin` | First start only |
| `ODOO_MASTER_PASSWORD` | generated, 32 characters | `admin_passwd`. The database manager is disabled anyway |
| `ODOO_DB` | `odoo` | Database name. Don't change it after the first deploy |
| `ODOO_LANGUAGE` | `en_US` | Language of the new database |
| `ODOO_COUNTRY` | empty | Country code of the main company, e.g. `US`, `DE` |
| `ODOO_INIT_MODULES` | empty | Apps to install on first start, comma-separated |
| `ODOO_WITH_DEMO` | `false` | Demo data in the new database |
| `ODOO_CRON_THREADS` | `1` | Threads for scheduled actions |
| `SMTP_SERVER` | empty | Outgoing mail host. Empty: no outgoing mail server in the config (you can add one in Odoo) |
| `SMTP_PORT` | `587` | Falls back to 587 when empty or not a number |
| `SMTP_USER`, `SMTP_PASSWORD` | empty | Mail server login |
| `SMTP_SSL` | `true` | STARTTLS |
| `EMAIL_FROM` | empty | Default From address |

### Auto-configured (do not change)

| Variable | Value | Why |
|----------|-------|-----|
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD` | `${{Postgres.PGHOST}}` and friends | Connection to the private Postgres. Odoo refuses the user `postgres`, so the Postgres service uses `odoo` |
| `PORT` | `8069` | The domain and the healthcheck point here |
| `RAILWAY_RUN_UID` | `0` | The container starts as root only to give the `odoo` user the volume, then Odoo runs as `odoo` |
| `ODOO_RUN_SH` | script | Writes `/tmp/odoo.conf`, creates or updates the database, starts Odoo |

## Upgrading

Change the image tag of the Odoo service to a newer `20.0-<date>` tag and redeploy. The start script sees the new build and runs `odoo -u all` once before starting. Back up first (see below). A major version change (20 to 21) needs Odoo's upgrade process and is not done automatically.

## Backups

The web database manager is disabled on purpose. Back up with Railway's volume backups for both services, or with `pg_dump` against Postgres plus a copy of `/var/lib/odoo/filestore`.

## Custom domain

Add the domain to the Odoo service. Odoo builds links from the URL of the first admin login (`web.base.url`); after switching domains, log in once on the new domain as admin or change `web.base.url` in **Settings > Technical > System Parameters**.

## Troubleshooting

- **Healthcheck fails on the first deploy**: check the Odoo logs for `odoo-setup: ERROR`. Database creation takes about a minute, longer with `ODOO_INIT_MODULES`.
- **`database odoo exists and holds tables that are not Odoo's`**: `ODOO_DB` points to a database used by something else. Set another name.
- **Login fails with the generated password**: the password was changed in Odoo after the first start; the variable is not read again.
- **Mail not sent**: set `SMTP_SERVER` and the login variables, or configure an outgoing mail server in Odoo.
- **Custom addons**: Odoo also loads addons from `/var/lib/odoo/addons/20.0` on the volume.

## License

Odoo Community Edition is LGPL-3.0. Enterprise apps are not included.

## Test notes

2026-11-11, on Railway: first start created the database in under a minute. `/web/health` 200; `admin` / `admin` refused; `admin` with the generated password logs in as administrator; database manager, selector, database list, web database creation and the `db` RPC service are all refused; websocket upgrade (101) on the public domain; Postgres has no public domain or TCP proxy. After redeploying Odoo and Postgres the start script skipped database creation, and a contact created before the redeploy was still there. A changed image build triggered `-u all` once (tested in a local copy).
