# Deploy and Host Paperclip on Railway

Paperclip is an open-source app for running AI agents as a company. You set goals, hire agents (Claude Code, Codex, OpenCode, Gemini and others) into an org chart with roles and budgets, hand them tasks, and review their work, approvals and costs from one board.

## About Hosting Paperclip

Paperclip is a Node.js server with a web UI. It keeps companies, agents, tasks and run history in PostgreSQL and agent workspaces on disk. On the internet it should run in authenticated mode with a fixed public URL, a session secret and a master key for the secrets it stores. On a fresh install in private mode, the first person who signs up and claims the instance becomes its admin.

This template creates your owner account at deploy, keeps sign-ups closed and turns off the first-visitor claim, and runs Paperclip with PostgreSQL 18 on Railway's private network, with every secret generated for you.

## Common Use Cases

- Running a team of coding agents on your repositories, with tasks, reviews and budgets
- Delegating research, writing and operations work to agents with clear roles and approvals
- Tracking what each agent did, what it cost and what is waiting for your approval
- Trying the "AI company" model without installing anything on your laptop
- A shared agent board for a small team

## Dependencies for Paperclip Hosting

- PostgreSQL 18
- An API key or account for at least one agent provider (Anthropic, OpenAI, ...)

### Deployment Dependencies

- Paperclip: https://github.com/paperclipai/paperclip
- Docker image: https://github.com/paperclipai/paperclip/pkgs/container/paperclip
- Deployment modes: https://github.com/paperclipai/paperclip/blob/master/doc/DEPLOYMENT-MODES.md

### Implementation Details

**What you set:** `OWNER_EMAIL`, the email you log in with (default `admin@example.com`). `OWNER_PASSWORD` is generated. Optional: `ANTHROPIC_API_KEY` and `OPENAI_API_KEY` for Claude Code and Codex agents (you can also add keys per agent in the UI).

**After deploy:**

1. Open the Paperclip URL and sign in with `OWNER_EMAIL` and the generated `OWNER_PASSWORD` (Variables tab of the Paperclip service).
2. Create your company, set its goal and hire your first agent.
3. Give the agent a provider key and assign it a task.
4. To add a teammate, set `PAPERCLIP_AUTH_DISABLE_SIGN_UP=false`, send them an invite from the company settings, and set it back to `true` once they have joined.

**This template:**

- Creates the owner (instance admin) on first start, so nobody else can claim your instance
- Keeps sign-ups closed (`PAPERCLIP_AUTH_DISABLE_SIGN_UP=true`)
- Runs in authenticated mode with public exposure, which turns off the "claim this instance" page that private mode shows the first visitor
- Uses the official image, pinned to Paperclip 2026.1117.0 instead of `latest`
- Generates the session secret and the master key that encrypts stored secrets
- Keeps agent workspaces and instance files on a volume, and PostgreSQL 18 on a volume with no public TCP proxy
- Applies database migrations on start, checks health on `/api/health` and restarts a crashed service
- Turns off Paperclip's anonymous usage telemetry (set `PAPERCLIP_TELEMETRY_DISABLED=0` to send it)

**Notes:** never change `PAPERCLIP_SECRETS_MASTER_KEY` after the first deploy, or stored secrets become unreadable. When you add a custom domain, set `PAPERCLIP_PUBLIC_URL` and `PAPERCLIP_ALLOWED_HOSTNAMES` to it. In public mode Paperclip turns off local stdio MCP servers and in-container provider logins; use API keys and remote (HTTP) MCP servers. Agents run inside the Paperclip container, so give it enough memory for the agent tools you use. Paperclip is MIT licensed. You are responsible for what your agents do and for the provider costs they create.

## Why Deploy Paperclip on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Paperclip on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
