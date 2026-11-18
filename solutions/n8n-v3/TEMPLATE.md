# Deploy and Host n8n 3 (queue mode + task runners) on Railway

n8n is a workflow automation tool with 400+ app nodes, AI agents, webhooks and JavaScript or Python code. This template runs n8n 3.2 the way n8n recommends for production: queue mode with a worker, Code nodes in isolated task runner containers, PostgreSQL 18 and Redis, with the owner account created at deploy time.

## About Hosting n8n 3 (queue mode + task runners)

The main n8n instance serves the editor, REST API and webhooks and puts every execution in a Redis queue. A worker picks the executions up, manual runs from the editor included, and stores the results in PostgreSQL. Code nodes don't run inside n8n: n8n 3 deprecates the old internal runner, so JavaScript and Python run in a separate `n8nio/runners` container attached to the worker over the private network. All images are official and pinned to the same version.

n8n 3 is an early access release: n8n still marks every 3.x release as a pre-release, and its `stable` Docker tag points to 2.x. This is a separate template for trying n8n 3 and starting new projects on it.

## Common Use Cases

- AI agents and chatbots that call your APIs, docs and databases
- Webhook backends: receive, transform and answer HTTP requests
- Syncing CRMs, spreadsheets, databases and SaaS apps on a schedule
- Data processing with JavaScript or Python Code nodes
- Internal tools and approvals with forms, email and chat

## Dependencies for n8n 3 (queue mode + task runners) Hosting

- PostgreSQL 18 (workflows, credentials, executions, binary data)
- Redis 8 (execution queue, persistent, noeviction)
- n8n worker and task runner (official images, same version as n8n)

### Deployment Dependencies

- n8n: https://github.com/n8n-io/n8n
- n8n docs: https://docs.n8n.io
- n8n 3.0 breaking changes: https://docs.n8n.io/changelog/v30-breaking-changes

### Implementation Details

**What you set:** `N8N_INSTANCE_OWNER_EMAIL`, the email you log in with.

**After deploy:** open the `n8n` URL and log in with `N8N_INSTANCE_OWNER_EMAIL` and the generated `N8N_OWNER_PASSWORD` (variables of the `n8n` service). Production webhooks answer on `https://your-n8n-domain/webhook/your-path`.

**This template:**

- Pins n8n 3.2.2 on main, worker and runner, PostgreSQL 18 and Redis 8.10
- Creates the owner account before n8n listens, so there is no setup screen anyone could claim
- Runs n8n in queue mode: main for the editor and webhooks, a worker for every execution
- Runs Code nodes in an external task runner with a generated token, no internal-mode fallback
- Generates and shares the encryption key between main and worker
- Sets the webhook URL (`N8N_WEBHOOK_URL`) to the public domain, with no deprecation warnings at startup
- Keeps worker, runner and databases private; only n8n has a domain
- Needs no n8n volume: binary data is stored in PostgreSQL

**Coming from n8n 2.x:** run **Settings, Migration Report** on your 2.x instance first and back up the database; the upgrade migrates it one way. n8n 3 removes old nodes (Function, Item Lists, Cron, Interval, Read Binary File and others), turns chat hub off, enforces a Content-Security-Policy, drops `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS` (manual runs always go to workers), lowers the default Code node timeout to 60 seconds (this template sets 300) and blocks unverified community nodes by default (set `N8N_UNVERIFIED_PACKAGES_ENABLED=true` to allow them). Our n8n 2.x templates are separate and unchanged.

**Notes:** The owner is reset from its variables on every start: change the password in Railway, or set `N8N_INSTANCE_OWNER_MANAGED_BY_ENV=false` to manage it in n8n. Don't change `N8N_ENCRYPTION_KEY` after the first deploy. Upgrade by changing all three n8n services to the same version. n8n is under the Sustainable Use License.

## Why Deploy n8n 3 (queue mode + task runners) on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying n8n 3 (queue mode + task runners) on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
