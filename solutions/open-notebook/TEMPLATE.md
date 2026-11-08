# Deploy and Host Open Notebook on Railway

Open Notebook is an open-source, self-hosted alternative to Google NotebookLM. You collect sources (PDFs, web pages, YouTube videos, audio, text) into notebooks, chat with them with citations, write notes, run transformations such as summaries, and turn a notebook into a podcast with up to four speakers. It works with OpenAI, Anthropic, Gemini, Ollama, OpenRouter and many other AI providers.

## About Hosting Open Notebook

Open Notebook runs a Next.js web app, a FastAPI backend and a background worker in one container, and stores everything in SurrealDB. Uploaded files are kept on disk. Podcasts need a text-to-speech provider, which usually means a paid API billed per minute of audio. Without a password, anyone who finds the URL can use the app and the AI provider keys stored in it.

This template runs Open Notebook with SurrealDB and a private Kokoro text-to-speech service on Railway's private network. A password is generated, and Kokoro is set up as the default podcast voice model on first start, so podcast audio costs nothing per minute.

## Common Use Cases

- A private NotebookLM for research papers, reports and course material
- Turning a reading list or a set of documents into a podcast you can listen to
- Chat with citations over your own sources, with the AI provider of your choice
- Summaries and other transformations run on every new source
- A REST API for adding sources and asking questions from your own tools

## Dependencies for Open Notebook Hosting

- SurrealDB 2.7
- Kokoro-FastAPI 0.9 (CPU) for text-to-speech
- An AI provider key (OpenAI, Anthropic, Gemini, OpenRouter, ...) or your own Ollama, added in the app after deploy

### Deployment Dependencies

- Open Notebook: https://github.com/lfnovo/open-notebook
- Documentation: https://github.com/lfnovo/open-notebook/tree/main/docs
- Kokoro-FastAPI: https://github.com/remsky/Kokoro-FastAPI
- SurrealDB: https://surrealdb.com

### Implementation Details

**What you set:** nothing. The password and encryption key are generated.

**After deploy:**

1. Open the Open Notebook URL and log in with the `OPEN_NOTEBOOK_PASSWORD` variable of the Open Notebook service.
2. Go to **Manage → Models**, add a provider (for example OpenAI or OpenRouter) with your API key, and pick the default chat and embedding models.
3. Create a notebook and add sources.
4. For a podcast, open **Podcasts**, pick an episode profile and generate. The voices already use Kokoro; the script is written by your chat model.

**This template:**

- Generates `OPEN_NOTEBOOK_PASSWORD`, so the app and the API require a login
- Generates `OPEN_NOTEBOOK_ENCRYPTION_KEY`, which encrypts the provider keys you save in the app
- Runs Kokoro text-to-speech as a private service and registers it as the default text-to-speech model, with Kokoro voices on the built-in speaker profiles
- Keeps SurrealDB and Kokoro private, with no public URL
- Stores SurrealDB data and uploaded files on volumes
- Serves the web app and the API from one URL
- Pins Open Notebook 1.15.1, SurrealDB 2.7.0 and Kokoro-FastAPI 0.9.2
- Checks health on `/api/auth/status`, `/health` (SurrealDB) and `/health` (Kokoro)

**Notes:** Kokoro runs on CPU, so a podcast takes a few minutes to voice. Don't change `OPEN_NOTEBOOK_ENCRYPTION_KEY` after you save provider keys, or they can't be decrypted. Open Notebook has one shared password, not user accounts.

## Why Deploy Open Notebook on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Open Notebook on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
