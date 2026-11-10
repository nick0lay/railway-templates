# Deploy and Host Evolution API + MCP Server on Railway

Evolution API + MCP Server gives Claude and other AI agents WhatsApp tools. Evolution API connects a WhatsApp number by scanning a QR code or entering a pairing code, like WhatsApp Web, with no Meta Business approval. mcp-evolution, a Model Context Protocol (MCP) server, turns it into 34 tools your agent calls over one HTTPS URL with a bearer token: read chats and history, send messages, media and polls, list groups, check numbers.

## About Hosting Evolution API + MCP Server

Evolution API is a Node.js service that keeps WhatsApp sessions open and exposes them as a REST API with a web manager; it needs PostgreSQL and Redis. mcp-evolution is a TypeScript MCP server that wraps that REST API as tools. It serves streamable HTTP, checks a bearer token on every request, and limits the agent to the instances, tools and recipients you allow.

This template deploys both on Railway's private network: Evolution API with its own PostgreSQL and Redis, and the MCP server, which reaches Evolution API over a private address with the API key filled in from a reference variable. Your agent only gets the MCP URL and token; the Evolution key never leaves Railway and is removed from every tool result.

## Common Use Cases

- Ask Claude to summarise unread WhatsApp chats or find a message
- Let an agent answer customers or send follow-ups from your own number
- Draft and send replies from Claude Code while you work
- Build your own agent on any MCP SDK with WhatsApp read and send tools
- Check which numbers have WhatsApp before a campaign

## Dependencies for Evolution API + MCP Server Hosting

- PostgreSQL 18 (Evolution API data and WhatsApp sessions)
- Redis 8 (Evolution API cache)
- mcp-evolution 0.7.0, built from a pinned GitHub commit on the official Node 22 image

### Deployment Dependencies

- Evolution API: https://github.com/evolution-foundation/evolution-api
- Evolution API docs: https://doc.evolution-api.com
- mcp-evolution: https://github.com/billyfranklim1/mcp-evolution
- Model Context Protocol: https://modelcontextprotocol.io

### Implementation Details

**What you set:** nothing required. Optionally `EVOLUTION_INSTANCES` (default `whatsapp`) on the Evolution MCP service.

**After deploy:**

1. Open `https://<evolution-domain>/manager`, log in with the `AUTHENTICATION_API_KEY` of the Evolution API service, create an instance named `whatsapp` (channel Baileys) and scan its QR code in WhatsApp (Settings → Linked devices). For a pairing code instead: `GET /instance/connect/whatsapp?number=<your number>` with the `apikey` header.
2. Copy `MCP_URL` and `MCP_AUTH_TOKEN` from the Evolution MCP service.
3. Claude Code: `claude mcp add --transport http whatsapp <MCP_URL> --header "Authorization: Bearer <MCP_AUTH_TOKEN>"`. Claude Desktop: use the `mcp-remote` bridge with the same header. Any streamable HTTP client with custom headers works.
4. Ask your agent to list your chats.

claude.ai's custom connectors and ChatGPT expect OAuth and can't send a static bearer token, so they can't connect directly.

**This template:**

- Pins Evolution API 2.3.7 (newer images need a license activation), mcp-evolution 0.7.0 (commit `44f1999`), Node 22.23.4, PostgreSQL 18 and Redis 8.10
- Protects the MCP endpoint with a generated 48-character bearer token, and Evolution API with a generated API key; the databases stay private
- Keeps the Evolution key inside Railway and removes it from tool output
- Leaves irreversible and broadcast tools (delete for everyone, log out, status posts, webhook, privacy and group changes) off; adds an instance allowlist and an optional recipient allowlist
- Turns on no Evolution API integration flag: MCP talks to the plain REST API
- Stores WhatsApp sessions in PostgreSQL so restarts don't log your number out

**Notes:** The MCP server builds its pinned commit at each start (about 15 seconds), so it needs GitHub and the npm registry to be reachable. It is stateless and answers POST only. `download_media` saves files inside the container, so remote agents can't open them. Use `EVOLUTION_ALLOWED_TOOLS=@read` for read-only access and `EVOLUTION_ALLOWED_RECIPIENTS` to limit who the agent can message. Use the Baileys channel for real numbers: Evolution API's built-in EVOLUTION test channel accepts messages on `/webhook/evolution` without the API key. WhatsApp may ban numbers that send bulk or unsolicited messages. Evolution API and mcp-evolution are not affiliated with WhatsApp or Meta. Licenses: Evolution API is Apache 2.0 with logo conditions; mcp-evolution is MIT.

## Why Deploy Evolution API + MCP Server on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Evolution API + MCP Server on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
