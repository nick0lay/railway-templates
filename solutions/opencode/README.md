# opencode 1.19

Self-hosted [opencode](https://github.com/anomalyco/opencode) on Railway: the open-source AI coding agent, used from your browser. This template runs `opencode web` from the official image at a pinned stable version. A password protects every page and the API. Your projects, sessions and provider logins are kept on a volume, and git comes preinstalled.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/opencode-119?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
                 You (browser, opencode CLI or app)
                               │ HTTPS + password (HTTP Basic auth)
                               ▼
┌──────────────────────────────────────────────────────────┐
│ Railway project                                          │
│                                                          │
│  opencode :4096 (public)                                 │
│    web UI and API in one process (`opencode web`)        │
│    runs tools (shell, file edits, git) in the workspace  │
│        │                                                 │
│        ▼                                                 │
│  Volume /data                                            │
│    /data/workspace   your repositories and files         │
│    /data/home        opencode config, provider logins,   │
│                      sessions database                   │
└──────────────────────────────────────────────────────────┘
          │ HTTPS to the model providers you configure
          ▼
   Anthropic, OpenAI, OpenRouter, Gemini, opencode Zen, ...
```

## Services

| Service | Source | Role |
|---------|--------|------|
| opencode | `ghcr.io/anomalyco/opencode:1.19.6` | Web UI, API and agent runtime (public, password-protected, volume at `/data`). Healthcheck `/site.webmanifest` |

## What this template does differently

- **A password on every route.** opencode's built-in HTTP Basic auth is turned on with a generated `OPENCODE_SERVER_PASSWORD`. Without it, the web UI, the API and the shell and file tools all answer 401. Only the web app manifest and its two icons are public; they're static files with no data, and the healthcheck uses the manifest. opencode has no user accounts, so there's nothing anyone could sign up for.
- **Persistent workspace and state.** `HOME` and the workspace are on the `/data` volume. Cloned repositories, sessions, opencode config and provider logins (`/connect`) survive redeploys.
- **Stable, pinned version.** It runs 1.19.6, the current stable release, instead of `latest`. Auto-update is off. The 2.x line is a rewrite and isn't marked as the stable release upstream yet.
- **Development tools.** The official image has only opencode and ripgrep. On every start, the template adds git, bash, an SSH client and curl, and sets git defaults. Add more packages with `OPENCODE_PACKAGES`, for example `nodejs npm python3`.
- **GitHub access in one variable.** Set `GH_TOKEN` to clone and push private repositories over HTTPS.
- **Official image, no custom build.** Upgrades are a tag change.

## After deploy

1. Open the `opencode` URL. Your browser asks for a login: use `opencode` as the user name and the `OPENCODE_SERVER_PASSWORD` variable from the `opencode` service.
2. Add a model. Set `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY` or `GEMINI_API_KEY` on the service, or connect a provider in the UI settings. opencode also offers a few free models through opencode Zen, so you can try it without a key.
3. Get code into the workspace. Ask the agent to `git clone` your repository into `/data/workspace`, or run the command yourself in a session's shell. Then choose **Add project** and open `/data/workspace/your-repo`.
4. Work with the agent from the browser. Changes stay on the volume, so commit and push them from the session when you're done.

To connect the opencode CLI on your computer to this server, run `opencode attach https://YOUR-DOMAIN --password YOUR-PASSWORD`, or set `OPENCODE_SERVER_PASSWORD` locally first.

## Variables

### User-configurable

| Variable | Default | Notes |
|---|---|---|
| `OPENCODE_SERVER_PASSWORD` | generated | Login password for the UI and API. Change it to rotate access |
| `OPENCODE_SERVER_USERNAME` | `opencode` | Login user name |
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `GEMINI_API_KEY` | empty | Optional model provider keys. Other providers can be added in the UI |
| `GH_TOKEN` | empty | Optional GitHub token for cloning and pushing private repositories over HTTPS |
| `OPENCODE_PACKAGES` | `git bash openssh-client curl` | Alpine packages installed on every start, for example `nodejs npm python3 go` |
| `GIT_USER_NAME`, `GIT_USER_EMAIL` | `opencode`, `opencode@users.noreply.github.com` | Author of commits made in the workspace (set once in the git config on the volume) |

opencode reads more settings from `/data/home/.config/opencode/opencode.json` (models, agents, MCP servers, permissions). See the [opencode docs](https://opencode.ai/docs/).

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `HOME` | `/data/home` | Config, provider logins and the sessions database on the volume |
| `OPENCODE_WORKSPACE` | `/data/workspace` | Working directory where the server starts |
| `OPENCODE_DISABLE_AUTOUPDATE` | `true` | Keeps the pinned version |
| `OPENCODE_START_SH` | script | Installs packages, sets git defaults and starts `opencode web --hostname :: --port $PORT` |
| `PORT` | `4096` | |

## Security notes

- The agent runs commands as root inside the container, with access to the volume and the internet. Treat the password like an SSH key, and use provider keys with spending limits.
- Anyone with the password controls the agent and can read everything in the workspace, including the `GH_TOKEN` and provider keys.
- opencode's share feature can publish a session to opencode.ai. Only share sessions that you want to make public.

## Upgrading

Change the image tag to a newer 1.x release (see [releases](https://github.com/anomalyco/opencode/releases)). Your workspace and sessions stay on the volume.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| The browser keeps asking for the password | Use the user name `opencode` (or your `OPENCODE_SERVER_USERNAME`) and the exact `OPENCODE_SERVER_PASSWORD` value |
| `git: not found` or a missing tool | Add the package to `OPENCODE_PACKAGES` and redeploy. The deploy log shows `start: installed ...` |
| No models to choose | Add a provider key or connect a provider in the UI settings |
| Private repository clone fails | Set `GH_TOKEN`, or add an SSH key under `/data/home/.ssh` |
| The UI shows no project | Choose **Add project** and open a folder under `/data/workspace` |

## Testing

Tested on Railway on 2026-11-23 with opencode 1.19.6. The service became healthy in about 30 seconds, and idle memory was about 0.2 GB. Without the password, or with a wrong one, the UI, the API, unknown asset paths and the file and config endpoints returned 401. With the password, the web UI loaded in a browser without errors. A session ran a shell command in the workspace with git installed. opencode's free built-in model wrote a file with its write tool, and the file could be read back. After a redeploy, the password still worked, and the sessions and both files were still there. Not tested: paid model providers, `GH_TOKEN` and the CLI attach.

## License

opencode is licensed under the [MIT License](https://github.com/anomalyco/opencode/blob/dev/LICENSE). This template is not affiliated with the opencode team. You are responsible for the code, keys and commands run on your instance.
