# Hermes Agent 0.23

Self-hosted [Hermes Agent](https://github.com/NousResearch/hermes-agent) on Railway: the open-source, self-improving AI agent from Nous Research. It keeps memory across sessions, writes its own skills, runs scheduled tasks, and talks to you from Telegram, Discord, Slack, WhatsApp, Signal or the web dashboard. This template runs the official image pinned to v0.23.1, puts the dashboard behind a generated password, and keeps all state on a volume.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/hermes-agent-023?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
          You (browser)              Telegram / Discord / Slack ...
               │ HTTPS                          │ bot APIs (outbound)
               ▼                                ▲
┌────────────────────────────────────────────────────────────┐
│ Railway project                                            │
│                                                            │
│  hermes-agent :8080 (public)                               │
│    s6 supervisor (from the official image)                 │
│      ├─ dashboard :8080   login required, /api/status open │
│      └─ gateway           messaging platforms, cron,       │
│                           API server on 127.0.0.1:8642     │
│    volume /opt/data: config, memory, skills, sessions      │
└────────────────────────────────────────────────────────────┘
               │
               ▼
     Model providers (OpenRouter, Anthropic, OpenAI, ...)
```

## Services

| Service | Source | Role |
|---------|--------|------|
| hermes-agent | `nousresearch/hermes-agent:v0.23.1` | Gateway and web dashboard (public, login required) |

## What this template does differently

- **Official image, pinned.** `nousresearch/hermes-agent:v0.23.1` instead of `latest`, a wrapper repo or a source build that can hit GitHub rate limits during the build.
- **Gateway and dashboard together.** The start command goes through the image's own entrypoint, so its s6 supervisor runs both and restarts either one if it crashes.
- **Dashboard behind a login.** Username `admin` and a generated password, with a generated session secret so logins survive restarts. Since June 2026 Hermes refuses to serve a public dashboard without an auth provider, and this sets one up for you.
- **State on a volume.** The volume is mounted at `/opt/data`, the image's own `HERMES_HOME`, so config, memory, skills, sessions and cron jobs survive a redeploy without any path remapping.
- **Healthcheck** on `/api/status`, so Railway only routes traffic to a running agent.

## After deploy

1. Open the `hermes-agent` URL and log in as `admin` with the `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` variable.
2. Add a model provider and pick a model in the dashboard. Or set `OPENROUTER_API_KEY` before deploying.
3. To chat from your phone, connect a messaging platform:
   - **Telegram:** create a bot with @BotFather, then set `TELEGRAM_BOT_TOKEN` and your numeric user ID in `TELEGRAM_ALLOWED_USERS`.
   - **Discord:** set `DISCORD_BOT_TOKEN` and `DISCORD_ALLOWED_USERS`.
   - Slack, WhatsApp, Signal and email are configured in the dashboard or with the variables from the [messaging docs](https://hermes-agent.nousresearch.com/docs/user-guide/messaging).
4. Redeploy after changing variables. Then message your bot.

Always set the allowlist for a bot you connect, so only you can use the agent and spend your model credits.

## Variables

### User-configurable

| Variable | Default | Notes |
|---|---|---|
| `HERMES_DASHBOARD_BASIC_AUTH_USERNAME` | `admin` | Dashboard login |
| `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` | generated | Read it after deploy. Change it here and redeploy to rotate it |
| `OPENROUTER_API_KEY` | empty (optional) | Model access through OpenRouter. Other providers can be added in the dashboard |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_ALLOWED_USERS` | empty (optional) | Telegram bot and the comma-separated user IDs allowed to use it |
| `DISCORD_BOT_TOKEN`, `DISCORD_ALLOWED_USERS` | empty (optional) | Discord bot and the allowed user IDs |

Any other variable Hermes reads (see its `.env.example`) can be added to the service.

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `HERMES_DASHBOARD_BASIC_AUTH_SECRET` | generated | Signs dashboard sessions. Changing it logs everyone out |
| `HERMES_DASHBOARD` | `1` | Runs the dashboard next to the gateway |
| `HERMES_DASHBOARD_HOST` | `0.0.0.0` | Lets Railway's proxy reach the dashboard |
| `HERMES_DASHBOARD_PORT` | `${{PORT}}` | The dashboard listens on the public port |
| `PORT` | `8080` | |

## Upgrading

Change the image tag (for example `nousresearch/hermes-agent:v0.23.2`) and redeploy. Hermes migrates its config on start. Don't run `hermes update` inside the container: changes to the container are lost on the next redeploy, and the saved config can end up ahead of the image. Read the [release notes](https://github.com/NousResearch/hermes-agent/releases) first.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Logs show `Auxiliary Nous client unavailable` warnings | No model provider is set yet. Add one in the dashboard or set `OPENROUTER_API_KEY` |
| The bot doesn't answer in Telegram or Discord | Check that your user ID is in the allowlist variable and that you redeployed after setting the token |
| Dashboard login fails | Use the current `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` value. A changed password applies after a redeploy |
| `/api/status` is reachable without a login | By design: it reports the version and gateway state for the healthcheck. Everything else needs the login |
| Out of memory during long agent runs | Raise the service's memory limit. The browser and terminal tools use extra memory |

## Testing

Tested on 2026-11-11 with Hermes Agent v0.23.1 in throwaway Railway projects, from the template draft and then from the published template. The service became healthy, and `/api/status` reported version 0.23.1 with the gateway running. Requests to the dashboard API without a login were refused, a wrong password was refused, and the generated password logged in. After a redeploy the service was healthy again and the existing login session still worked. A chat with a real model provider was not tested.
