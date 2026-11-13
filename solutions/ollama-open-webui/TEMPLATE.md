# Deploy and Host Ollama + Open WebUI on Railway

Ollama runs open large language models such as Llama, Qwen, Gemma and Mistral on your own server. Open WebUI is a ChatGPT-style interface for them, with chat history, document chat (RAG), multiple users and roles. Together they give you a private AI chat with no API keys and no data sent to a third party.

## About Hosting Ollama + Open WebUI

Ollama downloads models to disk and loads them into memory to answer requests; it has no login of its own, so it must stay private. Open WebUI stores users and chats in a database and needs a fixed secret key and an admin account that only you control: on a fresh install, the first person to sign up becomes the admin. On shared cloud CPUs, Ollama also needs its thread count set to the service's vCPU limit, or it starts one thread per host core and answers very slowly.

This template runs Ollama privately with a starter model downloaded at deploy, Open WebUI with the admin account created for you and public sign-up off, and PostgreSQL for users and chats, all on Railway's private network with pinned, tested versions.

## Common Use Cases

- A private ChatGPT for a team, with models running in your own project
- Chat with internal documents without sending them to an AI provider
- Try open models (Llama, Qwen, Gemma) before choosing one for an app
- An OpenAI-compatible endpoint for your own apps on Railway's private network
- One interface for local models and cloud providers side by side

## Dependencies for Ollama + Open WebUI Hosting

- Ollama, with a persistent volume for downloaded models
- PostgreSQL 18

### Deployment Dependencies

- Ollama: https://github.com/ollama/ollama
- Open WebUI: https://github.com/open-webui/open-webui
- Model library: https://ollama.com/library
- Open WebUI documentation: https://docs.openwebui.com

### Implementation Details

**What you set:** `WEBUI_ADMIN_EMAIL`, the email you log in with (default `admin@example.com`; change it to your own). Optionally `OLLAMA_DEFAULT_MODEL` (default `llama3.2:3b`, 2 GB).

**After deploy:**

1. Wait about a minute until the Ollama logs show `model-setup: llama3.2:3b ready`.
2. Open the Open WebUI URL and log in with `WEBUI_ADMIN_EMAIL` and the generated `WEBUI_ADMIN_PASSWORD`.
3. Chat with the starter model, and pull more models from the model selector or Admin Panel → Settings → Models.
4. Add users under Admin Panel → Users.

**This template:**

- Sets Ollama's CPU threads to the service limit (`LLAMA_ARG_THREADS=8`): in our test, replies went from under 1 to about 35 tokens per second
- Downloads a starter model on first start and selects it for new chats; later starts skip the download
- Creates the Open WebUI admin on first start and keeps public sign-up off
- Keeps Ollama private: only Open WebUI is public, and it requires a login
- Caps Ollama's prompt cache at 1 GiB so it fits the plan's memory
- Stores models, chats and files on volumes, and users and chats in PostgreSQL
- Pins Ollama 0.40.16, Open WebUI v0.13.0 and PostgreSQL 18, with healthchecks on both apps

**Notes:** models run on CPU. The first reply after a deploy or after 10 idle minutes takes 30–60 seconds while the model loads. On Hobby (8 vCPU, 8 GB RAM, 5 GB volume per service), use small models of 1–4B parameters; on Pro, 7–14B models fit, and you should raise `LLAMA_ARG_THREADS` to the service's vCPU limit.

## Why Deploy Ollama + Open WebUI on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Ollama + Open WebUI on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
