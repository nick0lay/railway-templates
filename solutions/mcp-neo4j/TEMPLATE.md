# Deploy and Host Neo4j MCP 2.1 on Railway

Neo4j MCP is the official Model Context Protocol server from Neo4j. It lets Claude, Cursor or any MCP client explore and query a Neo4j graph in plain language (Text2Cypher): the agent reads the schema, writes Cypher, runs it and answers from the results. This template runs it next to a Neo4j 2026.10 Community database, behind a bearer-token proxy.

## About Hosting Neo4j MCP 2.1

In HTTP mode the Neo4j MCP server expects every request to carry the Neo4j user and password and the database address. Here the MCP server (`neo4j/mcp:v2.1.0`) is private, and the only public service is a small Caddy proxy that requires `Authorization: Bearer <token>` on every request. The token is generated at deploy. The proxy then adds the Neo4j credentials and the private Bolt address itself, so your clients hold only the token, the database password stays on Railway's private network, and nobody can point the server at another database. The MCP server talks to Neo4j over Bolt encrypted with TLS. Neo4j keeps the graph on a volume, ships with APOC (needed for schema discovery) and has its memory capped (512 MB heap, 256 MB page cache). Neo4j Browser and a Bolt TCP proxy are protected by a generated password. All images are pinned. No LLM API key is needed: your MCP client's model writes the Cypher.

## Common Use Cases

- Ask questions about your graph from Claude Code, Claude Desktop, Cursor or VS Code ("Which customers bought products from more than three categories?")
- Let an agent build and update a knowledge graph with `write-cypher`, or keep it read-only with one variable
- A shared graph backend for agent frameworks (LangGraph, CrewAI, custom agents) over MCP
- Exploring and fixing data in Neo4j Browser alongside your agent

## Dependencies for Neo4j MCP 2.1 Hosting

- Neo4j MCP server 2.1.0 (`neo4j/mcp:v2.1.0`), private
- Token Proxy (`caddy:2.11.9-alpine`), public, bearer token required
- Neo4j 2026.10.1 Community with APOC (`neo4j:2026.10.1-community`), Browser and Bolt TCP proxy behind its password, Bolt TLS, volume

### Deployment Dependencies

- Neo4j MCP on GitHub: https://github.com/neo4j/mcp
- Neo4j MCP documentation: https://neo4j.com/docs/mcp/current/
- Model Context Protocol: https://modelcontextprotocol.io

### Implementation Details

After deploy, open the **Token Proxy** service's Variables tab and copy `MCP_URL` and `PROXY_TOKEN`.

Claude Code:

```bash
claude mcp add --transport http neo4j https://<domain>/mcp \
  --header "Authorization: Bearer <PROXY_TOKEN>"
```

Cursor (`~/.cursor/mcp.json`):

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

Claude Desktop's custom connector dialog has no field for custom headers, so use the `mcp-remote` bridge in `claude_desktop_config.json`:

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

Requests without the token get `401`. The tools are `get-schema` (labels, relationships and properties via APOC), `read-cypher` (read-only queries, writes refused) and `write-cypher`.

| Variable (Neo4j MCP service) | Default | Purpose |
|---|---|---|
| `NEO4J_MCP_READ_ONLY` | `false` | `true` hides `write-cypher` |
| `NEO4J_MCP_SCHEMA_SAMPLE_SIZE` | `100` | Nodes sampled per label by `get-schema` |
| `NEO4J_MCP_LOG_LEVEL` | `info` | `debug` logs every tool call |
| `NEO4J_MCP_TELEMETRY` | `false` | Upstream usage telemetry, off |

The token gives full database access through `write-cypher`, so share it only with clients you trust, or set `NEO4J_MCP_READ_ONLY=true`. Rotate the token by changing `PROXY_TOKEN` on the Token Proxy. Load your own data in Neo4j Browser (`BROWSER_URL` on the Neo4j service, user `neo4j`, password `DB_PASSWORD`) or with any driver through `BOLT_PUBLIC_URL` (`bolt+ssc://`).

In our test at idle, Neo4j used about 1.24 GB of RAM, the MCP server under 0.01 GB and the proxy under 0.02 GB.

## Why Deploy Neo4j MCP 2.1 on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Neo4j MCP 2.1 on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
