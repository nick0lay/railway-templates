# Open Notebook + Kokoro

Self-hosted [Open Notebook](https://github.com/lfnovo/open-notebook) on Railway: an open-source alternative to Google NotebookLM. Collect sources into notebooks, chat with them with citations, write notes, and turn a notebook into a podcast. This template adds a private [Kokoro](https://github.com/remsky/Kokoro-FastAPI) text-to-speech service and sets it up as the podcast voice model on first start, so podcast audio is free. The app is password-protected from the start and every version is pinned and tested.

<!-- deploy button added after publish -->

## Architecture

```
                 You / API clients
                        │ HTTPS
                        ▼
┌──────────────────────────────────────────────────────────┐
│ Railway project                                          │
│                                                          │
│  Open Notebook :8502 (public, password)                  │
│    web app (Next.js), forwards /api to the API :5055     │
│    API (FastAPI) and background worker                   │
│    uploads on a volume (/app/data)                       │
│         │                              │                 │
│         ▼ ws :8000                     ▼ http :8880      │
│  SurrealDB (private, volume)    Kokoro (private)         │
│  notebooks, sources, notes,     text-to-speech for       │
│  embeddings, job queue          podcasts, CPU            │
└──────────────────────────────────────────────────────────┘
          Chat, embeddings and podcast scripts go to the
          AI provider you add in the app (OpenAI, ...)
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Open Notebook | `lfnovo/open_notebook:1.15.1` | Web app, API and background worker in one container (public, password). Uploaded files on a volume |
| SurrealDB | `surrealdb/surrealdb:v2.7.0` | Database for notebooks, sources, notes, embeddings and the job queue (private, volume) |
| Kokoro | `ghcr.io/remsky/kokoro-fastapi-cpu:v0.9.2` | OpenAI-compatible text-to-speech with 70+ voices, model included in the image (private) |

## What this template does differently

- **Password on from the start.** Without `OPEN_NOTEBOOK_PASSWORD`, Open Notebook has no login, and anyone with the URL can use it and its stored provider keys. The password is generated.
- **Encryption key generated.** Provider keys you save in **Manage → Models** are encrypted with `OPEN_NOTEBOOK_ENCRYPTION_KEY`. Without it, the app can't save keys at all.
- **Free podcast voices.** Kokoro runs as a private service. On first start, the template registers it in Open Notebook as a credential and a text-to-speech model, makes it the default text-to-speech model, and switches the built-in speaker profiles to Kokoro voices. Out of the box, those profiles use OpenAI voices and need an OpenAI key billed per minute.
- **One URL.** The web app forwards `/api` to the API in the same container, so the browser, the REST API and the API docs all use the public URL. Port 5055 isn't exposed.
- **Private database.** SurrealDB has no public URL and a generated user and password, instead of the `root`/`root` of the upstream compose file.
- **Pinned versions.** Open Notebook 1.15.1, SurrealDB 2.7.0 and Kokoro-FastAPI 0.9.2 instead of `v1-latest`, `v2` and `latest`.
- **Healthchecks** on `/api/auth/status` (passes when the web app and the API both answer), and on `/health` for SurrealDB and Kokoro.

## After deploy

1. Open the Open Notebook URL and log in with the `OPEN_NOTEBOOK_PASSWORD` variable of the `Open Notebook` service.
2. Go to **Manage → Models**. Add a provider (OpenAI, Anthropic, Google, OpenRouter, Ollama and others) with your API key, then choose the default chat model and the embedding model. The text-to-speech default is already Kokoro.
3. Create a notebook and add sources: files, links, YouTube videos or text.
4. For a podcast, open **Podcasts**, choose an episode profile and generate. The speaker profiles already use Kokoro voices; the outline and the script come from your chat model. To change a voice, edit the speaker profile under **Podcasts → Profiles** and set a Kokoro voice ID such as `af_heart`, `am_michael` or `bf_emma`.
5. For scripts, call `https://<your-url>/api/...` (for example `/api/notebooks`) with the header `Authorization: Bearer <OPEN_NOTEBOOK_PASSWORD>`.

## Variables

### User-configurable

| Variable | Default | Notes |
|---|---|---|
| `OPEN_NOTEBOOK_PASSWORD` | generated | Password for the web app and the API. You can change it and redeploy |
| `TTS_BATCH_SIZE` | `2` | Text-to-speech requests sent at once per podcast. Kokoro on CPU handles a few at a time |
| `ESPERANTO_TTS_TIMEOUT` | `600` | Seconds per text-to-speech request |
| `LOGURU_LEVEL` | `INFO` | Log level of the API and worker |

AI provider keys aren't set with variables: add them in **Manage → Models**.

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `OPEN_NOTEBOOK_ENCRYPTION_KEY` | generated | Encrypts the provider keys stored in the database. **Don't change it after you save keys**: they can't be decrypted with a new one |
| `API_URL`, `CORS_ORIGINS` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | The browser calls the API through the public URL. Change both if you add a custom domain |
| `SURREAL_URL` | `ws://${{SurrealDB.RAILWAY_PRIVATE_DOMAIN}}:8000/rpc` | Private network |
| `SURREAL_USER`, `SURREAL_PASSWORD` | `${{SurrealDB.SURREAL_USER}}`, `${{SurrealDB.SURREAL_PASS}}` | Generated on the SurrealDB service |
| `SURREAL_NAMESPACE`, `SURREAL_DATABASE` | `open_notebook` | Set explicitly, as upstream recommends: the API and the job queue have different defaults |
| `KOKORO_BASE_URL` | `http://${{Kokoro.RAILWAY_PRIVATE_DOMAIN}}:8880/v1` | Kokoro over the private network, registered on first start |
| `ON_SETUP_PY` | script | Run by the start command to register Kokoro on first start. Later starts log `kokoro-setup: already set up, skipped` |
| `PORT` | `8502` | The web app; the public domain points here |
| SurrealDB: `SURREAL_BIND`, `SURREAL_PATH`, `PORT`, `RAILWAY_RUN_UID` | `[::]:8000`, `rocksdb:/data/open-notebook.db`, `8000`, `0` | Listen on the private network, store data on the volume |

## Custom domain

Add the domain to the `Open Notebook` service, then set `API_URL` and `CORS_ORIGINS` to `https://your-domain` and redeploy.

## Upgrading

Change the image tag of the `Open Notebook` service (for example `lfnovo/open_notebook:1.16.0`). Open Notebook migrates the database on start. Read the [release notes](https://github.com/lfnovo/open-notebook/releases) first and back up the SurrealDB volume before upgrading. Kokoro has no data and can be upgraded freely.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| "Invalid password" | Use the current `OPEN_NOTEBOOK_PASSWORD` of the `Open Notebook` service. The browser keeps the password; sign out and log in again after changing it |
| Chat or "Ask" says no model is configured | Add a provider in **Manage → Models** and pick the default chat and embedding models |
| "Encryption key not configured" | `OPEN_NOTEBOOK_ENCRYPTION_KEY` was removed. Restore the old value, or saved keys can't be decrypted |
| Kokoro isn't listed in Manage → Models | The first-start setup didn't finish. Look for `kokoro-setup:` in the `Open Notebook` logs. You can add it by hand: provider **OpenAI Compatible**, base URL `http://kokoro.railway.internal:8880/v1`, model `kokoro`, type TTS |
| Podcast fails with a voice error | The speaker profile uses a voice Kokoro doesn't have. Use a Kokoro voice ID (`af_heart`, `am_michael`, `bf_emma`, ...) |
| Podcast audio is slow | Kokoro runs on CPU. Keep `TTS_BATCH_SIZE` low; give the Kokoro service more CPU in its settings |
| The web app loads but requests fail | `API_URL` doesn't match the URL you open. Set it, and `CORS_ORIGINS`, to your public URL |

## Testing

Tested on 2026-11-06 with Open Notebook 1.15.1 in a throwaway Railway project, from the config: all three services healthy, and on first start the setup step registered Kokoro as a credential and a text-to-speech model, made it the default, and switched the three built-in speaker profiles to Kokoro voices. The web app loaded. The API refused requests without a password and with a wrong password, and accepted the generated one. A notebook, a text source and an uploaded file were created, and the file was downloaded back. Open Notebook's model test generated speech through Kokoro over the private network (`Speech generation successful`; Kokoro logged `POST /v1/audio/speech 200`). SurrealDB and Kokoro have no public URL. After redeploying all services, the notebook, the sources, the uploaded file, the Kokoro model and the speaker profiles were still there, and the setup step skipped itself. A full podcast wasn't generated, because it needs an AI provider key for the script.
