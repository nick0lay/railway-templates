# Evolution API + MCP Server

WhatsApp tools for Claude and other AI agents, on Railway. [Evolution API](https://github.com/evolution-foundation/evolution-api) connects a WhatsApp number by scanning a QR code or typing a pairing code, with no Meta Business approval. [mcp-evolution](https://github.com/billyfranklim1/mcp-evolution) is a Model Context Protocol (MCP) server that turns it into 34 tools: read chats and message history, send text, media, polls and reactions, list groups, check numbers. Your agent connects to one HTTPS URL with a bearer token. Both are pinned, tested versions, and every public endpoint needs a key or a token.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/evolution-api-23-mcp-server-07?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
  Claude Code / Claude Desktop / your agent       You (browser, curl)
        │ HTTPS POST /mcp                             │ HTTPS, apikey header
        │ Authorization: Bearer <MCP_AUTH_TOKEN>      │
        ▼                                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Railway project                                                      │
│                                                                      │
│  Evolution MCP :3000 (public, bearer token) ── REST + apikey ──┐     │
│   streamable HTTP, stateless, tool and         (private network)│     │
│   instance allowlists                                          ▼     │
│                                 Evolution API :8080 (public, API key)│
│                                  WhatsApp sessions, manager /manager │
│                                        │                │            │
│                                        ▼                ▼            │
│                                 Evolution Postgres  Evolution Redis  │
│                                 (private)           (private)        │
└──────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
                                WhatsApp servers (outbound)
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Evolution API | `evoapicloud/evolution-api:v2.3.7` | WhatsApp REST API and manager UI (public, API key) |
| Evolution Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Instances, WhatsApp sessions, messages, contacts (private) |
| Evolution Redis | `redis:8.10` | Evolution API cache (private) |
| Evolution MCP | `node:22.23.4-alpine3.24` running [billyfranklim1/mcp-evolution](https://github.com/billyfranklim1/mcp-evolution) 0.7.0 (commit `44f1999`) | MCP server over streamable HTTP at `/mcp` (public, bearer token). Talks to Evolution API over the private network |

## What this template does differently

- **Auth on the MCP endpoint.** The MCP server refuses every request without `Authorization: Bearer <MCP_AUTH_TOKEN>` (constant-time check). The token is 48 random letters and digits, generated at deploy time. Only `/health` is open, and it returns `{"status":"ok"}` and nothing else.
- **The Evolution key stays inside Railway.** The MCP server reads Evolution API's global key from a reference variable and calls Evolution API over the private network. It removes the key from every tool result and error, so your agent only ever holds the MCP token.
- **Guard rails on by default.** Tools that can't be undone or that broadcast (delete for everyone, log out, post a status, change the webhook, privacy or groups) are not registered at all. The agent can only address the instances you list in `EVOLUTION_INSTANCES`, and you can add a recipient allowlist.
- **A pinned server build.** mcp-evolution has no release image, so the service runs the official Node image and builds a pinned commit of the GitHub repo when it starts (about 15 seconds). The npm package called `mcp-evolution` is by a different author and is not used.
- **Evolution API as it is.** MCP isn't an Evolution API integration module, so no integration flag is turned on. Evolution API is our tested standalone configuration: version 2.3.7 (newer images need a license activation) with sessions stored in Postgres.
- **No extra database.** The MCP server is stateless: each request gets a fresh server with the same guards.

## After deploy

**1. Connect WhatsApp**

The MCP server works with the instance named in `EVOLUTION_INSTANCES` of the `Evolution MCP` service (default `whatsapp`). Create the instance with that name.

In the manager: open `https://<evolution-domain>/manager`, enter the server URL `https://<evolution-domain>` and the `AUTHENTICATION_API_KEY` of the `Evolution API` service, create an instance named `whatsapp` (channel **Baileys**) and scan the QR code in WhatsApp: **Settings → Linked devices → Link a device**.

With the API:

```bash
URL=https://<evolution-domain>
KEY=<AUTHENTICATION_API_KEY>

# Create the instance (response has a base64 QR code)
curl -X POST "$URL/instance/create" -H "apikey: $KEY" -H "content-type: application/json" \
  -d '{"instanceName":"whatsapp","integration":"WHATSAPP-BAILEYS","qrcode":true}'

# New QR code, or a pairing code for your number (WhatsApp → Linked devices → Link with phone number)
curl "$URL/instance/connect/whatsapp" -H "apikey: $KEY"
curl "$URL/instance/connect/whatsapp?number=5511999999999" -H "apikey: $KEY"

# State: "open" once paired
curl "$URL/instance/connectionState/whatsapp" -H "apikey: $KEY"
```

**2. Connect your agent**

Copy `MCP_URL` and `MCP_AUTH_TOKEN` from the `Evolution MCP` variables.

Claude Code:

```bash
claude mcp add --transport http whatsapp "<MCP_URL>" --header "Authorization: Bearer <MCP_AUTH_TOKEN>"
```

Claude Desktop and other clients that only start local commands use the `mcp-remote` bridge (needs Node.js):

```json
{
  "mcpServers": {
    "whatsapp": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "<MCP_URL>", "--header", "Authorization:${AUTH_HEADER}"],
      "env": { "AUTH_HEADER": "Bearer <MCP_AUTH_TOKEN>" }
    }
  }
}
```

Any client or SDK that supports streamable HTTP with custom headers works the same way: the URL plus the `Authorization` header. claude.ai's custom connector dialog and ChatGPT expect OAuth and can't send a static bearer token, so they can't connect directly.

Ask your agent "list my WhatsApp chats" or "send 'hi' to 5511999999999".

**3. Narrow what the agent can do (recommended)**

On `Evolution MCP`, set:

- `EVOLUTION_ALLOWED_TOOLS=@read` for read-only, or `@read,@send` for reading and basic sending.
- `EVOLUTION_ALLOWED_RECIPIENTS=5511999999999,*@g.us` to limit reading and sending to those numbers and all groups.
- `EVOLUTION_INSTANCES=sales,support` with `EVOLUTION_DEFAULT_INSTANCE=sales` for several numbers; tools then take an `instance` argument limited to that list.

Changing a variable redeploys the service.

## Tools

With the defaults the server registers 34 tools:

- **Messages:** `send_text`, `send_media`, `send_audio`, `send_sticker`, `send_location`, `send_contact`, `send_reaction`, `send_poll`, `send_list`, `send_button`
- **Chats:** `find_chats`, `find_contacts`, `find_messages`, `get_chat_history`, `mark_as_read`, `archive_chat`, `fetch_profile_picture`, `download_media`, `send_presence`, `check_number`
- **Groups:** `list_groups`, `get_group_info`, `fetch_invite_code`, `send_group_invite`, `find_group_by_invite`, `get_group_resolved_participants` (answers with an error here: it needs `EVOLUTION_DB_URL`)
- **Instance and profile:** `list_instances`, `connection_state`, `get_settings`, `find_webhook`, `find_labels`, `handle_label`, `fetch_business_profile`, `fetch_privacy`

`download_media` saves the file inside the MCP container and returns its path, which a remote agent can't open; use Evolution API's `/chat/getBase64FromMediaMessage/<instance>` for media instead.

The dangerous tools (`send_status`, `delete_message`, `logout_instance`, `restart_instance`, `set_settings`, `set_webhook`, profile, privacy, block and group changes) are off. Add them by name, for example `EVOLUTION_ALLOWED_TOOLS=@default,create_group`. Full list: [mcp-evolution README](https://github.com/billyfranklim1/mcp-evolution#tools).

## Variables

### User-configurable (`Evolution MCP`)

| Variable | Default | Notes |
|---|---|---|
| `EVOLUTION_INSTANCES` | `whatsapp` | Instance names the tools may use, comma-separated |
| `EVOLUTION_DEFAULT_INSTANCE` | `whatsapp` | Used when a call names no instance |
| `EVOLUTION_ALLOWED_TOOLS` | not set (all non-dangerous tools) | Tool names and groups: `@read`, `@send`, `@default`, `@dangerous` |
| `EVOLUTION_ALLOWED_RECIPIENTS` | not set (any chat) | Numbers, JIDs, `*@g.us`. Per instance: `EVOLUTION_ALLOWED_RECIPIENTS__<NAME>` |
| `MCP_EVOLUTION_REF` | `44f1999…` | mcp-evolution commit built at start. Change it to upgrade |

### Generated

| Service | Variable | Notes |
|---|---|---|
| Evolution MCP | `MCP_AUTH_TOKEN` | Bearer token, 48 letters and digits. Change it to rotate (at least 32 characters) |
| Evolution API | `AUTHENTICATION_API_KEY` | Global key, `apikey` header, manager login. The MCP server picks up a new value after its redeploy |

### Auto-configured (do not change)

| Service | Variable | Value |
|---|---|---|
| Evolution MCP | `MCP_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}/mcp` |
| Evolution MCP | `EVOLUTION_API_URL`, `EVOLUTION_API_KEY` | `http://${{Evolution API.RAILWAY_PRIVATE_DOMAIN}}:${{Evolution API.PORT}}`, `${{Evolution API.AUTHENTICATION_API_KEY}}` |
| Evolution MCP | `MCP_TRANSPORT`, `MCP_HTTP_PATH`, `HOST`, `PORT` | `http`, `/mcp`, `::`, `3000` |
| Evolution MCP | `MCP_RUN_SH` | Start script: downloads and builds `MCP_EVOLUTION_REF`, then starts the server |
| Evolution API | `SERVER_URL`, `DATABASE_CONNECTION_URI`, `CACHE_REDIS_URI` | Public domain, `${{Evolution Postgres.DATABASE_URL}}`, `${{Evolution Redis.REDIS_URL}}` |

The optional `EVOLUTION_DB_URL` of mcp-evolution (needed only by `get_group_resolved_participants`) is not set, so the MCP server has no direct database access.

## Custom domains

- Evolution API: add the domain, set `SERVER_URL=https://your-domain`.
- Evolution MCP: add the domain and use `https://your-domain/mcp`; `MCP_URL` shows the Railway domain.

## Upgrading

- Evolution API: change the image tag. Avoid `latest`, `homolog` and `-rc` tags; 2.4.0 and later need a license activation.
- mcp-evolution: set `MCP_EVOLUTION_REF` to a newer full commit SHA from the repository's `main` branch after reading its changelog.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `401 Unauthorized` from `/mcp` | Missing or wrong `Authorization: Bearer` header. In `mcp-remote`, keep `Authorization:${AUTH_HEADER}` without a space |
| `405 Method not allowed` | The server is stateless and answers POST only; clients that require a GET event stream aren't supported |
| Tool error `Evolution API error 404 ... instance does not exist` | Create the instance with the name in `EVOLUTION_INSTANCES`, or change the variable |
| `Input validation error ... invalid_enum_value` for `instance` | The instance isn't in `EVOLUTION_INSTANCES` |
| A tool is missing from the list | It is dangerous and off by default, or `EVOLUTION_ALLOWED_TOOLS` excludes it |
| State `close` or `connecting` | Pair again with `/instance/connect/<name>` (QR code or `?number=` pairing code) |
| Evolution MCP crashes after you edit `EVOLUTION_INSTANCES` | `EVOLUTION_DEFAULT_INSTANCE` must be one of the listed names, or empty |
| Evolution MCP doesn't start | Its logs show the build; it needs GitHub and the npm registry reachable at start |

Use the `WHATSAPP-BAILEYS` integration (QR code or pairing code) for real numbers. In Evolution API 2.3.7 the built-in `EVOLUTION` test channel accepts messages on `/webhook/evolution` without the API key, so anyone who knows such an instance's number can inject messages that your agent then reads. Keep production instances on `WHATSAPP-BAILEYS`.

An agent with send tools can message anyone on your behalf. Use the recipient allowlist while you try it out. WhatsApp may ban numbers that send bulk or unsolicited messages. Evolution API and mcp-evolution are not affiliated with WhatsApp or Meta.

## License

- Evolution API: Apache License 2.0 with extra [conditions](https://github.com/EvolutionAPI/evolution-api/blob/main/LICENSE): keep the logo and copyright in the manager, and a product built on it must say so where administrators can see it.
- mcp-evolution: [MIT](https://github.com/billyfranklim1/mcp-evolution/blob/main/LICENSE).

## Testing

Tested on 2026-11-10 with a test deploy of the template draft: all four services healthy, the MCP server built the pinned commit at start. Evolution API refused requests without a key and with a wrong key (401). The MCP endpoint refused requests with no token, a wrong token, the token with a character added or removed, Basic auth, the token in the query string and the Evolution key as `apikey` (401), answered 405 to GET, and `/health` returned only `{"status":"ok"}`. With the token, raw JSON-RPC and the official MCP Python SDK initialized and listed 34 tools (no dangerous ones); the tools called were `list_instances`, `connection_state`, `find_messages` and `send_text`. On an instance on the built-in EVOLUTION channel, `list_instances` and `connection_state` reported it open, a simulated incoming message came back through `find_messages`, and a message sent with `send_text` was stored by Evolution API. The Evolution key never appeared in a tool result. After redeploying Evolution API and its Postgres the instance was still there; after adding a second instance to `EVOLUTION_INSTANCES` the MCP server rebuilt, offered the `instance` argument and refused an instance outside the list. Not tested: a real WhatsApp number (the QR code was not scanned, so no real messages were sent or received); MCP clients other than raw JSON-RPC and the Python SDK (Claude Code with `claude mcp add`, Claude Desktop with `mcp-remote`); media, group and label tools, including `download_media`.
