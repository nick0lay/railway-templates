# Ollama + Open WebUI

Self-hosted [Ollama](https://github.com/ollama/ollama) with [Open WebUI](https://github.com/open-webui/open-webui) on Railway: run open models such as Llama, Qwen and Gemma on CPU and chat with them in a ChatGPT-style interface, with no API keys and no data leaving your project. A starter model is downloaded at deploy, the admin account is created for you, public sign-up is off, and Ollama is reachable only over the private network. Versions are pinned and tested.

<!-- Deploy button: add after publishing -->

## Architecture

```
                     You / your team
                       │ HTTPS
                       ▼
┌──────────────────────────────────────────────────────┐
│ Railway project                                      │
│                                                      │
│  Open WebUI :8080 (public, login required)           │
│    chat UI, users, documents (RAG)                   │
│    volume /app/backend/data                          │
│        │                     │                       │
│        ▼                     ▼                       │
│  Ollama :11434 (private)   Postgres :5432 (private)  │
│    runs models on CPU        users, chats, settings  │
│    volume /root/.ollama                              │
│    (downloaded models)                               │
└──────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Open WebUI | `ghcr.io/open-webui/open-webui:v0.13.0` | Chat UI and API (public, login required) |
| Ollama | `ollama/ollama:0.40.15` | Runs the models (private, no public domain) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Users, chats, settings (private) |

## What this template does differently

- **Fast replies on Railway's CPUs.** Ollama sizes its thread pool from the host's cores, not the service's limit. On Railway's 96-core hosts it starts 48 threads on an 8-vCPU service, and a small model answers at under 1 token per second. This template sets `LLAMA_ARG_THREADS=8`; in our test, the same model went from 0.5 to about 35 tokens per second.
- **A model is ready when you log in.** On first start, Ollama downloads `OLLAMA_DEFAULT_MODEL` (default `llama3.2:3b`, 2 GB) to its volume, and Open WebUI selects it for new chats. Later starts find the model and skip the download.
- **Admin account created at deploy.** On a fresh Open WebUI, the first person to sign up becomes the admin. This template creates the admin from `WEBUI_ADMIN_EMAIL` and a generated `WEBUI_ADMIN_PASSWORD`, and public sign-up stays off.
- **Ollama stays private.** Ollama has no login of its own, so it gets no public domain. Only Open WebUI is public, and it requires a login.
- **Bounded memory.** The prompt cache is capped at 1 GiB (`LLAMA_ARG_CACHE_RAM`); the default of 8 GiB is as much as the Hobby plan's whole memory limit.
- **Data persists.** Downloaded models on Ollama's volume, users and chats in Postgres on a volume, and uploaded files on Open WebUI's volume. `WEBUI_SECRET_KEY` is generated, so redeploys don't log anyone out.
- **Pinned versions and healthchecks** on Ollama (`/`) and Open WebUI (`/health`), and analytics off.

## After deploy

1. Wait until the Ollama logs show `model-setup: llama3.2:3b ready` (about a minute).
2. Open the Open WebUI URL and log in with `WEBUI_ADMIN_EMAIL` and the `WEBUI_ADMIN_PASSWORD` variable.
3. Start a chat. The starter model is already selected. The first reply after a deploy or after 10 idle minutes takes 30–60 seconds while Ollama loads the model into memory; later replies start within a second or two.
4. Add more models: type a model name from [ollama.com/library](https://ollama.com/library) (for example `qwen3:1.7b`) in the model selector and choose to pull it from Ollama.com, or use **Admin Panel → Settings → Models**.
5. Add users under **Admin Panel → Users** (the **+** button).

## Hardware and cost

Ollama runs models on CPU. As a rough guide, a model needs about as much RAM as its download size plus 1 GB.

| Plan | Per-service limits | What fits |
|---|---|---|
| Hobby | 8 vCPU, 8 GB RAM, 5 GB volume | One or two small models (1–4B parameters), for example `llama3.2:3b`, `qwen3:1.7b`, `gemma3:1b` |
| Pro | Up to 32 vCPU and 32 GB RAM; volumes can grow | 7–14B models such as `qwen3:8b` or `gemma3:12b`; raise `LLAMA_ARG_THREADS` to the service's vCPU limit |

Usage is billed by Railway for what the services use. Ollama uses CPU only while it answers, and it unloads a model from RAM 10 minutes after the last request (`OLLAMA_KEEP_ALIVE`). Open WebUI and Postgres idle at about 1 GB of RAM together. Railway's memory graph for Ollama also counts the file cache from model downloads, so it can show more than the model itself uses.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Open WebUI | `WEBUI_ADMIN_EMAIL` | (required) | Email of the admin account. You log in with it |
| Open WebUI | `WEBUI_ADMIN_PASSWORD` | generated | Read it after deploy. Applied only when the admin is created on first start |
| Open WebUI | `WEBUI_ADMIN_NAME` | `Admin` | Display name of the admin |
| Ollama | `OLLAMA_DEFAULT_MODEL` | `llama3.2:3b` | Downloaded on start if missing. Set it to another tag and redeploy Ollama to download that model too |
| Ollama | `LLAMA_ARG_THREADS` | `8` | CPU threads per model. Match the service's vCPU limit |
| Ollama | `OLLAMA_KEEP_ALIVE` | `10m` | How long a model stays in RAM after the last request |
| Ollama | `LLAMA_ARG_CACHE_RAM` | `1024` | Prompt cache limit in MiB |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Open WebUI | `OLLAMA_BASE_URL` | `http://${{Ollama.RAILWAY_PRIVATE_DOMAIN}}:11434` | Private network |
| Open WebUI | `ENABLE_OLLAMA_API` | `true` | Use the Ollama service |
| Open WebUI | `DEFAULT_MODELS` | `${{Ollama.OLLAMA_DEFAULT_MODEL}}` | Model for new chats. Saved on first start; change it later in Admin Settings |
| Open WebUI | `ENABLE_OPENAI_API` | `false` | No cloud provider by default. Add one in Admin Panel → Settings → Connections to use cloud models next to Ollama |
| Open WebUI | `AIOHTTP_CLIENT_TIMEOUT` | `900` | Long answers from CPU models can take minutes |
| Open WebUI | `WEBUI_SECRET_KEY` | generated | Signs logins. Changing it logs everyone out |
| Open WebUI | `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Private network |
| Open WebUI | `DATA_DIR`, `WEBUI_URL`, `PORT` | | Volume path, public URL, port 8080 |
| Ollama | `OLLAMA_HOST` | `::` | Listen on the private network (IPv6) |
| Ollama | `PORT` | `11434` | Used by the healthcheck |
| Ollama | `OLLAMA_SETUP_SH` | script | Downloads `OLLAMA_DEFAULT_MODEL` on start if it's missing |

## Upgrading

Change the image tags (for example `ollama/ollama:0.40.16` or `ghcr.io/open-webui/open-webui:v0.13.1`). Downloaded models stay on the volume. Open WebUI migrates its database on start and can't go back to an older version after that; read the [Open WebUI](https://github.com/open-webui/open-webui/releases) and [Ollama](https://github.com/ollama/ollama/releases) release notes first.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Replies are very slow (under a few tokens per second) | `LLAMA_ARG_THREADS` is missing or higher than the service's vCPU limit. Set it to the limit |
| No models in the model list | The first download is still running; check the Ollama logs for `model-setup`. If it failed, redeploy Ollama to retry |
| Downloading another model fails with an error | Ollama's volume is full. Hobby volumes hold 5 GB; delete a model in Admin Panel → Settings → Models, or move to Pro and grow the volume |
| Ollama restarts while loading a model | Out of memory. Use a smaller model, or raise the memory limit on Pro |
| Login fails with the generated password | The admin is created on the first start only. If you changed `WEBUI_ADMIN_PASSWORD` or `WEBUI_ADMIN_EMAIL` later, use the old values |
| Everyone is logged out after a redeploy | `WEBUI_SECRET_KEY` was changed or removed |

## License

Ollama is [MIT](https://github.com/ollama/ollama/blob/main/LICENSE). Open WebUI uses its own [license](https://github.com/open-webui/open-webui/blob/main/LICENSE) (BSD-3-Clause plus a branding clause): you can self-host it, but keep the "Open WebUI" branding unless you qualify for an exception. Each model has its own license; `llama3.2:3b` uses the [Llama 3.2 Community License](https://www.llama.com/llama3_2/license/).

## Testing

Tested on 2026-11-06 with Ollama 0.40.15 and Open WebUI v0.13.0 in throwaway Railway projects. All three services were healthy; the starter model downloaded in about 30 seconds and the admin was created at first start. Requests without a login, a stranger's sign-up and a wrong password were refused, and the admin logged in. Ollama had no public domain. The starter model was listed in Open WebUI and answered chats through Open WebUI's API (about 35 tokens per second once loaded). After redeploying all three services, the model download was skipped, and the admin login, the saved chat and chatting still worked. Before `LLAMA_ARG_THREADS` was set, the same setup answered at under 1 token per second and a chat timed out. Not tested: the browser UI (only its API), model pulls from the model selector, and Pro-plan sizes.
