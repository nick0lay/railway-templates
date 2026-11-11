# Deploy and Host Odoo 20 + MCP on Railway

Odoo is open-source business software: CRM, sales, invoicing and accounting, inventory, purchase, manufacturing and projects in one database. This template runs Odoo Community 20 with an MCP server, so Claude, Cursor and other AI agents can look up customers, leads, quotations, invoices and stock, and create or update records, through a protected endpoint. The agent works as its own restricted Odoo user, never as the administrator.

## About Hosting Odoo 20 + MCP

Odoo needs PostgreSQL, a volume for attachments and a database with an administrator before anyone can log in, and a default container leaves the database manager open. Odoo Community has no built-in MCP server, and the open-source Odoo MCP servers have no authentication of their own, so they must not be exposed directly.

This template runs the official `odoo:20.0` image with PostgreSQL 18, created and locked down at deploy. The MCP server ([mcp-server-odoo](https://github.com/ivnvxd/mcp-server-odoo)) runs privately and logs in to Odoo as a dedicated user it creates on first start. A small Caddy proxy is the only public MCP entry point and requires a generated token.

## Common Use Cases

- Ask Claude "Which invoices are overdue?" or "What did Acme order this year?" and get answers from your own Odoo
- Let an agent create leads, contacts and draft quotations from e-mails or meeting notes
- Check stock levels, open purchase orders and project tasks from Claude Code or Cursor
- Build automations where an AI agent reads and updates ERP records under its own login
- Run CRM, invoicing, inventory and manufacturing for a small or mid-size company, with AI access built in

## Dependencies for Odoo 20 + MCP Hosting

- PostgreSQL 18 (private)
- mcp-server-odoo 0.9.0 (private)
- Caddy token proxy (public MCP endpoint)

### Deployment Dependencies

- Odoo: https://github.com/odoo/odoo
- Official image: https://hub.docker.com/_/odoo
- MCP server: https://github.com/ivnvxd/mcp-server-odoo
- Model Context Protocol: https://modelcontextprotocol.io

### Implementation Details

**What you set:** nothing. The Odoo admin password, the agent's password, the MCP token and the database password are generated.

**After deploy:**

1. Wait about a minute, then open the Odoo URL and log in as `admin` with `ODOO_ADMIN_PASSWORD` (Odoo service, Variables).
2. Install the apps you use from **Apps** (CRM, Sales, Invoicing, Inventory, ...). The agent's user gets user-level access to them within 5 minutes.
3. Connect Claude. In the **Token Proxy** service, Variables:
   - **claude.ai / Claude Desktop:** Settings > Connectors > Add custom connector, paste `CONNECTOR_URL` (the token is in the URL; keep it secret).
   - **Claude Code:** `claude mcp add --transport http odoo <MCP_URL> --header "Authorization: Bearer <PROXY_TOKEN>"`
4. Ask Claude about your Odoo data.

**This template:**

- Uses the official `odoo:20.0-20261102` image (pinned) with PostgreSQL 18; the database and admin are created on first start, `admin` / `admin` never works
- Disables Odoo's database manager and database list, and sets a generated master password
- Listens on 0.0.0.0 with proxy mode, threaded so the websocket works on one port; SMTP is optional
- Never recreates an existing database; updates modules automatically after an image change
- Creates an Odoo user `mcp` ("AI Agent (MCP)") without admin rights for the agent, and grants it user-level Sales, Invoicing, Inventory, Purchase, Project and Manufacturing access as you install those apps
- Runs mcp-server-odoo 0.9.0 privately over streamable HTTP; tools to search, read, aggregate, create, update and delete records, post to the chatter and handle attachments, all limited by that user's Odoo rights
- Puts a Caddy proxy in front: every MCP request needs the 48-character token, as a Bearer header or in the connector URL
- Keeps Odoo's attachments and Postgres data on volumes, Postgres and the MCP server private

**Notes:** restrict the agent further in Odoo (Settings > Users > AI Agent (MCP)) or make it read-only with `ODOO_YOLO=read`. Never give it the admin account. Anyone with the token or the connector URL acts as the agent's user; rotate by changing `PROXY_TOKEN`. Odoo Enterprise apps are not included.

## Why Deploy Odoo 20 + MCP on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Odoo 20 + MCP on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
