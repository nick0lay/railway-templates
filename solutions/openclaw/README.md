# OpenClaw

A personal AI assistant platform with multi-channel chat, S3-backed backup, and disaster recovery on Railway.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/openclaw-moltbot-clawdbot-data-backupres?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Overview

This solution deploys OpenClaw as a durable single-service deployment with:
- **AI Gateway**: Multi-channel chat support (WhatsApp, Telegram, Slack, Discord, and more)
- **50+ Built-in Skills**: GitHub, Slack, coding-agent, and other agent skills out of the box
- **Memory Plugin**: Persistent memory with search and embeddings
- **S3 Backup**: Automatic state sync to a Railway Bucket every 5 minutes
- **Disaster Recovery**: Fresh deploys auto-restore from the last backup
- **Local Sync**: Download your Railway backup locally using any S3-compatible CLI
- **Railway Skills**: Teach the agent to manage its own Railway infrastructure

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          Internet                               │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                  OpenClaw Gateway (Public)                       │
│                  Port 8080                                       │
│                  Control UI + API + Agent Runtime                │
│                                                                  │
│  ┌──────────────────┐  ┌──────────────────────────────────┐     │
│  │  Gateway Process  │  │  Backup Sync Loop (background)   │     │
│  │  (main)           │  │  every 300s → S3 bucket          │     │
│  └──────────────────┘  └──────────────────────────────────┘     │
└──────────────┬──────────────────────────────┬───────────────────┘
               │                              │
               ▼                              ▼
┌──────────────────────────┐   ┌──────────────────────────────┐
│      /data Volume        │   │     Railway Bucket (S3)      │
│  ┌────────┬──────────┐   │   │                              │
│  │ config │ workspace│   │   │  openclaw-state/files/       │
│  ├────────┼──────────┤   │   │  openclaw-state/sqlite/      │
│  │ memory │  skills  │   │   │  backup-marker.json          │
│  └────────┴──────────┘   │   │                              │
└──────────────────────────┘   └──────────────────────────────┘
```

## Quick Start

1. Click the **Deploy on Railway** button above
2. Set `SETUP_PASSWORD` for the onboarding wizard
3. Attach a **Railway Bucket** to the service for backup (recommended)
4. Wait for the service to deploy
5. Access OpenClaw via the generated Railway domain

## Service

| Service | Source | Description |
|---------|--------|-------------|
| OpenClaw | [`nick0lay/openclaw@railway-deployment`](https://github.com/nick0lay/openclaw/tree/railway-deployment) | AI gateway with Control UI, agent runtime, and S3 backup (public) |

The deployment source is maintained in a separate repository. The custom Dockerfile builds OpenClaw from source and adds sqlite3 CLI and AWS CLI for backup support.

## Accessing OpenClaw After Deployment

After deployment, click on the service to find your URL:

1. **Deployments Tab**: The URL is displayed directly under the service name
2. **Settings > Networking**: Go to Settings tab → scroll to Networking → find Public Networking

### Gateway Authentication

The gateway requires authentication when binding to a network address (which this template does). It supports two **mutually exclusive** auth modes — you use one or the other, never both:

| Mode | Variable | Best For | How It Works |
|------|----------|----------|--------------|
| **Password** (recommended) | `OPENCLAW_GATEWAY_PASSWORD` | Human access via browser | You type a memorable password in the Control UI login screen |
| **Token** | `OPENCLAW_GATEWAY_TOKEN` | Machine-to-machine | Random 64-char string sent in the connection handshake, never typed manually |

**Selection logic**: If `OPENCLAW_GATEWAY_PASSWORD` is set, password mode activates automatically. Otherwise the gateway falls back to token mode. If neither is set, the gateway will refuse to start.

**Recommendation**: For Railway deployments where you access the Control UI in a browser, set `OPENCLAW_GATEWAY_PASSWORD` to a memorable password. This gives a much better experience — you just type your password in the login screen instead of copying a 64-character token from the Variables tab.

### Connecting to the Control UI

**If using password mode** (recommended):

1. Open the public URL in your browser
2. Enter the password you set in `OPENCLAW_GATEWAY_PASSWORD`

**If using token mode**:

1. Open your Railway project dashboard
2. Click on the **OpenClaw** service → **Variables** tab
3. Find `OPENCLAW_GATEWAY_TOKEN` — click the eye icon to reveal the value
4. Copy and paste the token when the Control UI prompts you to connect

### Initial Setup

On first access you will see the setup wizard. Use the `SETUP_PASSWORD` you configured in Variables to complete onboarding. After completing the wizard, you can start chatting with your OpenClaw agent through the Control UI.

## Environment Variables

### User-Configurable Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SETUP_PASSWORD` | - | Password for the onboarding setup wizard (required) |
| `OPENCLAW_GATEWAY_PASSWORD` | - | Gateway login password for Control UI (recommended for human access) |
| `OPENCLAW_GATEWAY_TOKEN` | - | Gateway auth token for machine-to-machine access (used if password is not set) |
| `BACKUP_ENABLED` | `true` | Enable/disable S3 backup sync |
| `BACKUP_INTERVAL_SEC` | `300` | Seconds between backup cycles (default: 5 minutes) |
| `BACKUP_S3_PREFIX` | `openclaw-state` | Prefix inside the S3 bucket for backup data |

### Auto-Configured (Do Not Change)

| Variable | Value | Description |
|----------|-------|-------------|
| `PORT` | `8080` | Container port. Railway routes traffic to this port. |
| `OPENCLAW_STATE_DIR` | `/data/.openclaw` | State directory on the persistent volume. Changing breaks backup paths. |
| `OPENCLAW_WORKSPACE_DIR` | `/data/workspace` | Workspace directory on the persistent volume. |

### S3 Bucket Variables (Auto-Injected)

These are automatically set when you attach a Railway Bucket to the service:

| Variable | Description |
|----------|-------------|
| `BUCKET` | S3 bucket name |
| `ACCESS_KEY_ID` | S3 access key |
| `SECRET_ACCESS_KEY` | S3 secret key |
| `ENDPOINT` | S3 endpoint URL (e.g. `https://storage.railway.app`) |
| `REGION` | S3 region (typically `auto`) |

If no Bucket is attached, backup sync is gracefully disabled and the gateway runs without backup.

## Volume

| Mount Path | Purpose |
|------------|---------|
| `/data` | All persistent data (state, workspace, memory databases) |

Data layout on the volume:

- `/data/.openclaw/` — Gateway state (config, memory, plugins)
- `/data/.openclaw/memory/` — SQLite databases (conversations, embeddings)
- `/data/.openclaw/openclaw.json` — Gateway configuration
- `/data/workspace/` — Agent workspace files

## Backup & Disaster Recovery

This template includes an S3-backed backup system that runs alongside the gateway process.

### How It Works

1. **On Boot (Restore)**: If the local volume is empty (fresh deploy or volume wipe), state is downloaded from the S3 bucket before the gateway starts
2. **During Operation (Backup Loop)**: Every 5 minutes (configurable), state is synced to the bucket:
   - SQLite databases are safely copied using the `sqlite3 .backup` API (no locking required)
   - Config, workspace, and non-SQLite files are synced via `aws s3 sync`
   - Ephemeral files (locks, temp, media) are excluded
3. **On Shutdown (Final Backup)**: A final backup runs before the container exits

### S3 Bucket Structure

```
s3://BUCKET/openclaw-state/
├── files/               # All non-SQLite state (config, workspace, etc.)
├── sqlite/              # Safe SQLite database copies
└── backup-marker.json   # Last backup timestamp
```

### Syncing Backup Locally

You can download your Railway backup to a local machine using any S3-compatible CLI. Find the bucket credentials in the Railway Bucket service variables.

```bash
# Configure AWS CLI with Railway Bucket credentials
export AWS_ACCESS_KEY_ID="<ACCESS_KEY_ID from Railway>"
export AWS_SECRET_ACCESS_KEY="<SECRET_ACCESS_KEY from Railway>"
export AWS_DEFAULT_REGION="auto"

# Download the full backup
aws s3 sync "s3://<BUCKET>/openclaw-state/" ./openclaw-backup/ \
  --endpoint-url "<ENDPOINT from Railway>"

# Or download only SQLite databases
aws s3 sync "s3://<BUCKET>/openclaw-state/sqlite/" ./openclaw-backup/sqlite/ \
  --endpoint-url "<ENDPOINT from Railway>"

# Check when the last backup ran
aws s3 cp "s3://<BUCKET>/openclaw-state/backup-marker.json" - \
  --endpoint-url "<ENDPOINT from Railway>"
```

You can also use other S3-compatible tools such as `s3cmd`, `rclone`, or `mc` (MinIO Client).

### Restoring From a Local Backup

To push a local backup to the Railway Bucket (e.g. migrating from another deployment):

```bash
# Upload state files
aws s3 sync ./openclaw-backup/files/ "s3://<BUCKET>/openclaw-state/files/" \
  --endpoint-url "<ENDPOINT from Railway>"

# Upload SQLite databases
aws s3 sync ./openclaw-backup/sqlite/ "s3://<BUCKET>/openclaw-state/sqlite/" \
  --endpoint-url "<ENDPOINT from Railway>"
```

Then redeploy or restart the Railway service. On boot, the entrypoint will detect an empty volume and restore from the bucket.

## Railway Skills (Infrastructure Self-Awareness)

OpenClaw can manage its own Railway infrastructure when equipped with [Railway Agent Skills](https://docs.railway.com/ai/agent-skills). Once configured, your agent can list projects, check deployment status, manage environment variables, view logs, and more — all through natural language.

### Step 1: Install Railway Skills

Ask your OpenClaw agent to install the official Railway skills:

> Install skills from https://github.com/railwayapp/railway-skills

OpenClaw will download and register 12 skills covering project management, service operations, deployments, domains, databases, metrics, and documentation. The skills are markdown-based instruction files that teach the agent how to interact with Railway's API.

Available skills after installation:

| Skill | Capability |
|-------|------------|
| `status` | Check project status |
| `projects` | List, switch, and configure projects |
| `new` | Create projects, services, databases |
| `service` | Manage existing services |
| `deploy` | Deploy local code |
| `domain` | Manage service domains |
| `environment` | Manage variables, build/deploy settings, replicas |
| `deployment` | List deployments, view logs, redeploy, rollback |
| `database` | Add Railway databases (Postgres, Redis, MySQL, MongoDB) |
| `templates` | Deploy from the Railway marketplace |
| `metrics` | Query CPU, memory, network, disk usage |
| `railway-docs` | Fetch up-to-date Railway documentation |

### Step 2: Install Railway CLI

The Railway skills use the Railway CLI under the hood. Ask OpenClaw to install it:

> Install Railway CLI

The agent will run the official install script (`bash <(curl -fsSL cli.new)`) inside its environment. The CLI binary persists on the `/data` volume across redeploys.

### Step 3: Provide a Railway API Token and Verify

Generate an API token in your [Railway account settings](https://railway.com/account/tokens), then give it to the agent:

> Here is my Railway token: `<your-token>`. Log in with it and list all my Railway projects to confirm it works.

The agent will run `railway login --token <your-token>` and then `railway list` to verify the connection. You should see your Railway projects listed in the response.

### What You Can Do After Setup

Once skills and CLI are configured, you can ask OpenClaw things like:

- "What's the status of my Railway project?"
- "Show me the logs for the last deployment"
- "How much memory is my service using?"
- "Add a PostgreSQL database to my project"
- "Set the environment variable `API_KEY` to `abc123`"
- "Redeploy my service"

The agent uses Railway CLI commands behind the scenes, guided by the skill instructions.

## Multi-Process Container

The container runs two processes managed by the entrypoint script:

| Process | Role | Lifecycle |
|---------|------|-----------|
| OpenClaw Gateway | Main process — serves Control UI and agent API | Starts after restore, container exits when this dies |
| Backup Sync Loop | Background — syncs state to S3 every 300s | Starts after gateway, runs final backup on shutdown |

Graceful shutdown flow: `SIGTERM` → stop gateway → final backup → exit.

## Troubleshooting

### Gateway fails to start

1. Check service logs for error messages
2. Verify `PORT` is set to `8080`
3. Ensure the `/data` volume is mounted
4. Health check has a 300s timeout — the first build may take several minutes

### Backup not working

1. Verify a Railway Bucket is attached to the service
2. Check that `BUCKET`, `ACCESS_KEY_ID`, `SECRET_ACCESS_KEY`, `ENDPOINT`, and `REGION` are present in Variables
3. Look for `[backup-sync]` messages in service logs
4. If `BACKUP_ENABLED` is `false`, backup is intentionally disabled

### State not restored after redeploy

1. Restore only runs if the local volume is empty (no `openclaw.json` in state dir)
2. If the volume still has data, restore is skipped — this is expected behavior
3. To force a restore: delete the volume, redeploy, and the entrypoint will download from the bucket

### Cannot access Control UI

1. Verify you have a public domain assigned (Settings > Networking)
2. Device auth is disabled for Railway — access uses token/password auth
3. Check `SETUP_PASSWORD` is set if you see the setup wizard

### SQLite backup warnings in logs

Messages like "failed to backup ... (may be locked)" are non-fatal. The backup retries on the next cycle. This can happen during heavy write operations.

## Resources

- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [OpenClaw Documentation](https://docs.openclaw.com)
- [Railway Buckets Documentation](https://docs.railway.com/guides/buckets)
- [Railway Agent Skills](https://docs.railway.com/ai/agent-skills)
- [Railway Skills GitHub](https://github.com/railwayapp/railway-skills)
