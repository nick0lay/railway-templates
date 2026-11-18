# n8n 3 (queue mode + task runners)

[n8n](https://github.com/n8n-io/n8n) 3.2 on Railway, set up the way n8n recommends for production: queue mode with a worker, Code nodes in separate task runner containers, PostgreSQL 18 and Redis. The owner account is created at deploy time, so nobody can claim a fresh instance, and every image is the official one with a pinned tag.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/n8n-32-queue-mode-task-runners?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

> **Early access.** n8n publishes the 3.x line as an early access release: every 3.x release is marked as a pre-release on GitHub, and n8n's `stable` and `latest` Docker tags still point to 2.x. Use this template to try n8n 3 or to start new projects on it. For an instance you depend on, stay on 2.x until n8n moves `stable` to 3.x.

This is a separate template. Our n8n 2.x templates stay on 2.47 and are not changed; deploying this one does not touch them.

## Architecture

```
                     You (browser), webhook callers
                                  │ HTTPS
                                  ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Railway project                                                      │
│                                                                      │
│   n8n :5678 (public, owner login)                                    │
│   editor, REST API, webhooks                                         │
│      │ enqueue           │                                           │
│      ▼                   ▼                                           │
│   Redis :6379        Postgres :5432                                  │
│   (private, queue)   (private: workflows, credentials,               │
│      │ jobs            executions, binary data)                      │
│      ▼                   ▲                                           │
│   n8n-worker (private) ──┘                                           │
│   runs every execution, manual ones too                              │
│      │ task broker :5679                                             │
│      ▼                                                               │
│   n8n-runner (private)                                               │
│   JavaScript + Python Code nodes                                     │
└──────────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| n8n | `n8nio/n8n:3.2.2` | Editor, REST API and webhooks; puts executions on the queue (public, owner login) |
| n8n-worker | `n8nio/n8n:3.2.2` | Runs all executions from the queue, including manual runs from the editor (private) |
| n8n-runner | `n8nio/runners:3.2.2` | Runs Code node JavaScript and Python for the worker, isolated from n8n (private) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Workflows, credentials, executions, binary data (private, volume) |
| Redis | `redis:8.10` | Execution queue, append-only file on a volume, `noeviction` (private) |

## What this template does

- **Owner created at deploy time.** n8n normally lets the first visitor create the owner account, so a fresh public instance can be claimed by someone else. Here the owner is created from `N8N_INSTANCE_OWNER_EMAIL` and the generated `N8N_OWNER_PASSWORD` before n8n listens. There is no setup screen.
- **Queue mode.** The main instance serves the editor, API and webhooks and puts executions in Redis; `n8n-worker` runs them. In n8n 3 manual executions always run on workers, so the worker also runs what you test in the editor.
- **External task runner.** n8n 3 deprecates the internal runner mode (a child process with n8n's own permissions) and logs a warning while it is used. Here Code nodes run in a separate `n8nio/runners` container attached to the worker's task broker with a generated token. In queue mode n8n 3's main instance runs no executions and starts no task broker, so it needs no runner of its own; it is still set to external mode, which keeps the deprecation warning away.
- **No n8n volume.** In queue mode n8n 3 stores binary data in Postgres by default, the encryption key is a variable, and community nodes you install from the UI are reinstalled after a redeploy.
- **Generated secrets.** `N8N_ENCRYPTION_KEY` (shared by main and worker), `N8N_OWNER_PASSWORD`, the runner token, and the Postgres and Redis passwords.
- **Private by default.** Only `n8n` has a public domain. Worker, runners, Postgres and Redis have no domain or TCP proxy.
- **Pinned versions.** n8n 3.2.2 on all three n8n services, Postgres 18, Redis 8.10.
- **No deprecation warnings at startup.** The webhook base URL uses `N8N_WEBHOOK_URL`, which replaces `WEBHOOK_URL` in n8n 3.

## After deploy

1. Open the `n8n` URL and log in with `N8N_INSTANCE_OWNER_EMAIL` and the `N8N_OWNER_PASSWORD` variable of the `n8n` service.
2. Build workflows. Production webhook URLs are `https://your-n8n-domain/webhook/your-path`; `N8N_WEBHOOK_URL` is already set to the public domain.
3. For API access, create an API key under **Settings → n8n API** and send it as the `X-N8N-API-KEY` header to `/api/v1/...`.

The owner is reset from the two variables on every start, so change the password in Railway, not in n8n's settings. To manage the owner in n8n instead, set `N8N_INSTANCE_OWNER_MANAGED_BY_ENV=false` on `n8n` after the first start.

## Coming from n8n 2.x

n8n 3.0 has breaking changes. The full list is in n8n's [v3.0 breaking changes](https://docs.n8n.io/changelog/v30-breaking-changes) page; these are the ones that matter for a Railway deployment.

**Before you move a 2.x instance**

- Open **Settings → Migration Report** on your 2.x instance (recent 2.x versions have it). It lists the workflows, nodes and settings that need changes, and can rewrite some nodes for you.
- Back up Postgres. n8n migrates the database forward on the first 3.x start, and 2.x can't read it afterwards.
- To move to this template, the simplest path is to export your workflows from the 2.x editor and import them here, then recreate the credentials. n8n's documented in-place path is to start 3.x on your existing database with the same encryption key; that was not tested with this template, which starts on a new, empty database.
- Node.js stays on version 26, as in recent 2.x images, and n8n still runs only from the Docker image (3.x is no longer published to npm).

**Removed nodes and helpers.** Workflows that use these fail, and published ones don't activate: Function, Function Item, Item Lists, LangChain Code, Cron, Interval, HTML Extract, iCalendar, Convert to/from binary data, Read/Write Binary File(s), Read PDF, Workflow Trigger, the legacy OpenAI node, OpenAI Assistant and OpenAI Model, the legacy HTTP Request Tool, SerpApi, Manual Chat Trigger, Chat Messages Retriever, Motorhead and Zep, the old document loaders and Insert/Load vector store nodes, AI Agent version 1 modes, Edit Image versions 1 and 1.1, and the AI Transform node. `$getPairedItem` is gone from expressions, `$evaluateExpression()` from the Code node, and the Execute Sub-workflow node lost its Local File and URL sources.

**Changed defaults**

| Setting | 2.x | 3.x | This template |
|---|---|---|---|
| `N8N_RUNNERS_TASK_TIMEOUT` | 300 s | 60 s | `300` on `n8n-worker`; the runner reads the same value |
| `N8N_UNVERIFIED_PACKAGES_ENABLED` | `true` | `false`: unverified community nodes can't be installed, and installed ones stop loading | `false`; set `true` on `n8n` (the worker follows) to keep the 2.x behavior |
| `N8N_RUNNERS_MODE=internal` | default | deprecated, warning at startup | `external` |
| `WEBHOOK_URL` | webhook base URL | deprecated, warning at startup; use `N8N_WEBHOOK_URL` (test and production webhooks) | `N8N_WEBHOOK_URL` |
| Manual executions in queue mode | on main unless `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true` | always on workers | worker |
| Binary data mode `default` (in memory) | allowed | removed | `database` (the queue mode default) |
| Chat hub | on | off; add `chat-hub` to `N8N_ENABLED_MODULES` for 3.x | off |
| Content-Security-Policy | report only | enforced on n8n's own pages | enforced |
| Encryption key rotation | opt in | on (Settings → Data Encryption Keys) | on |
| SSRF default block list (when SSRF protection is on) | | adds `100.64.0.0/10`, `::/128`, `2002::/16`, `64:ff9b::/96` | not turned on |
| Compression node limits | 2 GiB, 5000 entries | 256 MiB, 1000 entries | n8n default |

**Removed variables.** Remove these from your own configuration; n8n 3 ignores them: `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS`, `N8N_PRE_EXECUTE_ERROR_CREATES_EXECUTION`, `N8N_WORKFLOW_TAGS_DISABLED` (tags are always on), `N8N_MIGRATE_FS_STORAGE_PATH`. `N8N_DB_PING_TIMEOUT` is replaced by `DB_PING_TIMEOUT_MS`. `WEBHOOK_URL` still works but is deprecated; rename it to `N8N_WEBHOOK_URL`.

**Other changes.** The filesystem storage folder `~/.n8n/binaryData` is renamed to `~/.n8n/storage` (no effect here: there is no n8n volume). The Slack API credential needs the signing secret, or workflows with a Slack Trigger don't activate. Gmail Trigger versions below 1.4 behave like 1.4. The Chat Trigger WebSocket sends JSON frames, so custom chat clients need `@n8n/chat` 1.31.0 or later. Import from URL and the Code node's Ask AI tab are gone from the editor.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| n8n | `N8N_INSTANCE_OWNER_EMAIL` | `admin@example.com` | Owner login. Change it to your own before deploying |
| n8n | `N8N_INSTANCE_OWNER_MANAGED_BY_ENV` | `true` | `false` stops resetting the owner on start; manage it in n8n |
| n8n | `N8N_INSTANCE_OWNER_FIRST_NAME`, `N8N_INSTANCE_OWNER_LAST_NAME` | `Instance`, `Owner` | |
| n8n | `GENERIC_TIMEZONE` | not set (UTC) | Timezone of Schedule triggers, for example `Europe/Berlin`; worker and runner follow |
| n8n | `N8N_UNVERIFIED_PACKAGES_ENABLED` | `false` | `true` allows unverified community nodes; the worker follows |
| n8n-worker | `N8N_RUNNERS_TASK_TIMEOUT` | `300` | Seconds per Code node task; the runner reads the same value |
| n8n-runner | `N8N_RUNNERS_MAX_CONCURRENCY` | `5` | Code node tasks at once |

### Generated

| Service | Variable | Notes |
|---|---|---|
| n8n | `N8N_OWNER_PASSWORD` | Owner password. Change it here to change the password |
| n8n | `N8N_ENCRYPTION_KEY` | Encrypts stored credentials; the worker uses the same key. **Never change it after the first deploy** |
| n8n-worker | `N8N_RUNNERS_AUTH_TOKEN` | Shared secret between worker and runner |
| Postgres, Redis | `POSTGRES_PASSWORD`, `REDIS_PASSWORD` | |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| n8n | `N8N_RUN_SH` | start script | Hashes `N8N_OWNER_PASSWORD` (bcrypt) and starts n8n |
| n8n | `N8N_WEBHOOK_URL`, `N8N_HOST`, `N8N_EDITOR_BASE_URL` | public domain | Update them with a custom domain; the worker reads `N8N_WEBHOOK_URL` from `n8n` |
| n8n, n8n-worker | `EXECUTIONS_MODE` | `queue` | |
| n8n, n8n-worker | `DB_POSTGRESDB_*` | `${{Postgres.*}}` | Private network |
| n8n, n8n-worker | `QUEUE_BULL_REDIS_*` | `${{Redis.*}}` | `QUEUE_BULL_REDIS_DUALSTACK=true` for Railway's private network |
| n8n, n8n-worker | `N8N_RUNNERS_MODE` | `external` | Code nodes run in `n8n-runner` |
| n8n-worker | `N8N_RUNNERS_BROKER_LISTEN_ADDRESS` | `::` | The runner connects to the worker's broker over the private network |
| n8n-runner | `N8N_RUNNERS_TASK_BROKER_URI` | `http://${{n8n-worker.RAILWAY_PRIVATE_DOMAIN}}:5679` | |

The official runner image allows the `crypto` built-in and the `moment` package in JavaScript Code nodes, and restricts the Python standard library. Other packages need a custom runner image built from `n8nio/runners`.

## Custom domain

Add the domain to `n8n`, then set `N8N_HOST=your-domain`, `N8N_WEBHOOK_URL=https://your-domain/` and `N8N_EDITOR_BASE_URL=https://your-domain` on `n8n`. The worker reads `N8N_WEBHOOK_URL` from `n8n`.

## Scaling

Add replicas to `n8n-worker` for more parallel executions. Each worker replica has its own task broker and a runner connects to one broker, so plan one `n8n-runner` replica per worker replica if your workflows use Code nodes (replicas were not part of our test).

## Upgrading

Change `n8n`, `n8n-worker` **and** `n8n-runner` to the same version, for example `n8nio/n8n:3.3.0` and `n8nio/runners:3.3.0`. The runner version must match n8n. The main instance migrates the database on start, so back up Postgres first. Avoid `latest`, `next`, `beta` and nightly tags. Release notes: https://docs.n8n.io/release-notes/

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Can't log in | Use `N8N_INSTANCE_OWNER_EMAIL` and `N8N_OWNER_PASSWORD` from the `n8n` variables; a password changed in n8n's settings is reset on restart |
| Code node times out | `n8n-runner` isn't running, its tag differs from `n8n-worker`, or the task took longer than `N8N_RUNNERS_TASK_TIMEOUT` |
| Executions stay queued | `n8n-worker` isn't running; check its logs and `QUEUE_BULL_REDIS_*` |
| A community node disappeared after the upgrade | It is unverified; set `N8N_UNVERIFIED_PACKAGES_ENABLED=true` on `n8n` |
| An imported workflow fails with "unknown node" | It uses a node removed in 3.0; see the Migration Report on 2.x |
| Webhook returns 404 | The workflow isn't published, or you called `/webhook-test/` instead of `/webhook/` |

## License

n8n: [Sustainable Use License](https://github.com/n8n-io/n8n/blob/master/LICENSE.md). Self-hosting for your own business is allowed; selling n8n as a hosted service is not.

## Testing

Tested on 2026-11-18 with a test deploy of the template draft: all five services healthy. n8n showed no setup screen and refused an anonymous owner setup, its REST API without a login, the public API without a key or with a wrong key, and a wrong password; the generated owner password worked. A workflow created through the n8n API (Webhook with basic auth, a JavaScript Code node, Respond to Webhook) answered on the public production URL and refused calls without basic auth; a Python Code node ran too. The main instance enqueued the executions, the worker ran them, and the JavaScript and Python runners of `n8n-runner` registered with the worker's task broker. Neither n8n process logged a deprecation warning. After redeploying n8n, the worker and Postgres, the login, the published workflow and its credential were still there, and the webhook answered again. Worker and runner replicas, community nodes and an upgrade from a 2.x database were not tested.
