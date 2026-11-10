# Deploy and Host Evolution API + n8n on Railway

Evolution API + n8n gives you WhatsApp automations and AI agents. n8n is a workflow automation tool with AI Agent, LLM and 400+ app nodes; Evolution API connects a WhatsApp number by scanning a QR code, like WhatsApp Web, with no Meta Business approval. Each message to your number calls an n8n workflow, and the workflow's answer goes back to the chat.

## About Hosting Evolution API + n8n

Evolution API is a Node.js service that keeps WhatsApp sessions open and exposes them as a REST API with a web manager. Its n8n integration posts every incoming message to an n8n webhook with the text, the contact and a session ID, and sends the workflow's `output` back. n8n needs PostgreSQL, and for production it runs in queue mode: the main instance serves the editor and webhooks, Redis holds the job queue, workers run the executions, and task runners run Code nodes in a separate container.

This template deploys the whole stack on Railway's private network: Evolution API with its own PostgreSQL and Redis, and n8n main, worker and task runner with their own PostgreSQL and Redis. Evolution API calls n8n and n8n calls Evolution API over private addresses that are already filled in as variables.

## Common Use Cases

- AI agents that answer WhatsApp customers with your docs, CRM or calendar
- Lead capture from WhatsApp into a CRM, Google Sheets or Notion
- Order, booking and payment notifications sent from n8n workflows
- Human handover: the bot pauses when you answer from the phone
- Several WhatsApp numbers, each routed to its own workflow

## Dependencies for Evolution API + n8n Hosting

- PostgreSQL 18 (two: one for each app)
- Redis 8 (two: Evolution API cache and n8n job queue)
- n8n worker and task runner (official images, same version as n8n)

### Deployment Dependencies

- Evolution API: https://github.com/evolution-foundation/evolution-api
- Evolution API docs: https://doc.evolution-api.com
- n8n: https://github.com/n8n-io/n8n
- n8n docs: https://docs.n8n.io

### Implementation Details

**What you set:** `N8N_INSTANCE_OWNER_EMAIL`, the email you log in to n8n with.

**After deploy:**

1. Open the `n8n` URL and log in with `N8N_INSTANCE_OWNER_EMAIL` and the generated `N8N_OWNER_PASSWORD` (variables of the `n8n` service).
2. Build a workflow: Webhook trigger (POST, Basic Auth, respond with the Respond to Webhook node), your logic, and Respond to Webhook with `{"output": "reply text"}`. Publish it.
3. Open `https://<evolution-domain>/manager`, log in with the `AUTHENTICATION_API_KEY` of the Evolution API service, create an instance and scan its QR code in WhatsApp (Settings → Linked devices).
4. In the instance's n8n integration, add a bot: Webhook URL = the `PRIVATE_WEBHOOK_URL` variable of n8n plus your webhook path, the basic auth user and password, trigger = all messages or a keyword.
5. Message your number from another phone.

To send messages from other workflows, use an HTTP Request node with `EVOLUTION_API_URL` and an `apikey` header with `EVOLUTION_API_KEY` (both variables of n8n).

**This template:**

- Pins Evolution API 2.3.7 (newer images need a license activation), n8n 2.47.3, PostgreSQL 18 and Redis 8.10
- Creates the n8n owner account at deploy time, so nobody else can claim a fresh instance
- Runs n8n in queue mode with a worker and an external task runner for JavaScript and Python Code nodes, all on the official images
- Turns on only the n8n integration in Evolution API
- Puts the private webhook URL and Evolution API's private URL and key in variables, ready to paste
- Gives each app its own PostgreSQL and Redis
- Protects every public service: generated Evolution API key and n8n owner login; worker, runner and databases stay private
- Stores WhatsApp sessions in PostgreSQL so restarts don't log your number out

**Notes:** The n8n owner is reset from its variables on every start: change the password in Railway, or set `N8N_INSTANCE_OWNER_MANAGED_BY_ENV=false` to manage it in n8n. Evolution API sends the instance token to the workflow as `apiKey`, so a workflow can call Evolution API back. Don't change `N8N_ENCRYPTION_KEY` after the first deploy. Upgrade n8n by changing n8n, worker and runner to the same version. WhatsApp may ban numbers that send bulk or unsolicited messages. Evolution API and n8n are not affiliated with WhatsApp or Meta.

## Why Deploy Evolution API + n8n on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Evolution API + n8n on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
