# Deploy and Host Open WebUI on Railway

Open WebUI is an open-source, ChatGPT-style interface for large language models. It works with OpenAI and any OpenAI-compatible API (OpenRouter, Groq, LiteLLM and others) as well as Ollama, and adds chat history, document chat (RAG), web search, tools, image generation and multiple users with roles.

## About Hosting Open WebUI

Open WebUI is a Python web app that stores users, chats and settings in a database and keeps uploaded files, the document index and the embedding model on disk. In production it needs PostgreSQL, a persistent volume, a fixed secret key so logins survive restarts, and an admin account that only you control: on a fresh install, the first person to sign up becomes the admin.

This template creates the admin account at deploy with your email and a generated password, turns public sign-up off, and runs Open WebUI with PostgreSQL over Railway's private network, a volume for files and a pinned, tested version.

## Common Use Cases

- A private ChatGPT for your team with your own API keys
- One interface for several providers: OpenAI, Claude and Gemini through OpenRouter, open models through Groq
- Chat with your documents: upload PDFs and notes into knowledge bases
- A front end for a LiteLLM gateway or a self-hosted Ollama server
- Shared prompts, tools and custom models for a team

## Dependencies for Open WebUI Hosting

- PostgreSQL 18
- Persistent volume for uploads, the document index and the embedding model

### Deployment Dependencies

- Open WebUI: https://github.com/open-webui/open-webui
- Documentation: https://docs.openwebui.com
- Image: https://github.com/open-webui/open-webui/pkgs/container/open-webui

### Implementation Details

**What you set:** `WEBUI_ADMIN_EMAIL`, the email you log in with. Optionally `OPENAI_API_KEY` (and `OPENAI_API_BASE_URL` for another provider); you can also add providers later in Admin Settings.

**After deploy:**

1. Open the Open WebUI URL and log in with `WEBUI_ADMIN_EMAIL` and the generated `WEBUI_ADMIN_PASSWORD`.
2. Add a provider under Admin Panel → Settings → Connections, if you didn't set a key at deploy.
3. Add users under Admin Panel → Users.

**This template:**

- Creates the admin account on first start and keeps public sign-up off, so nobody else can claim your instance
- Generates a persistent `WEBUI_SECRET_KEY`, so redeploys don't log everyone out
- Keeps users and chats in PostgreSQL on a volume, and files, the document index and the embedding model on a second volume
- Connects to PostgreSQL over the private network
- Pins Open WebUI v0.13.0 and PostgreSQL 18 instead of `:main`
- Turns off the Ollama connection (no Ollama in the project) and analytics
- Checks health on `/health`

**Notes:** Open WebUI needs about 1–2 GB of RAM with the local embedding model. Upgrade by changing the image tag; Open WebUI migrates the database on start.

## Why Deploy Open WebUI on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Open WebUI on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
