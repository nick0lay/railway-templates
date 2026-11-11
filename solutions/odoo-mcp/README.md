# Odoo 20 + MCP

Odoo Community 20 with an MCP server, so Claude, Cursor and other AI agents can search, read, create and update Odoo records: contacts, leads, quotations, invoices, products, stock. The agent works as its own restricted Odoo user, and the MCP endpoint is protected by a generated token.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/odoo-20-mcp?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

The Odoo and Postgres services are the same as in [Odoo 20](../odoo/): generated admin password, database manager off, SMTP optional. This template adds:

- **Odoo MCP**: [ivnvxd/mcp-server-odoo](https://github.com/ivnvxd/mcp-server-odoo) 0.9.0 (MPL-2.0), private, streamable HTTP. It has no authentication of its own, so it has no domain.
- **Token Proxy**: Caddy, the only public MCP entry point. Every request needs the generated `PROXY_TOKEN`.

## Architecture

```
Claude / Cursor / agents                                   Browser
   │ HTTPS: Authorization: Bearer <PROXY_TOKEN>               │ HTTPS
   │    or  https://<proxy>/<PROXY_TOKEN>/mcp                 ▼
   ▼                                              ┌──────────────────────────┐
┌──────────────────────────┐  private   ┌──────────────────────┐  XML-RPC   │ Odoo (public)            │
│ Token Proxy (public)     │ ─────────▶ │ Odoo MCP (private)   │ ─────────▶ │ odoo:20.0-20261102 :8069 │
│ caddy:2.11.9-alpine :8080│ http :8000 │ mcp-server-odoo 0.9.0│ as user    │ volume /var/lib/odoo     │
│ 401 without the token    │   /mcp     │ no domain            │ "mcp"      └────────────┬─────────────┘
└──────────────────────────┘            └──────────────────────┘                         │ private
                                                                           ┌────────────▼─────────────┐
                                                                           │ Postgres (private) 18    │
                                                                           └──────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Odoo | `odoo:20.0-20261102` | Odoo web app (public), same as the Odoo 20 template |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Database (private) |
| Odoo MCP | `ivnvxd/mcp-server-odoo:0.9.0` | MCP server, streamable HTTP on `:8000/mcp` (private, no domain) |
| Token Proxy | `caddy:2.11.9-alpine` | Public HTTPS for MCP clients; checks the token, streams responses |

## How the agent logs in

On first start the Odoo MCP service creates an Odoo user `mcp` ("AI Agent (MCP)") with a generated password (`ODOO_PASSWORD`), as an **internal user without admin rights**. The MCP server logs in as that user, so Odoo's own access rights decide what the agent can see and change. Records the agent creates show "AI Agent (MCP)" as author.

The user gets the groups in `MCP_USER_GROUPS` as their apps are installed (checked every 5 minutes): user level for Sales (all leads), Invoicing (billing), Inventory, Purchase, Project, Manufacturing, and contact creation. It never gets Settings, user management or accounting manager rights. A group you remove from the user in Odoo stays removed. To make the agent read-only, set `ODOO_YOLO=read` on the Odoo MCP service.

Why not the admin account or an API key: admin would give the agent every right in Odoo, including users and settings. Odoo 20 API keys can only be created by the user themselves in the browser, with a password check, so they can't be created at deploy; the server uses the dedicated user's password over Odoo's XML-RPC instead. The MCP server's "standard" mode (per-model allow-lists) needs an Odoo addon that the official image doesn't ship, so this template uses its plain-Odoo mode ("YOLO" in upstream's docs), restricted by the Odoo user's rights.

## Connect Claude

Open the **Token Proxy** service, Variables tab:

- `MCP_URL` (`https://<proxy-domain>/mcp`) with `PROXY_TOKEN`, for clients that can send a header
- `CONNECTOR_URL` (`https://<proxy-domain>/<PROXY_TOKEN>/mcp`), for clients that only take a URL. Treat it like a password

### claude.ai and Claude Desktop (custom connector)

Settings > Connectors > **Add custom connector**. Name: `Odoo`. URL: paste `CONNECTOR_URL`. Leave the OAuth fields empty. Then enable the connector in a chat and ask, for example, "List my open quotations" or "Create a lead for Acme Corp".

The connector dialog has no field for a header, which is why the token is part of this URL. Anyone with the URL has the agent's access, so don't share it; to rotate, change `PROXY_TOKEN` (both URLs change).

### Claude Code

```bash
claude mcp add --transport http odoo https://<proxy-domain>/mcp \
  --header "Authorization: Bearer <PROXY_TOKEN>"
```

### Cursor, VS Code and other clients

```json
{
  "mcpServers": {
    "odoo": {
      "url": "https://<proxy-domain>/mcp",
      "headers": { "Authorization": "Bearer <PROXY_TOKEN>" }
    }
  }
}
```

VS Code (`.vscode/mcp.json`) takes the same `url` and `headers` under `"servers"` with `"type": "http"`.

### By hand

```bash
curl -s https://<proxy-domain>/mcp \
  -H "Authorization: Bearer <PROXY_TOKEN>" \
  -H "Content-Type: application/json" -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl","version":"1"}}}'
```

Without the token the proxy answers `401`.

## MCP tools

`search_records`, `get_record`, `get_fields`, `aggregate_records`, `list_models`, `get_current_context`, `create_record(s)`, `update_record(s)`, `delete_record`, `post_message` (chatter), `list_record_attachments`, `read_attachment`, `upload_attachment`, and resource templates. All of them run with the `mcp` user's Odoo rights. See [upstream's tool list](https://github.com/ivnvxd/mcp-server-odoo#available-tools).

## Variables

### User-configurable (Odoo MCP service)

| Variable | Default | Notes |
|----------|---------|-------|
| `ODOO_USER` | `mcp` | Login of the agent's Odoo user |
| `ODOO_PASSWORD` | generated, 32 characters | Set again on the user at start if it no longer works; change it here to rotate |
| `MCP_USER_NAME` | `AI Agent (MCP)` | Display name in Odoo |
| `MCP_USER_GROUPS` | user-level app groups | Comma-separated Odoo group XML ids, granted once each when their app is installed |
| `ODOO_YOLO` | `true` | `true`: read and write within the user's rights. `read`: read-only |
| `ODOO_MCP_DEFAULT_LIMIT`, `ODOO_MCP_MAX_LIMIT` | `25`, `100` | Records per search |
| `ODOO_MCP_SESSION_IDLE_TIMEOUT` | `3600` | Seconds |

### User-configurable (Token Proxy service)

| Variable | Default | Notes |
|----------|---------|-------|
| `PROXY_TOKEN` | generated, 48 letters and digits | The only secret MCP clients need. Letters and digits only, at least 32 |
| `CADDYFILE` | see the service | `/healthz` open, `/.well-known/*` 404, `/<PROXY_TOKEN>/mcp` without a header, everything else needs `Authorization: Bearer <PROXY_TOKEN>` |

The Odoo service has the same variables as [Odoo 20](../odoo/README.md#variables).

### Auto-configured (do not change)

| Variable | Value | Why |
|----------|-------|-----|
| `ODOO_URL` | `http://${{Odoo.RAILWAY_PRIVATE_DOMAIN}}:${{Odoo.PORT}}` | MCP talks to Odoo over the private network |
| `ODOO_DB` | `${{Odoo.ODOO_DB}}` | The database list is disabled, so the name must be given |
| `ODOO_ADMIN_LOGIN`, `ODOO_ADMIN_PASSWORD` | from the Odoo service | Used only by the setup step to create the `mcp` user and grant groups. If you change the admin password in Odoo, set the new one here, or groups of newly installed apps are no longer granted (the agent keeps working) |
| `UPSTREAM_URL` (Token Proxy) | `http://${{Odoo MCP.RAILWAY_PRIVATE_DOMAIN}}:8000` | Where the proxy forwards |
| `PORT`, `ODOO_MCP_TRANSPORT`, `ODOO_MCP_HOST`, `ODOO_MCP_PORT`, `MCP_SETUP_PY` | | Server settings and the setup script |

## Security notes

- Give the agent only the rights it needs: open **Settings > Users > AI Agent (MCP)** and remove groups, or use `ODOO_YOLO=read`. Never point `ODOO_USER` at the admin account.
- The token is one shared secret. Everyone who has it (or `CONNECTOR_URL`) acts as the `mcp` user.
- Text in Odoo records (e-mails, notes, product descriptions from customers) is passed to your agent. Treat it as untrusted input, as with any agent that reads business data.
- The MCP server's own `/health` is behind the token too; only the proxy's `/healthz` is open.
- Links in tool results point to the private Odoo address; open records from your Odoo domain.

## Troubleshooting

- **Odoo MCP restarts on the first deploy**: it waits up to 30 minutes for Odoo to create the database, then for the admin login. Check the Odoo logs first.
- **`neither admin nor mcp can log in`**: the admin password was changed in Odoo before the MCP user was created. Set `ODOO_ADMIN_PASSWORD` on the Odoo MCP service to the current admin password and redeploy it.
- **The agent can't see an app's records**: the group is granted within 5 minutes of installing the app; or add it to the user by hand in Odoo.
- **401 from the proxy**: the header must be exactly `Authorization: Bearer <PROXY_TOKEN>`, or use `CONNECTOR_URL`.

## License

Odoo Community Edition is LGPL-3.0. mcp-server-odoo is MPL-2.0. Caddy is Apache-2.0.

## Test notes

2026-11-11, on Railway: all four services healthy. Odoo checks as in the Odoo 20 template (admin/admin refused, database manager off, websocket 101). The setup step created the `mcp` user and granted the groups of installed apps. Through the proxy: no token, a wrong token, the token plus a suffix, Basic auth and a wrong token in the path all return 401; `/.well-known/*` returns 404. With the token, on `/mcp`, `/mcp/` and the connector URL, an MCP client initialized and listed the tools; `get_current_context` ran as `mcp`; `search_records` found a contact the admin had created; `create_record` of a contact worked; creating a `res.users` record was refused by Odoo. The same checks passed after redeploying Odoo, Postgres and Odoo MCP.
