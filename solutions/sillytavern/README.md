# SillyTavern 1.19

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/sillytavern-119?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

Self-hosted [SillyTavern](https://github.com/SillyTavern/SillyTavern) on Railway: the chat and roleplay frontend for large language models. This template runs the official image at a pinned stable version. A generated password protects every page and API call, and config, chats, characters, settings, server plugins and global extensions are kept on one volume.

## Architecture

```
                     You (browser)
                          │ HTTPS + password (HTTP Basic auth)
                          ▼
┌──────────────────────────────────────────────────────────┐
│ Railway project                                          │
│                                                          │
│  SillyTavern :8000 (public)                              │
│    web UI and API in one Node.js process                 │
│        │                                                 │
│        ▼                                                 │
│  Volume /data                                            │
│    /data/config       config.yaml                        │
│    /data/data         characters, chats, settings,       │
│                       API keys, per-user extensions      │
│    /data/plugins      server plugins                     │
│    /data/extensions   extensions installed for all users │
└──────────────────────────────────────────────────────────┘
          │ HTTPS to the model APIs you connect
          ▼
   OpenAI, Claude, Gemini, OpenRouter, DeepSeek, Ollama, KoboldCpp, ...
```

## Services

| Service | Source | Role |
|---------|--------|------|
| SillyTavern | `ghcr.io/sillytavern/sillytavern:1.19.1` | Web UI and API (public, password-protected, volume at `/data`). No healthcheck: every route needs the password |

## What this template does differently

- **A password on every route.** Basic authentication is on with a generated password. Without it, the UI, the API, the CSRF token endpoint and even the static files answer 401. Failed logins are limited to 5 per minute per visitor IP, taken from Railway's proxy headers.
- **Everything persistent on one volume.** The start command links `config/`, `data/`, `plugins/` and `public/scripts/extensions/third-party/` to the `/data` volume before running the image's own entrypoint. Settings, chats, characters, API keys, server plugins and extensions installed for all users survive redeploys. Templates that mount only `data/` lose global extensions and plugins on every redeploy.
- **Railway-ready networking.** The IP whitelist is off (Railway's proxy addresses change, so it would lock you out), the server listens on all interfaces, and the untrusted-host warning for the Railway domain is silenced.
- **Stable, pinned version.** It runs 1.19.1, the current stable release, instead of `latest`.
- **Official image, no custom build.** Upgrades are a tag change.

## After deploy

1. Open the SillyTavern URL. Your browser asks for a login: use `user` and the `SILLYTAVERN_BASICAUTHUSER_PASSWORD` variable from the `SillyTavern` service.
2. Open **API Connections** (the plug icon), choose a provider (Chat Completion for OpenAI, Claude, Gemini, OpenRouter and others; Text Completion for KoboldCpp, Ollama, text-generation-webui), paste your key or server URL and connect.
3. Choose a character from the character list, or import one, and start chatting.

### Several users

SillyTavern can give each person their own characters, chats and settings:

1. Set `SILLYTAVERN_ENABLEUSERACCOUNTS` to `true` on the service and redeploy.
2. Log in (basic auth still applies), open **User Settings** > **Admin Panel**, set a password for `default-user` and create the other users.
3. Optional: to let each person log in with their own name and password instead of the shared one, set `SILLYTAVERN_PERUSERBASICAUTH` to `true` and redeploy. Do this only after every user has a password, or users without one can't log in.

## Variables

### User-configurable

| Variable | Default | Notes |
|---|---|---|
| `SILLYTAVERN_BASICAUTHUSER_PASSWORD` | generated | Login password. Change it to rotate access |
| `SILLYTAVERN_BASICAUTHUSER_USERNAME` | `user` | Login user name |

SillyTavern reads every `config.yaml` key from an environment variable named `SILLYTAVERN_` plus the key in capitals, with dots replaced by underscores (for example `SILLYTAVERN_ENABLESERVERPLUGINS=true`). You can also edit `/data/config/config.yaml`; environment variables win over the file. See the [SillyTavern docs](https://docs.sillytavern.app/administration/config-yaml/).

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `SILLYTAVERN_BASICAUTHMODE` | `true` | Password on every route |
| `SILLYTAVERN_WHITELISTMODE` | `false` | The IP whitelist can't work behind Railway's proxy |
| `SILLYTAVERN_RATELIMITING_PREFERREALIPHEADER` | `true` | Rate-limit failed logins per visitor, not per proxy |
| `SILLYTAVERN_HOSTWHITELIST_SCAN` | `false` | No warning for every request to the Railway domain |
| `SILLYTAVERN_BROWSERLAUNCH_ENABLED` | `false` | No browser inside the container |
| `SILLYTAVERN_PORT`, `PORT` | `8000` | |
| `SILLYTAVERN_START_SH` | script | Links config, data, plugins and extensions to `/data`, then runs the image entrypoint |

## Security notes

- Anyone with the password can read every chat and use the API keys saved in SillyTavern. Keep it secret, and use provider keys with spending limits.
- Extensions and server plugins run code on your instance. Install only ones you trust.

## Upgrading

Change the image tag to a newer release (see [releases](https://github.com/SillyTavern/SillyTavern/releases)) and redeploy. Your data stays on the volume, and SillyTavern adds new config keys to `config.yaml` on start.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| The browser keeps asking for the password | Use `user` (or your `SILLYTAVERN_BASICAUTHUSER_USERNAME`) and the exact password from the Variables tab |
| `429 Too Many Requests` | More than 5 wrong logins in a minute. Wait a minute and try again |
| "Invalid CSRF token" or a login prompt after a redeploy | Reload the page. Browser sessions end on every redeploy, and a page left open needs a fresh token |
| Users can't log in after turning on per-user login | Turn off `SILLYTAVERN_PERUSERBASICAUTH`, set a password for every user in the Admin Panel, then turn it on again |
| An extension is gone after a redeploy | Extensions installed for all users or for one user are on the volume. Check that the volume is still attached at `/data` |

## Testing

Tested on Railway on 2026-11-23 with SillyTavern 1.19.1. The service was running about 30 seconds after the deploy started, and idle memory was about 0.15 GB. Without the password, the UI, the API, the CSRF token endpoint and static files returned 401, and a wrong password or user name was refused. With the password, the UI loaded, settings were saved and read back with a CSRF token, a character was created, and an extension was installed for all users. After a redeploy, the password still worked, and the settings, the character, the extension and `config.yaml` were still on the volume. Not tested: connecting a model provider, chat generation and user accounts mode.

## License

SillyTavern is licensed under the [GNU AGPL-3.0](https://github.com/SillyTavern/SillyTavern/blob/release/LICENSE). This template is not affiliated with the SillyTavern team.
