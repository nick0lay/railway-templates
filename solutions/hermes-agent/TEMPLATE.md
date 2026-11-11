# Deploy and Host Hermes Agent on Railway

Hermes Agent is the open-source, self-improving AI agent from Nous Research. It remembers you across sessions, writes and refines its own skills, runs scheduled tasks, and talks to you from Telegram, Discord, Slack, WhatsApp, Signal or the web dashboard. It works with any model provider: OpenRouter, Anthropic, OpenAI, Google, Nous Portal or your own endpoint.

## About Hosting Hermes Agent

Hermes runs as a long-lived gateway process that keeps its memory, skills, sessions and configuration on disk. In production it needs a persistent volume, an always-on process, and a dashboard that only you can open: since June 2026, Hermes refuses to serve the dashboard on a public address without an auth provider.

This template runs the official `nousresearch/hermes-agent` image, pinned to v0.23.1, with the gateway and the web dashboard supervised together. The dashboard is behind a username and a generated password, and all state lives on a Railway volume.

## Common Use Cases

- A personal AI assistant you message from Telegram or Discord, with memory that grows over time
- Scheduled automations in plain language: daily briefings, reports, reminders, delivered to your chat
- A coding and research agent that works on a cloud machine while you are away
- Moving from OpenClaw, Claude Code or Codex: Hermes can import their settings, memories and skills

## Dependencies for Hermes Agent Hosting

- Persistent volume for memory, skills, sessions and configuration
- A model provider key (OpenRouter, Anthropic, OpenAI, Google or Nous Portal)

### Deployment Dependencies

- Hermes Agent: https://github.com/NousResearch/hermes-agent
- Documentation: https://hermes-agent.nousresearch.com/docs
- Image: https://hub.docker.com/r/nousresearch/hermes-agent

### Implementation Details

**What you set:** nothing is required. Optionally, `OPENROUTER_API_KEY` for the model, and `TELEGRAM_BOT_TOKEN` with `TELEGRAM_ALLOWED_USERS` (or the Discord pair) to chat from your phone.

**After deploy:**

1. Open the service URL and log in as `admin` with the generated `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` variable.
2. Add a model provider key and pick a model in the dashboard, or set `OPENROUTER_API_KEY`.
3. To chat from Telegram, create a bot with @BotFather, set `TELEGRAM_BOT_TOKEN` and your user ID in `TELEGRAM_ALLOWED_USERS`, and redeploy.

**This template:**

- Runs the official image, pinned to Hermes Agent v0.23.1, instead of `latest` or a source build
- Starts the messaging gateway and the web dashboard together under the image's own process supervisor
- Puts the dashboard behind a login with a generated password and session secret
- Keeps memory, skills, sessions and configuration on a volume, so a redeploy keeps everything
- Checks health on `/api/status`, so Railway only routes traffic to a running agent

**Notes:** when you connect a bot, set its allowlist (`TELEGRAM_ALLOWED_USERS`, `DISCORD_ALLOWED_USERS`) so only you can use the agent. Upgrade by changing the image tag; don't run `hermes update` inside the container, as changes there are lost on redeploy.

## Why Deploy Hermes Agent on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Hermes Agent on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
