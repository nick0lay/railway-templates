# Deploy and Host Evolution API + Flowise on Railway

Evolution API + Flowise puts AI agents on WhatsApp. Flowise is a visual builder for LLM agents, chatbots and RAG flows. Evolution API connects a WhatsApp number by scanning a QR code, like WhatsApp Web, with no Meta Business approval. Each message to your number runs a Flowise flow, and the flow's answer goes back to the chat.

## About Hosting Evolution API + Flowise

Evolution API is a Node.js service that keeps WhatsApp sessions open and exposes them through a REST API and a web manager. Its Flowise integration posts every incoming message to a Flowise prediction URL, with the text, the contact as session ID, and the instance details as variables, and it sends the flow's `text` answer back to the chat. Flowise stores flows, API keys, credentials and chat history in PostgreSQL, and uploaded files on a volume.

This template deploys both apps on Railway's private network: Evolution API with its own PostgreSQL and Redis, and Flowise with its own PostgreSQL. Evolution API calls Flowise at a private address that is already filled in as a variable.

## Common Use Cases

- AI customer support on WhatsApp that answers from your documents (RAG)
- Agents with tools that look up orders, book appointments or create CRM leads
- One conversation memory per contact, since the session ID is the phone number
- Several WhatsApp numbers, each routed to its own flow
- Human handover: the bot pauses when you answer from the phone

## Dependencies for Evolution API + Flowise Hosting

- PostgreSQL 18 (two: one for each app)
- Redis 8 (Evolution API cache)
- An LLM provider key for your flows (OpenAI, Anthropic, Gemini, Groq, ...)

### Deployment Dependencies

- Evolution API: https://github.com/evolution-foundation/evolution-api
- Evolution API docs: https://doc.evolution-api.com
- Flowise: https://github.com/FlowiseAI/Flowise
- Flowise docs: https://docs.flowiseai.com

### Implementation Details

**What you set:** `ADMIN_EMAIL` on `flowise`, the email you log in to Flowise with.

**After deploy:**

1. Open the `flowise` URL and log in with `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD` (variables of the `flowise` service). Add your LLM key under Credentials.
2. Build an Agentflow or Chatflow and test it in the chat panel.
3. Create an API key under API Keys and assign it to the flow (flow → API Endpoint). Without an assigned key, anyone who knows the flow ID can call it.
4. Open `https://<evolution-domain>/manager` and log in with the `AUTHENTICATION_API_KEY` of the Evolution API service. Create an instance and pair it: scan the QR code in WhatsApp (Settings → Linked devices), or get a pairing code from `/instance/connect/<name>?number=<your number>`.
5. In the instance's Flowise integration, add a bot. Set the API URL to the `PRIVATE_PREDICTION_URL` variable of flowise followed by the flow ID, the API key to the Flowise key, and the trigger to all messages or a keyword.
6. Message your number from another phone.

The same steps work through the API with `POST /flowise/create/<instance>` and the body `{"enabled":true,"apiUrl":"...","apiKey":"...","triggerType":"all"}`.

**This template:**

- Pins Evolution API 2.3.7 (newer images need a license activation), Flowise 3.1.4, PostgreSQL 18 and Redis 8.10
- Creates the Flowise owner account at deploy time, so nobody else can claim a fresh instance
- Turns on only the Flowise integration in Evolution API
- Puts Flowise's private prediction URL and Evolution API's private URL in variables, ready to paste
- Gives each app its own PostgreSQL. Flowise runs as a single process and doesn't need Redis
- Protects every public service: a generated Evolution API key and the Flowise owner login. The databases stay private
- Stores WhatsApp sessions in PostgreSQL, so restarts don't log your number out

**Notes:** Evolution API also sends `remoteJid`, `pushName`, `instanceName`, `serverUrl` and the instance token (`apiKey`) as variables. Flowise ignores them until you allow them in the flow under Configuration → Security → Override Configuration; then use `{{ $vars.remoteJid }}` in nodes. Don't change `FLOWISE_SECRETKEY_OVERWRITE` after the first deploy. Use Baileys (QR code) instances for real numbers: the built-in EVOLUTION test channel's `/webhook/evolution` has no API-key check, so don't attach production bots to it. WhatsApp may ban numbers that send bulk or unsolicited messages. Evolution API and Flowise are not affiliated with WhatsApp or Meta.

## Why Deploy Evolution API + Flowise on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Evolution API + Flowise on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
