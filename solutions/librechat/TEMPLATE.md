# Deploy and Host LibreChat on Railway

LibreChat is an open-source, ChatGPT-style chat app for many AI providers at once: OpenAI, Anthropic Claude, Google Gemini, OpenRouter, Groq, Mistral, DeepSeek, xAI and any OpenAI-compatible API. It adds agents, MCP tools, file search over your documents, conversation search, presets, and multiple users with their own keys.

## About Hosting LibreChat

LibreChat is a Node.js app backed by four services: MongoDB for users, conversations and stored keys, Meilisearch for conversation search, a RAG API that chunks and embeds uploaded files, and PostgreSQL with pgvector for the embeddings. In production it needs volumes for all data, fixed secrets so logins and stored keys survive restarts, and an admin account that only you control: with open registration, anyone who finds the URL can sign up and spend the API keys you put on the server.

This template deploys the full upstream stack on Railway's private network, creates your admin account at deploy, keeps sign-up off, and pins every image to a tested release.

## Common Use Cases

- A private ChatGPT for your team, with your own API keys or each user's own key
- One chat window for Claude, GPT, Gemini, Llama, Mistral, DeepSeek and Grok
- Chat with your documents: upload PDFs and notes and ask questions about them (file search)
- Agents with tools and MCP servers, shared with your team
- Search across all past conversations

## Dependencies for LibreChat Hosting

- MongoDB 8.0 (volume)
- Meilisearch 1.35 (volume)
- LibreChat RAG API 0.9 with PostgreSQL 15 + pgvector 0.8 (volume)
- An API key for at least one LLM provider (yours, or each user's)

### Deployment Dependencies

- LibreChat: https://github.com/danny-avila/LibreChat
- Documentation: https://www.librechat.ai/docs
- Configuration file reference: https://www.librechat.ai/docs/configuration/librechat_yaml
- RAG API: https://github.com/danny-avila/rag_api

### Implementation Details

**What you set:** `ADMIN_EMAIL`, the email you log in with (default `admin@example.com`; change it to your own). Optionally, provider keys such as `OPENAI_API_KEY` or `ANTHROPIC_API_KEY`. By default every provider is `user_provided`: each user enters their own key in the chat window.

**After deploy:**

1. Open the LibreChat URL and log in with `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD` from the LibreChat service's variables.
2. Choose a provider in the model menu and enter your key, or set the key on the server and redeploy.
3. To add users, set `ALLOW_REGISTRATION=true`, let them sign up, then set it back to `false`.

**Services:**

| Service | Image | Access |
|---|---|---|
| LibreChat | `librechat:v0.8.9` | public, login required |
| MongoDB | `mongo:8.0.38` | private, password |
| Meilisearch | `meilisearch:v1.35.1` | private, master key |
| RAG-API | `librechat-rag-api-dev-lite:v0.9.1` | private, JWT |
| VectorDB | `pgvector:0.8.0-pg15` | private, password |

**This template:**

- Creates the admin account at deploy and keeps public sign-up off, so nobody else can claim your instance or use your keys
- Pins LibreChat v0.8.9 and RAG API v0.9.1 instead of the nightly `latest` builds, and the database versions LibreChat itself pins
- Keeps uploads and generated images on a volume, so they survive redeploys
- Generates `CREDS_KEY`, `CREDS_IV`, `JWT_SECRET`, `JWT_REFRESH_SECRET` and the Meilisearch master key once
- Ships a `librechat.yaml` in the `LIBRECHAT_YAML` variable with OpenRouter, Groq, Mistral, DeepSeek and xAI, editable from the dashboard
- Uses your `OPENAI_API_KEY` for file search embeddings too, so one key turns on chat and file search
- Turns on scheduled agent runs for a single-replica deployment
- Runs MongoDB with authentication, Meilisearch in production mode and the RAG API behind LibreChat's JWT, all without public domains
- Sets login, sign-up and message rate limits, automatic bans, and no search engine indexing

**Tested** with a deploy from the template: sign-up and anonymous requests refused, admin login, chat with and without a key, a document embedded for file search, and users, keys, chats and files kept after redeploying every service.

**Notes:** the stack needs about 1.5 to 2 GB of RAM. Upgrade by changing the LibreChat image tag after reading the release notes. LibreChat and the RAG API are MIT-licensed; MongoDB is under the SSPL. You are responsible for license compliance and for the terms of the providers you connect.

## Why Deploy LibreChat on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying LibreChat on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
