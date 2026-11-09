# Neo4j MCP 2.1

Let Claude, Cursor or any MCP client query and update a Neo4j graph in plain language (Text2Cypher). The agent reads the schema, writes Cypher, runs it and answers from the results. This template runs the official [Neo4j MCP server](https://github.com/neo4j/mcp) (`neo4j/mcp`, by Neo4j, GPL-3.0) next to a Neo4j 2026.10 Community database, behind a bearer-token proxy.

**Clients only hold one token.** In HTTP mode the Neo4j MCP server expects every request to carry the Neo4j user and password (Basic auth) and the Bolt address (`X-Neo4j-MCP-URI` header). Here the MCP server is private, and the only public service is a small Caddy proxy. It checks `Authorization: Bearer <PROXY_TOKEN>` on every request, then adds the Neo4j credentials and the private Bolt address itself. The database password never leaves Railway's private network, and a client can't point the server at another database.

## Architecture

```
MCP client (Claude, Cursor, agents)
   │  HTTPS, Authorization: Bearer <PROXY_TOKEN>
   ▼
┌──────────────────────────┐   private network     ┌──────────────────────────┐   Bolt TLS (bolt+ssc)   ┌───────────────────────────┐
│ Token Proxy (public)     │ ────────────────────▶ │ Neo4j MCP (private)      │ ──────────────────────▶ │ Neo4j (Browser public,    │
│ caddy:2.11.9-alpine :8080│ http :8000            │ neo4j/mcp:v2.1.0         │        :7687            │ password; Bolt TCP proxy) │
│ 401 without the token    │ /db/neo4j/mcp         │ streamable HTTP          │                         │ neo4j:2026.10.1-community │
│ sets Neo4j Basic auth +  │ + Basic auth          │                          │                         │ APOC, volume /data        │
│ X-Neo4j-MCP-URI          │ + X-Neo4j-MCP-URI     │                          │                         │                           │
└──────────────────────────┘                       └──────────────────────────┘                         └───────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Token Proxy | `caddy:2.11.9-alpine` | Public HTTPS. Checks the bearer token, rewrites `/mcp` to `/db/neo4j/mcp`, sets the Neo4j credentials and Bolt address, streams responses |
| Neo4j MCP | `neo4j/mcp:v2.1.0` | Official Neo4j MCP server, HTTP transport, private, no domain |
| Neo4j | `neo4j:2026.10.1-community` | Graph database with APOC (the MCP server's `get-schema` needs it), volume. Browser over HTTPS and a Bolt TCP proxy (TLS, self-signed certificate), both behind a generated password |

No LLM key is needed: your MCP client's own model writes the Cypher.

## After deploy

1. Open the **Token Proxy** service, Variables tab. Copy `MCP_URL` (`https://<domain>/mcp`) and `PROXY_TOKEN`.
2. Add the server to your client (below).
3. Ask something like "What is in my graph?" or "Create a small graph of my team and the projects we work on". The agent calls `get-schema`, then `read-cypher` or `write-cypher`.

### Claude Code

```bash
claude mcp add --transport http neo4j https://<domain>/mcp \
  --header "Authorization: Bearer <PROXY_TOKEN>"
```

### Cursor (`~/.cursor/mcp.json` or `.cursor/mcp.json`)

```json
{
  "mcpServers": {
    "neo4j": {
      "url": "https://<domain>/mcp",
      "headers": { "Authorization": "Bearer <PROXY_TOKEN>" }
    }
  }
}
```

VS Code (`.vscode/mcp.json`) takes the same `url` and `headers` under `"servers"` with `"type": "http"`.

### Claude Desktop

Claude Desktop's "Add custom connector" dialog has fields for a URL and optional OAuth client details but none for custom headers (as of Nov 2026), so it can't send the token directly. Use the `mcp-remote` bridge (needs Node.js) in `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "neo4j": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://<domain>/mcp", "--header", "Authorization:${NEO4J_MCP_AUTH}"],
      "env": { "NEO4J_MCP_AUTH": "Bearer <PROXY_TOKEN>" }
    }
  }
}
```

### Any client, by hand

```bash
curl -s https://<domain>/mcp \
  -H "Authorization: Bearer <PROXY_TOKEN>" \
  -H "Content-Type: application/json" -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl","version":"1"}}}'
```

Without the header the proxy answers `401`. `/mcp`, `/mcp/` and `/db/neo4j/mcp` all work.

## MCP tools

| Tool | What it does |
|------|--------------|
| `get-schema` | Labels, relationship types and properties, sampled with APOC (`NEO4J_MCP_SCHEMA_SAMPLE_SIZE` nodes per label) |
| `read-cypher` | Runs a read-only query. The server checks the query type with `EXPLAIN` and refuses writes |
| `write-cypher` | Runs a query that changes data. Hidden when `NEO4J_MCP_READ_ONLY=true` |
| `list-gds-procedures` | Only listed when the Graph Data Science plugin is installed (it isn't by default) |

## Environment variables

### User-configurable (Neo4j MCP service)

| Variable | Default | Notes |
|----------|---------|-------|
| `NEO4J_MCP_READ_ONLY` | `false` | `true` hides `write-cypher`, so agents can only read |
| `NEO4J_MCP_SCHEMA_SAMPLE_SIZE` | `100` | Nodes sampled per label by `get-schema` |
| `NEO4J_MCP_LOG_LEVEL` | `info` | `debug` to see every tool call |
| `NEO4J_MCP_TELEMETRY` | `false` | Upstream's anonymous usage telemetry, off here |

### User-configurable (Token Proxy service)

| Variable | Default | Notes |
|----------|---------|-------|
| `PROXY_TOKEN` | generated, 48 letters and digits | Change it to rotate the token. Letters and digits only, at least 32 characters; the proxy refuses to start otherwise |
| `CADDYFILE` | the proxy rules | Caddy configuration written at start |

### Auto-configured (do not change)

| Variable | Service | Value | Why |
|----------|---------|-------|-----|
| `NEO4J_MCP_TRANSPORT_MODE` | Neo4j MCP | `http` | Streamable HTTP instead of stdio |
| `NEO4J_MCP_HTTP_HOST` / `NEO4J_MCP_HTTP_PORT` | Neo4j MCP | `[::]`, `8000` | IPv4 and IPv6 (upstream's default is `127.0.0.1:80`). The service has no domain, so only the proxy reaches it |
| `NEO4J_MCP_HTTP_ALLOWED_URIS` | Neo4j MCP | `${{Neo4j.RAILWAY_PRIVATE_DOMAIN}}:7687` | The only database the server may connect to |
| `UPSTREAM_URL` | Token Proxy | `http://${{Neo4j MCP.RAILWAY_PRIVATE_DOMAIN}}:8000` | Where authorized requests go |
| `NEO4J_USER` / `NEO4J_PASSWORD` | Token Proxy | `${{Neo4j.DB_USER}}`, `${{Neo4j.DB_PASSWORD}}` | Sent to the MCP server as Basic auth on the private network |
| `NEO4J_BOLT_URL` | Token Proxy | `${{Neo4j.BOLT_URL}}` | Sent as `X-Neo4j-MCP-URI` (`bolt+ssc://`, Bolt over TLS). A header sent by the client is overwritten |
| `NEO4J_DATABASE` | Token Proxy | `neo4j` | `/mcp` is rewritten to `/db/neo4j/mcp` |
| `MCP_URL` / `PUBLIC_URL` | Token Proxy | `https://${{RAILWAY_PUBLIC_DOMAIN}}/mcp` | For copying into clients |
| Neo4j variables | Neo4j | memory limits, Bolt TLS, generated password | See the [Neo4j template](../neo4j/) |

If you change the Neo4j password (`ALTER USER` in Cypher), update `DB_PASSWORD` on the Neo4j service too; the proxy reads it from there.

## Bring your own data

- **Neo4j Browser**: open `BROWSER_URL` from the Neo4j service and log in as `neo4j` with `DB_PASSWORD`. Paste Cypher, or use `LOAD CSV` from a public URL.
- **Drivers**: connect to `BOLT_PUBLIC_URL` (`bolt+ssc://`, TLS through the TCP proxy) from any Neo4j driver.
- **Your agent**: ask it to create nodes and relationships with `write-cypher`.

## Security notes

- The proxy checks the token before anything reaches the MCP server. Only `/healthz` (answered by the proxy itself) is open. Basic auth with the Neo4j password is refused at the proxy too.
- The token is a single shared secret with full database access through `write-cypher`, including deleting everything. Set `NEO4J_MCP_READ_ONLY=true` if your agents only need to read.
- Data in the graph reaches your agent's context. Don't let an agent with `write-cypher` act on graph content from untrusted sources.
- Neo4j Browser and the Bolt TCP proxy are protected by the generated Neo4j password. Remove the Neo4j domain and TCP proxy if you don't need them.

## Resources and costs

Measured on Railway at idle: Neo4j about 1.24 GB, Neo4j MCP 0.007 GB, proxy 0.016 GB. Most of the memory is the Neo4j JVM (heap 512 MB plus page cache 256 MB); the MCP server is a small Go binary and the proxy is Caddy.

## Troubleshooting

- **401 from the proxy**: the header must be exactly `Authorization: Bearer <PROXY_TOKEN>` (one space). Check that the client really sends headers (Claude Desktop's connector dialog has no header field; use `mcp-remote`).
- **Initialize fails with a connection or authentication error**: Neo4j is still starting (give it a minute after the first deploy), or the Neo4j password was changed in Cypher but not in `DB_PASSWORD`.
- **`get-schema` returns nothing**: the database is empty. Add data first.

## Test notes

2026-11-10, deploy of the stored template config on Railway:

- All three services healthy. Neo4j MCP has no public domain; the proxy forwards to `http://neo4j-mcp.railway.internal:8000`.
- Proxy: `/healthz` returns 200. On `/mcp` and `/db/neo4j/mcp`, no token, a wrong token, the token plus extra characters, Basic auth, and even the real Neo4j password as Basic auth all return 401.
- With the token, an MCP client (Python `mcp` SDK 2.3, streamable HTTP) on `/mcp`, `/mcp/` and `/db/neo4j/mcp` initialized (server `neo4j-mcp v2.1.0`; initialize checks the Neo4j connection and APOC), listed `get-schema`, `read-cypher`, `write-cypher`, and ran `get-schema`.
- `write-cypher` created a node, `read-cypher` read it back, and `read-cypher` refused a `CREATE`. The node was found through Neo4j's HTTPS Query API, outside MCP.
- The client also sent `X-Neo4j-MCP-URI: bolt://attacker.example.com:7687`; the MCP server's log shows every request went to `bolt+ssc://neo4j.railway.internal:7687` (the proxy overwrites the header). The Neo4j password does not appear in the MCP server's or the proxy's logs.
- Memory at idle: Neo4j 1.23–1.24 GB, Neo4j MCP 0.007 GB, Token Proxy 0.016 GB.
- Not tested: `NEO4J_MCP_READ_ONLY=true`, and the Claude Desktop `mcp-remote` bridge.
