# Deploy and Host opencode on Railway

opencode is the open-source AI coding agent. It reads your code, plans changes, edits files, runs commands and uses git, with Claude, GPT, Gemini, OpenRouter, local models or opencode's free models. Its web mode gives you the full agent in a browser, so you can work on your repositories from any device.

## About Hosting opencode

`opencode web` is a single process that serves the web UI and the API, and runs the agent's tools on the machine it runs on. A hosted instance needs a password on every route, a persistent workspace for repositories, persistent state for sessions and provider logins, development tools such as git, and a pinned version.

This template runs the official image at the stable 1.19.6 release. Its built-in login is protected by a generated password, the workspace and state are on a volume, and git, bash, SSH and curl are installed on start.

## Common Use Cases

- A coding agent in the browser that keeps working on a server while your laptop is closed
- Working on your repositories from a tablet, phone or locked-down work machine
- A shared remote server that the opencode CLI or desktop app attaches to
- Trying many model providers, including free models, from one agent
- Quick fixes, reviews and refactors on GitHub repositories without a local setup

## Dependencies for opencode Hosting

- A Railway volume for the workspace and state
- An API key for at least one model provider (optional; free models are available)

### Deployment Dependencies

- opencode: https://github.com/anomalyco/opencode
- Docs: https://opencode.ai/docs/
- Image: https://github.com/anomalyco/opencode/pkgs/container/opencode

### Implementation Details

**What you set:** nothing is required. Optional: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY` or `GEMINI_API_KEY`, `GH_TOKEN` for private repositories, and `OPENCODE_PACKAGES` for more tools (for example `nodejs npm python3`).

**After deploy:**

1. Open the opencode URL and log in as `opencode` with the generated `OPENCODE_SERVER_PASSWORD` (Variables tab).
2. Add a provider key, or start with a free model.
3. Clone a repository into `/data/workspace`, then choose Add project and open it.
4. Connect the CLI with `opencode attach https://YOUR-DOMAIN --password YOUR-PASSWORD`.

**This template:**

- Requires the password for the web UI, the API and every tool endpoint. Only the static web app manifest is public, for the healthcheck
- Keeps `/data/workspace` (your repositories) and `/data/home` (config, provider logins, sessions) on a volume, so they survive redeploys
- Pins opencode 1.19.6, the current stable release, and turns off auto-update
- Installs git, bash, openssh-client and curl on start, sets git defaults and supports `GH_TOKEN` for private repositories
- Uses the official image, with no custom build
- Checks health and restarts the service if it crashes

**Notes:** the agent runs commands as root in the container, with internet access. Keep the password secret, and use provider keys with spending limits. opencode's share feature can publish a session to opencode.ai, so only share what you want public. Upgrade by changing the image tag. opencode is MIT licensed. This template is not affiliated with the opencode team.

## Why Deploy opencode on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying opencode on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
