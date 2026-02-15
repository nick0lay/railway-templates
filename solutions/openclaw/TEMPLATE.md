# OpenClaw Railway Template

## Template Overview

# Deploy and Host OpenClaw on Railway

OpenClaw is an open-source personal AI assistant platform that runs on your own infrastructure. It supports multi-channel chat (WhatsApp, Telegram, Slack, Discord, and more), 50+ built-in agent skills, persistent memory with embeddings, and extensible plugin architecture. This template deploys a durable instance with automatic S3-backed backup and disaster recovery.

## About Hosting OpenClaw

This template deploys OpenClaw as a single service with:

- **AI Gateway**: Multi-channel agent runtime with Control UI
- **50+ Skills**: Built-in agent skills for GitHub, Slack, coding, and more
- **Memory Plugin**: Persistent memory with search and embeddings (SQLite-backed)
- **S3 Backup**: Automatic state sync to a Railway Bucket every 5 minutes
- **Disaster Recovery**: Fresh deploys auto-restore from the last backup
- **Local Sync**: Download your backup locally with any S3-compatible CLI

Railway volumes persist your state across redeployments. The attached Railway Bucket provides an additional layer of durability — if the volume is ever lost, the service auto-restores from the bucket on next boot.

## Getting Started After Deployment

### Accessing OpenClaw

After deployment, click on the **OpenClaw** service to find your URL:

1. **Deployments Tab**: The URL is displayed directly under the service name
2. **Settings > Networking**: Go to Settings tab → scroll to Networking → find Public Networking

### Connecting to the Control UI

The template generates both `OPENCLAW_GATEWAY_PASSWORD` and `OPENCLAW_GATEWAY_TOKEN` by default. When both are set, password mode is used.

- **Password mode** (default): Enter the password each time you open the Control UI. You can change `OPENCLAW_GATEWAY_PASSWORD` in Variables to a memorable value
- **Token mode**: The token is persisted on the client — after the first login, the UI reconnects automatically on subsequent visits. To switch to token mode, remove `OPENCLAW_GATEWAY_PASSWORD` from Variables and use the `OPENCLAW_GATEWAY_TOKEN` value instead

### Accessing via CLI (SSH)

You can SSH into the running container using the [Railway CLI](https://docs.railway.com/guides/cli) for advanced tasks — configuring Claude subscriptions, managing credentials, or running CLI commands directly:

```bash
railway link
railway ssh --service OpenClaw --environment production
npx openclaw --help
```

See the [full CLI access guide](https://github.com/nick0lay/openclaw/blob/railway-deployment/railway/README.md#accessing-your-instance-via-cli) for detailed setup instructions.

### Backup

A Railway Bucket is already attached to the template. Backup is enabled by default and runs automatically every 5 minutes — check logs for `[backup-sync]` messages. Fresh deploys auto-restore from the bucket if the volume is lost. See the [backup & local sync guide](https://github.com/nick0lay/openclaw/blob/railway-deployment/railway/README.md) for instructions on downloading your backup to a local machine.

## Common Use Cases

- Self-hosted AI assistant accessible from WhatsApp, Telegram, Slack, or Discord
- Private coding agent with GitHub integration and persistent memory
- Multi-channel team assistant with custom skills and workflows
- Personal AI with full data ownership — no data leaves your infrastructure
- Durable deployment with S3 backup for disaster recovery
- Infrastructure-aware agent that can manage its own Railway deployment via Railway Skills
- Local development with Railway as production backend (sync state via S3)

## Dependencies for OpenClaw Hosting

- Docker (OpenClaw is built from source inside the container)
- Node.js 22 (included in the Docker image)
- Railway Bucket (included in the template)

### Deployment Dependencies

- [OpenClaw GitHub Repository](https://github.com/openclaw/openclaw)

### Service

| Service | Source | Description |
|---------|--------|-------------|
| OpenClaw | [`nick0lay/openclaw@railway-deployment`](https://github.com/nick0lay/openclaw/tree/railway-deployment) | AI gateway with Control UI, agent runtime, and S3 backup |

### Environment Variables

**User-Configurable:**

| Variable | Description |
|----------|-------------|
| `OPENCLAW_GATEWAY_PASSWORD` | Gateway login password for browser access (recommended) |
| `OPENCLAW_GATEWAY_TOKEN` | Gateway auth token for machine-to-machine access (alternative to password) |
| `ANTHROPIC_API_KEY` | API key from [Anthropic Console](https://console.anthropic.com). Required for the agent to respond to messages |
| `OPENAI_API_KEY` | API key from [OpenAI Platform](https://platform.openai.com). Enables memory embeddings (vector search over past conversations) and allows using OpenAI models as an alternative AI provider |
| `BACKUP_ENABLED` | Enable/disable S3 backup (default: `true`) |
| `BACKUP_INTERVAL_SEC` | Seconds between backup cycles (default: `300`) |

**Auto-Configured (Do Not Change):**

| Variable | Description |
|----------|-------------|
| `OPENCLAW_STATE_DIR` | State directory (`/data/.openclaw`) |
| `OPENCLAW_GATEWAY_ALLOW_REMOTE_CONTROL_UI` | Enables remote Control UI access (`true`) |
| `BACKUP_S3_PREFIX` | S3 key prefix, references `${{OpenClaw.OPENCLAW_STATE_DIR}}` |
| `BUCKET` | Backup bucket name, references `${{Bucket.BUCKET}}` |
| `REGION` | Backup bucket region, references `${{Bucket.REGION}}` |
| `ENDPOINT` | Backup bucket endpoint, references `${{Bucket.ENDPOINT}}` |
| `ACCESS_KEY_ID` | Backup bucket access key, references `${{Bucket.ACCESS_KEY_ID}}` |
| `SECRET_ACCESS_KEY` | Backup bucket secret key, references `${{Bucket.SECRET_ACCESS_KEY}}` |

### Volume

| Mount Path | Purpose |
|------------|---------|
| `/data` | All persistent data (state, workspace, memory databases) |

## Key Features

### S3-Backed Backup & Disaster Recovery
Automatic state sync to a Railway Bucket every 5 minutes. SQLite databases are safely copied using the `.backup` API without locking. Fresh deploys auto-restore from the bucket. A final backup runs on graceful shutdown.

### Local Sync
Download your full Railway backup locally using `aws s3 sync` or any S3-compatible CLI. Useful for local development, migration, or offline access to your data. See the [backup & local sync guide](https://github.com/nick0lay/openclaw/blob/railway-deployment/railway/README.md) for step-by-step instructions.

### Multi-Channel Chat
Connect WhatsApp, Telegram, Slack, Discord, Google Chat, Signal, iMessage, Teams, and more through a single gateway.

### 50+ Built-in Skills
Agent skills for GitHub, Slack, coding, file management, web search, and more — all included out of the box.

### Persistent Memory
Memory plugin with search and embeddings stored in SQLite. Conversations and context persist across restarts and redeploys.

### CLI Access via SSH
SSH into the running container using `railway ssh` for advanced configuration — manage credentials, configure Claude subscriptions, run OpenClaw CLI commands, and debug the environment without leaving your terminal.

### Railway Skills (Infrastructure Self-Awareness)
Let OpenClaw manage its own Railway infrastructure — list projects, check deployments, view logs, manage variables, add databases, and more through natural language. To install, simply ask OpenClaw to install the skill by providing the repository link: `https://github.com/railwayapp/railway-skills`. OpenClaw will handle the rest. Then provide a [Railway API token](https://railway.com/account/tokens) and the agent can operate on your Railway account autonomously.

### Extensible Plugins
Load custom extensions for additional capabilities. Memory, skills, and integrations are modular and configurable.

## Why Deploy OpenClaw on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying OpenClaw on Railway, you get a fully managed AI assistant platform with automatic S3 backup, disaster recovery, and persistent storage — all configured and ready to use. Host your servers, databases, AI agents, and more on Railway.
