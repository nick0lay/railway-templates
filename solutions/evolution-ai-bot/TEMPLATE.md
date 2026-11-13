# Deploy and Host WhatsApp AI Bot (Evolution API + LiteLLM) on Railway

WhatsApp AI Bot puts an LLM on your WhatsApp number in one click, without n8n. Evolution API connects the number by QR code or pairing code, like WhatsApp Web, with no Meta Business approval. Its built-in OpenAI bot answers every chat, and LiteLLM lets that bot use any provider: OpenAI, Anthropic, Gemini, OpenRouter and 100+ more, with one API key.

## About Hosting WhatsApp AI Bot (Evolution API + LiteLLM)

Evolution API is a Node.js service that keeps WhatsApp sessions open and exposes them as a REST API with a web manager. Its OpenAI integration answers incoming messages with a chat completion model, keeps each chat's recent history and supports a system prompt, keywords, session expiry and human takeover. LiteLLM is an OpenAI-compatible gateway with virtual keys, budgets, spend logs and an admin UI.

This template deploys both on Railway's private network: Evolution API with its own PostgreSQL and Redis, and LiteLLM with its own PostgreSQL. Evolution API's OpenAI client is already pointed at LiteLLM's private address, so you only add a provider key and a bot.

## Common Use Cases

- A customer support assistant on your business WhatsApp number
- A personal ChatGPT, Claude or Gemini assistant you can message from your phone
- FAQ, booking and opening-hours answers with a system prompt
- Several WhatsApp numbers, each with its own model, prompt and spend budget
- Trying different models on the same number by changing one name

## Dependencies for WhatsApp AI Bot (Evolution API + LiteLLM) Hosting

- PostgreSQL 18 (two: one for each app)
- Redis 8 (Evolution API cache)
- An API key from any LLM provider LiteLLM supports

### Deployment Dependencies

- Evolution API: https://github.com/evolution-foundation/evolution-api
- Evolution API docs: https://doc.evolution-api.com
- LiteLLM: https://github.com/BerriAI/litellm
- LiteLLM docs: https://docs.litellm.ai

### Implementation Details

**What you set:** one provider key on the LiteLLM service: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY` or `OPENROUTER_API_KEY` (you can add it after deploy).

**After deploy:**

1. Open `https://<litellm-domain>/ui`, log in with `UI_USERNAME` and the generated `UI_PASSWORD`, and create a virtual key (Virtual Keys → Create New Key, optionally with a budget).
2. Open `https://<evolution-domain>/manager`, log in with the `AUTHENTICATION_API_KEY` of the Evolution API service, create an instance (Baileys) and link your number: scan the QR code in WhatsApp (Settings → Linked devices), or request a pairing code with `GET /instance/connect/<name>?number=<your number>`.
3. In the instance, open Integrations → OpenAI. Add a credential with a unique name and the virtual key, then add a bot: type Chat Completion, a model such as `gpt-4o-mini`, `anthropic/claude-haiku-4-5` or `gemini/gemini-2.5-flash`, max tokens, a system message and trigger = all messages.
4. Message your number from another phone.

API equivalent: `POST /openai/creds/<instance>` with `{"name","apiKey"}`, then `POST /openai/create/<instance>` with `{"enabled":true,"openaiCredsId","botType":"chatCompletion","model","maxTokens","systemMessages":[...],"triggerType":"all",...}`.

**This template:**

- Pins Evolution API 2.3.7 (newer images need a license activation), LiteLLM 1.109.1, PostgreSQL 18 and Redis 8.10
- Points Evolution API's OpenAI bot at LiteLLM over the private network (`OPENAI_BASE_URL`), so any provider works
- Turns on only the OpenAI integration in Evolution API
- Routes any model name to its provider out of the box; add aliases, fallbacks or Ollama in the LiteLLM UI
- Gives each WhatsApp number its own virtual key, with spend logs and optional budgets
- Gives each app its own PostgreSQL
- Protects every public service: generated Evolution API key, LiteLLM master key and admin UI password; databases stay private
- Stores WhatsApp sessions in PostgreSQL so restarts don't log your number out

**Notes:** Evolution API 2.3.7 requires a unique credential name and key per instance, so create one virtual key per number. Voice notes are not transcribed through LiteLLM (Evolution sends them to OpenAI directly), and the Assistant bot type is not supported; use Chat Completion. Provider errors are sent to the chat, so test the model first. Use Baileys instances for real numbers: the built-in EVOLUTION test channel accepts messages on `/webhook/evolution` without the API key. Don't change `LITELLM_SALT_KEY` after the first deploy. WhatsApp may ban numbers that send bulk or unsolicited messages. Evolution API and LiteLLM are not affiliated with WhatsApp, Meta or any LLM provider.

## Why Deploy WhatsApp AI Bot (Evolution API + LiteLLM) on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying WhatsApp AI Bot (Evolution API + LiteLLM) on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
