# WhatsApp AI Bot: Evolution API + LiteLLM

The lightest way to get an LLM answering a WhatsApp number, without n8n or any workflow tool. [Evolution API](https://github.com/evolution-foundation/evolution-api) connects a WhatsApp number by QR code or pairing code, with no Meta Business approval. Its built-in OpenAI bot answers every chat, and [LiteLLM](https://github.com/BerriAI/litellm) sits behind it as a private gateway. Set one API key (OpenAI, Anthropic, Gemini, OpenRouter, or any of the 100+ providers LiteLLM supports) and pick the model by name. Both apps are pinned stable releases, and every public page needs a key or a login.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/whatsapp-ai-bot-evolution-api-23-litellm?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
   WhatsApp users          You (browser / curl)
        │                    │ HTTPS
        ▼                    ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Railway project                                                      │
│                                                                      │
│  Evolution API :8080 (public, API key)                               │
│   WhatsApp sessions, manager /manager, built-in OpenAI bot           │
│      │        │          │ POST /v1/chat/completions                 │
│      ▼        ▼          │ (OPENAI_BASE_URL, private network,        │
│  Evolution  Evolution    │  one LiteLLM virtual key per instance)    │
│  Postgres   Redis        ▼                                           │
│  (private)  (private)  LiteLLM :4000 (public, master key + UI login) │
│                          │ virtual keys, budgets, spend logs, /ui    │
│                          ▼                                           │
│                        LiteLLM Postgres (private)                    │
└──────────────────────────│───────────────────────────────────────────┘
        │                  ▼
        ▼             OpenAI, Anthropic, Gemini, OpenRouter, ... (outbound)
 WhatsApp servers (outbound)
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Evolution API | `evoapicloud/evolution-api:v2.3.7` | WhatsApp REST API, manager UI and the OpenAI bot (public, API key) |
| Evolution Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Instances, WhatsApp sessions, messages, bot sessions with chat history (private) |
| Evolution Redis | `redis:8.10` | Evolution API cache (private) |
| LiteLLM | `litellm/litellm-database:v1.106.6` | OpenAI-compatible gateway to any provider, virtual keys, budgets, spend logs, admin UI (public, master key and UI login) |
| LiteLLM Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Virtual keys, models added in the UI, spend logs (private) |

## What this template does differently

- **No workflow tool in the middle.** Evolution API's own OpenAI bot (chat completion mode) keeps a per-chat history and answers directly. Four services fewer than an n8n stack.
- **Any provider, not just OpenAI.** Evolution API 2.3.7 uses the official OpenAI SDK, which reads `OPENAI_BASE_URL`. The template points it at LiteLLM's private address, so the bot calls whatever model name you give it: `gpt-4o-mini`, `anthropic/claude-haiku-4-5`, `gemini/gemini-2.5-flash`, `openrouter/...`.
- **One key per WhatsApp number, with budgets.** Each Evolution instance gets its own LiteLLM virtual key, so you see spend per number and can cap it. The master key never leaves LiteLLM.
- **Only the OpenAI integration on in Evolution API.** `OPENAI_ENABLED=true` plus `OPENAI_BASE_URL`. No other integration is turned on.
- **Auth on every public service.** Evolution API needs the generated global API key, LiteLLM needs the master key (API) or the generated UI password (admin UI). The databases have no public domain or TCP proxy.
- **Pinned, tested versions:** Evolution API 2.3.7 (newer images need a license activation), LiteLLM 1.106.6, Postgres 18, Redis 8.10.

## After deploy

**1. Add a provider key**

Set at least one of `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY` or `OPENROUTER_API_KEY` on the `LiteLLM` service and redeploy it. Any model name is passed to its provider (wildcard route). To use other providers, Ollama, aliases or fallbacks, open `https://<litellm-domain>/ui`, log in as `UI_USERNAME` / `UI_PASSWORD`, and add models under **Models**. Models added there are stored in Postgres and show up in Evolution's model list.

**2. Create a virtual key for the WhatsApp number**

In the LiteLLM UI: **Virtual Keys → Create New Key** (optionally set a budget). Or with the API:

```bash
LITELLM=https://<litellm-domain>
curl -X POST "$LITELLM/key/generate" -H "Authorization: Bearer <LITELLM_MASTER_KEY>" \
  -H "content-type: application/json" -d '{"key_alias":"whatsapp-main","max_budget":5}'
```

Copy the returned `key` (`sk-...`). Create one key per Evolution instance: Evolution API 2.3.7 stores credentials with a globally unique key **and** a globally unique name, so a second instance can't reuse either.

**3. Connect WhatsApp**

1. Copy `AUTHENTICATION_API_KEY` from the `Evolution API` service variables.
2. Open `https://<evolution-domain>/manager`, enter the server URL `https://<evolution-domain>` and the API key.
3. Create an instance (channel **Baileys**) and link it: scan the QR code in WhatsApp (**Settings → Linked devices → Link a device**), or use a pairing code (below).

**4. Attach the AI bot**

In the manager, open the instance → **Integrations → OpenAI**:

1. **Credentials:** add one with a unique name (for example `litellm-main`) and the virtual key from step 2.
2. **Add bot:** type **Chat Completion**, the credential, a model (for example `gpt-4o-mini`), max tokens (for example `500`), a system message, trigger = all messages or a keyword.

The same with the API. We tested the `/openai/creds`, `/openai/getModels` and `/openai/create` calls on an instance; the Baileys instance and pairing-code calls are the standard Evolution API ones and were not run in our test:

```bash
URL=https://<evolution-domain>
KEY=<AUTHENTICATION_API_KEY>

# Instance with QR code (base64 image in the response)
curl -X POST "$URL/instance/create" -H "apikey: $KEY" -H "content-type: application/json" \
  -d '{"instanceName":"main","integration":"WHATSAPP-BAILEYS","qrcode":true}'
# Or a pairing code: enter it in WhatsApp under Linked devices -> Link with phone number
curl "$URL/instance/connect/main?number=5511999999999" -H "apikey: $KEY"

# Credentials = the LiteLLM virtual key (unique name and key per instance)
curl -X POST "$URL/openai/creds/main" -H "apikey: $KEY" -H "content-type: application/json" \
  -d '{"name":"litellm-main","apiKey":"sk-<virtual key>"}'
# -> {"id":"<credsId>", ...}

# Models LiteLLM offers to this key
curl "$URL/openai/getModels/main?openaiCredsId=<credsId>" -H "apikey: $KEY"

# The bot
curl -X POST "$URL/openai/create/main" -H "apikey: $KEY" -H "content-type: application/json" -d '{
  "enabled": true, "openaiCredsId": "<credsId>", "botType": "chatCompletion",
  "model": "gpt-4o-mini", "maxTokens": 500,
  "systemMessages": ["You are the WhatsApp assistant of <business>. Answer in the user'\''s language, in at most 3 short sentences. If you do not know, say a human will reply soon."],
  "assistantMessages": [], "userMessages": [],
  "triggerType": "all", "expire": 60, "keywordFinish": "#stop", "delayMessage": 1000, "unknownMessage": "",
  "listeningFromMe": false, "stopBotFromMe": true, "keepOpen": false, "debounceTime": 5,
  "splitMessages": false, "timePerChar": 0}'
```

`expire` closes a chat's session (and its history) after that many minutes without a message, `keywordFinish` lets the user end it, `stopBotFromMe` pauses the bot when you answer from the phone yourself, and `debounceTime` merges quick consecutive messages into one call. The bot keeps the last 10 messages of each chat as context.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| LiteLLM | `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `OPENROUTER_API_KEY` | empty | Set at least one |
| LiteLLM | `LITELLM_CONFIG` | wildcard route | LiteLLM proxy config, written to a file on start. Add `model_list` entries, fallbacks or other providers here, or use the UI |
| LiteLLM | `UI_USERNAME` | `admin` | Admin UI login |
| Evolution API | `DATABASE_SAVE_DATA_*` | `true` | Store messages, contacts, chats, labels and history |
| Evolution API | `LANGUAGE`, `TZ`, `LOG_LEVEL` | `en`, `UTC`, `ERROR,WARN,INFO,LOG,WEBHOOKS` | |

### Generated

| Service | Variable | Notes |
|---|---|---|
| Evolution API | `AUTHENTICATION_API_KEY` | 64 hex characters, sent as the `apikey` header; manager login |
| LiteLLM | `LITELLM_MASTER_KEY` | Admin key of the LiteLLM API. Use it to create virtual keys; don't paste it into Evolution |
| LiteLLM | `UI_PASSWORD` | Admin UI password |
| LiteLLM | `LITELLM_SALT_KEY` | Encrypts provider keys stored in the database. **Never change it after the first deploy** |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Evolution API | `OPENAI_ENABLED` | `true` | Turns on `/openai/*` and the manager's OpenAI page |
| Evolution API | `OPENAI_BASE_URL` | `http://${{LiteLLM.RAILWAY_PRIVATE_DOMAIN}}:${{LiteLLM.PORT}}/v1` | The OpenAI bot calls LiteLLM over the private network. Remove it to call api.openai.com directly with a real OpenAI key |
| Evolution API | `DATABASE_CONNECTION_URI`, `CACHE_REDIS_URI` | `${{Evolution Postgres.DATABASE_URL}}`, `${{Evolution Redis.REDIS_URL}}` | Private network |
| LiteLLM | `DATABASE_URL`, `STORE_MODEL_IN_DB` | `${{LiteLLM Postgres.DATABASE_URL}}`, `True` | Keys and UI-added models persist |

## Limits of Evolution's OpenAI bot through LiteLLM

- **Voice notes are not transcribed.** Evolution API 2.3.7 sends audio straight to `api.openai.com` with the bot's credential, which is a LiteLLM key, so OpenAI rejects it and the contact gets "Sorry, I couldn't transcribe your audio message". Keep `speechToText` off.
- **Use Chat Completion, not Assistant.** The Assistant type needs OpenAI's Assistants API, which LiteLLM doesn't serve for other providers.
- **Errors reach the chat.** When the provider fails (bad key, no credit, unknown model), Evolution sends `Sorry, there was an error: <message>` to the contact. Test the model in LiteLLM first.
- Images sent by contacts are passed as `image_url`; that works only with vision models.

## Custom domains

- Evolution API: add the domain, set `SERVER_URL=https://your-domain`.
- LiteLLM: add the domain; nothing else to change. Evolution keeps using the private address.

## Upgrading

- Evolution API: change the image tag. It migrates its database on start. Avoid `latest`, `homolog` and `-rc` tags; check the license notes of new releases first.
- LiteLLM: change to another `litellm/litellm-database:v1.x.y` stable tag (not `main-latest` or `-nightly`). It migrates its database on start.

Back up both Postgres services first.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `401 Unauthorized` from Evolution API | The `apikey` header is missing or wrong |
| `Openai is disabled` | `OPENAI_ENABLED` was removed from Evolution API |
| `This API key is already registered` | Each instance needs its own LiteLLM virtual key |
| `Error creating openai creds` (500) | The credential name is already used by another instance; names are global |
| Bot answers `Sorry, there was an error: 401 ... Incorrect API key` | The provider key on `LiteLLM` is wrong or missing for that model's provider |
| Bot answers `... Invalid proxy server token` | The credential is not a valid LiteLLM virtual key (or the key was deleted) |
| Bot answers `... model ... not found` / `LLM Provider NOT provided` | Use a provider prefix (`anthropic/...`, `gemini/...`) or add the model in the LiteLLM UI |
| Model list in the manager is empty | Add models in the LiteLLM UI; wildcard-routed names work but aren't listed |
| The bot answers once and then ignores the user | The session expired (`expire`) or the user sent `keywordFinish` |
| The bot stops after you answered from the phone | `stopBotFromMe` is on; that is intended for human takeover |
| The QR code expires | Call `/instance/connect/<name>` again or reopen the instance in the manager |

Use the `WHATSAPP-BAILEYS` integration (QR code or pairing code) for real numbers. In Evolution API 2.3.7 the built-in `EVOLUTION` test channel accepts messages on `/webhook/evolution` without the API key, so anyone who knows such an instance's number could trigger its bot and spend your LLM budget. Don't attach production bots to `EVOLUTION` instances.

WhatsApp may ban numbers that send bulk or unsolicited messages. Evolution API and LiteLLM are not affiliated with WhatsApp, Meta or any LLM provider.

## License

- Evolution API: Apache License 2.0 with extra [conditions](https://github.com/EvolutionAPI/evolution-api/blob/main/LICENSE): keep the logo and copyright in the manager, and a product built on it must say so where administrators can see it.
- LiteLLM: [MIT](https://github.com/BerriAI/litellm/blob/main/LICENSE), except the `enterprise/` features, which need a LiteLLM license. This template uses only the open-source features.

## Testing

Tested on 2026-11-10 with test deploys of the template draft: all five services healthy. Evolution API refused instance and OpenAI endpoints without a key and with a wrong key (401). LiteLLM refused chat completions without a key and with a wrong key, refused key creation with a virtual key, refused a wrong UI password and accepted the generated one. With the master key we created a virtual key and a mock model (LiteLLM `mock_response`). On an Evolution API instance on the built-in EVOLUTION channel, credentials with the virtual key were accepted, the model list came from LiteLLM, and a Chat Completion bot was created. A simulated incoming message got the mock model's exact reply stored by Evolution API, with the chat history in the bot session and the call in LiteLLM's spend log for that key. With the bot switched to `gpt-4o-mini` and a fake OpenAI key on LiteLLM, the chat received OpenAI's `Incorrect API key provided` error through LiteLLM, which shows the request left Evolution, went through LiteLLM and reached OpenAI. A second instance could not reuse the same key or credential name, and worked with its own. After redeploying Evolution API, LiteLLM and both Postgres services, the virtual key, the model, the instance and the bot were still there and a second message got its reply. **Not tested:** a real WhatsApp number (QR or pairing code) and real messages; a paid provider key, so no real model answer; Anthropic, Gemini and OpenRouter routes; the manager's OpenAI page (we used the API); voice notes and images.
