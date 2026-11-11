# ERPNext 16 + MCP for Claude

Self-hosted [ERPNext](https://github.com/frappe/erpnext) v16 on Railway: open-source ERP for accounting, inventory, sales, purchasing, manufacturing, projects and HR, an alternative to Odoo and SAP Business One. This template runs the official Frappe images with MariaDB and two Redis instances. The site is created on first start with a generated Administrator password, background jobs and the scheduler run from the start, and every version is pinned and tested. ERPNext's built-in MCP server is on, so Claude and other AI agents can read and update your ERP data under a normal ERPNext login.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/erpnext-1?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
                 You / API clients
                        │ HTTPS
                        ▼
┌──────────────────────────────────────────────────────────┐
│ Railway project                                          │
│                                                          │
│  ERPNext :8080 (public, ERPNext login)                   │
│    nginx: static assets, routes /socket.io               │
│    gunicorn (web), socket.io (realtime),                 │
│    background worker (long, default, short), scheduler   │
│    site files and attachments on a volume (sites/)       │
│        │                  │                   │          │
│        ▼ :3306            ▼ :6379             ▼ :6379    │
│  MariaDB 11.8        Redis Cache         Redis Queue     │
│  (private, volume)   (private, memory)   (private, AOF)  │
└──────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| ERPNext | `frappe/erpnext:v16.54.0` | Web server, realtime server, background worker, scheduler and nginx in one container (public). Site config and attachments on a volume |
| MariaDB | `mariadb:11.8.9` | Database, with the utf8mb4 settings Frappe requires (private, volume) |
| Redis Cache | `redis:8.10` | Cache, in memory only, least-recently-used eviction at 256 MB (private) |
| Redis Queue | `redis:8.10` | Background job queue and realtime events, append-only file on a volume (private) |

## What this template does differently

- **Official images, current version.** Frappe's own `frappe/erpnext` image at v16.54.0 and MariaDB 11.8, the versions in Frappe's compose files, instead of third-party all-in-one images, MariaDB 10.6 or Redis 6.
- **Site created for you.** On first start the container creates the site, installs ERPNext and sets the Administrator password from the generated `ADMIN_PASSWORD`. Later starts skip this. If the image version changes, the container runs `bench migrate` once before starting.
- **Everything that needs the site files in one service.** Frappe's compose file runs web, realtime, workers and scheduler as separate containers sharing one `sites` volume. Railway volumes can't be shared, so they run together in the ERPNext service, with the volume on `sites/`. If any process stops, the container exits and Railway restarts it.
- **Background jobs and scheduler on.** One worker serves the long, default and short queues, and the scheduler is enabled, so emails, recurring documents and auto-repeat work.
- **Private data services.** MariaDB and both Redis instances have no public URL, and every Redis instance has a generated password.
- **MCP server ready for Claude.** Frappe v16 includes an MCP server at `/api/v2/mcp`, on by default. It is served over the same HTTPS domain and needs an ERPNext login (OAuth or an API key); see [Connect Claude](#connect-claude-and-other-ai-agents-mcp).
- **Healthcheck** on `/api/method/ping` through nginx, with a 15-minute timeout for the first start.

## After deploy

The first deploy takes 3 to 6 minutes while the site is created. Watch for `erpnext-setup: site created` in the ERPNext logs.

1. Open the ERPNext URL and log in as `Administrator` with the `ADMIN_PASSWORD` variable of the `ERPNext` service.
2. Complete the setup wizard: language, country, currency, your company and fiscal year. It also creates your own user.
3. Add users under **Users** and give them roles. Use your own user day to day, not Administrator.
4. Set up email under **Email Account** so ERPNext can send invoices and notifications.
5. For scripts, create API keys for a user (**User → Settings → API Access**) and call `https://<your-url>/api/resource/...` with the header `Authorization: token <api_key>:<api_secret>`.

## Connect Claude and other AI agents (MCP)

ERPNext v16 has a built-in [MCP server](https://docs.frappe.io/framework/guides-integration/mcp) at `https://<your-url>/api/v2/mcp` (Streamable HTTP). Through it an agent can search document types, read their fields, list, read, count, create, update and delete documents, and call whitelisted methods. Every call runs with the permissions of the ERPNext user the agent logs in as.

**Create a user for the agent first.** Don't connect agents as Administrator: the tools include `delete_document` and `call_method`. In ERPNext, add a user (for example `claude@your-company.com`) with only the roles the agent needs, such as Accounts User or Stock User.

**claude.ai and Claude Desktop (OAuth).** Settings → Connectors → Add custom connector, URL `https://<your-url>/api/v2/mcp`. Claude registers itself with ERPNext (OAuth dynamic client registration is on by default) and opens the ERPNext login page; log in as the agent user and click **Allow**. Access tokens last an hour and Claude renews them with the refresh token.

**Claude Code, n8n and scripts (API key).** Open the agent user, **Settings → API Access → Generate Keys**, and use the key and secret as a header:

```bash
claude mcp add --transport http erpnext https://<your-url>/api/v2/mcp \
  --header "Authorization: token <api_key>:<api_secret>"
```

Then ask, for example, "list unpaid sales invoices older than 30 days" or "create a purchase order for 20 units of item X from supplier Y". Check what the agent wrote before you submit documents that post to the ledger.

Without a login, `/api/v2/mcp` answers 401.

## Variables

### User-configurable

| Variable | Default | Notes |
|---|---|---|
| `ADMIN_PASSWORD` | generated | Administrator password, set when the site is created on first start. Changing it later has no effect; change the password in ERPNext |
| `HOST_NAME` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL used in emails, links and print formats. Set it to your custom domain if you add one |
| `GUNICORN_WORKERS` | `2` | Web worker processes. Raise it for more users |
| `GUNICORN_THREADS` | `4` | Threads per web worker |

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `SITE_NAME` | `frontend` | Internal Frappe site name, as in Frappe's compose file. nginx always serves this site, so custom domains work without renaming it. Don't change it after the first deploy |
| `DB_HOST`, `DB_PORT` | `${{MariaDB.RAILWAY_PRIVATE_DOMAIN}}`, `3306` | Private network |
| `DB_ROOT_PASSWORD` | `${{MariaDB.MARIADB_ROOT_PASSWORD}}` | Used to create the site database and its own user |
| `REDIS_CACHE`, `REDIS_QUEUE` | `redis://:<password>@<private host>:6379` | Written to the bench config on every start |
| `PORT` | `8080` | nginx; the public domain points here |
| `RAILWAY_RUN_UID` | `0` | The container starts as root only to give the `frappe` user the volume. All ERPNext processes run as `frappe` |
| `ERPNEXT_RUN_SH` | script | Start script run by the start command: bench config, site creation or migrate, then all processes |
| MariaDB: `MARIADB_ROOT_PASSWORD`, `MARIADB_AUTO_UPGRADE` | generated, `1` | Root password; system tables are upgraded after a MariaDB update |
| Redis: `REDIS_PASSWORD` | generated | One per Redis service |

## Custom domain

Add the domain to the `ERPNext` service, set `HOST_NAME` to `https://your-domain` and redeploy.

## Upgrading

Change the image tag of the `ERPNext` service to a newer v16 release (for example `frappe/erpnext:v16.55.0`) and redeploy. On start, the container notices the new version and runs `bench migrate`. Back up first: in ERPNext, **Backups** can download the database and files, or snapshot the MariaDB and ERPNext volumes. Major upgrades (v16 to v17) need Frappe's upgrade notes; read them before changing the major version.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| The first deploy stays "deploying" for minutes | Site creation takes 3 to 6 minutes. Look for `erpnext-setup:` lines in the ERPNext logs |
| "Invalid login credentials" for Administrator | Use the `ADMIN_PASSWORD` the site was created with. If you changed the variable after the first deploy, the old value still applies |
| Setup failed on first start (for example MariaDB wasn't ready) | Redeploy the ERPNext service. An unfinished site is removed and created again |
| Emails and links use the wrong address | Set `HOST_NAME` to the URL you use and redeploy |
| Background jobs don't run | Look for `bench worker` and scheduler errors in the ERPNext logs; check that Redis Queue is running |
| Out of memory | Give the ERPNext service more memory, or lower `GUNICORN_WORKERS` |

## License

ERPNext is licensed under GPL-3.0 and the Frappe framework under MIT. The images are built by Frappe from [frappe_docker](https://github.com/frappe/frappe_docker).

## Testing

Tested on 2026-11-06 with ERPNext v16.54.0 (Frappe 16.55.2) in a throwaway Railway project, from the config: all four services healthy, and the site was created on first start in about two minutes. `/api/method/ping` answered `pong`. The API refused requests without a login (403) and a wrong Administrator password (401), and accepted the generated one; the desk loaded. The setup wizard was completed through the API (company, currency, fiscal year), then an item and a customer were created and a sales invoice was submitted. A file was attached to the customer and downloaded back intact. The background worker processed jobs from the long, default and short queues, the scheduler ran scheduled jobs, and the socket.io endpoint answered through nginx. MariaDB and both Redis instances have no public URL. After redeploying all four services, the setup step logged `site frontend already set up, skipped`, and the company, customer, invoice and file were still there. The restart paths were also checked with the same image locally: a site without the setup marker is detected as installed and kept, and a changed image version runs `bench migrate` before start. Email sending and the browser setup wizard weren't tested.

MCP checked on 2026-11-11 on fresh deploys of the published template. Without a login `/api/v2/mcp` answered 401 with OAuth metadata. With a user's API key, `initialize` and `tools/list` worked (13 tools). The OAuth flow a claude.ai connector uses was run step by step: client registration with the claude.ai callback URL, ERPNext login, the Allow page, the PKCE code exchange, MCP calls with the access token (valid 1 hour), and a refresh-token exchange followed by more MCP calls. Adding the connector inside the claude.ai interface itself wasn't tested.
