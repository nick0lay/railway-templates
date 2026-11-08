# Deploy and Host NVIDIA Auto Ontology on Railway

NVIDIA Auto Ontology builds a semantic layer over your databases. It reads their schemas, works out what tables, columns and joins mean, and keeps a glossary of business terms. You ask questions in plain language and get answers with the SQL behind them. AI agents get the same layer through an MCP server, so they ask your data questions with your definitions instead of guessing at raw tables.

## About Hosting NVIDIA Auto Ontology

Auto Ontology is four services on PostgreSQL:

- **Web app:** login, the UI and the public API.
- **Python API:** text-to-SQL and the catalog.
- **Ingestion service:** reads your databases and builds embeddings.
- **MCP server:** for agents.

Hosting it yourself means running two schema migrations before the apps start, keeping the Python API off the internet, and pointing four kinds of model (reasoning, extraction, embeddings, rerank) at an endpoint. NVIDIA's images also listen on IPv4 only.

This template runs NVIDIA's official 1.2.0 images and loads a sample database so you can try it right away. It creates your admin account at deploy and turns sign-up off. Only the web app and the MCP server are public, and both require a login. The migrations run on start, and the API and ingestion service work on Railway's private network.

## Common Use Cases

- Ask questions about a Postgres, Snowflake, ClickHouse, Trino or MySQL database in plain language and see the SQL
- Give AI agents (Cursor, Claude, internal agents) governed access to your data through MCP, as the signed-in user
- Build and maintain a business glossary and semantic layer that maps terms like "active customer" to tables and rules
- Explore an unfamiliar database: generated descriptions of tables, columns and join paths
- Query your data from scripts and notebooks with personal API tokens

## Dependencies for NVIDIA Auto Ontology Hosting

- PostgreSQL 17
- A model API key: a free `nvapi-` key from build.nvidia.com by default, or another OpenAI-compatible endpoint

### Deployment Dependencies

- Auto Ontology: https://github.com/NVIDIA/auto-ontology
- NVIDIA API catalog (model keys): https://build.nvidia.com
- MCP setup: https://github.com/NVIDIA/auto-ontology/blob/main/docs/mcp.md

### Implementation Details

**What you set:**

- `AUTO_ONTOLOGY_ADMIN_EMAIL`, your login.
- `DEFAULT_MODELS_API_KEY`, your model key.

**After deploy:**

1. Open the Auto Ontology URL and log in with `AUTO_ONTOLOGY_ADMIN_EMAIL` and the generated `AUTO_ONTOLOGY_ADMIN_PASSWORD` (Auto Ontology service → Variables).
2. Ask a question about the bundled Chinook music-store database.
3. Point `CONNECTION_STRINGS` (API service) at your own databases, or clear it and add connections in Settings.
4. Add `https://<your MCP domain>/mcp` to your AI client and sign in when it asks.

**This template:**

- Creates the admin at deploy with sign-up disabled; others join by invitation
- Keeps the Python API, the ingestion service and PostgreSQL private; every API call goes through the web app's permission checks
- Protects the MCP server with OAuth tokens that Auto Ontology issues to signed-in users
- Loads the Chinook sample database on first start, with a read-only user, so there is data to query immediately
- Runs both migrations on start instead of separate one-shot jobs
- Binds the API and ingestion service to IPv6 and IPv4 for Railway's private network
- Pins NVIDIA's 1.2.0 images by digest, with PostgreSQL 17

**Notes:**

- The five services idle at about 1.2 GB of RAM, with no GPU needed: the models run on NVIDIA's hosted API or your own endpoint.
- Model usage is billed by your model provider.

## Why Deploy NVIDIA Auto Ontology on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying NVIDIA Auto Ontology on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
