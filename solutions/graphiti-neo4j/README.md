# Graphiti 0.31 MCP + Neo4j

Long-term memory for AI agents over MCP. [Graphiti](https://github.com/getzep/graphiti) (by Zep, Apache-2.0) turns what an agent tells it into a temporal knowledge graph: entities, facts between them, and when each fact was true. Claude, Cursor or any MCP client can add memories and search them back. This template runs the official Graphiti MCP server on Neo4j, behind a bearer-token proxy.

**Upstream's MCP server has no authentication of its own.** Zep calls it a reference implementation and warns not to expose it to an untrusted network. In this template the MCP server is private, and the only public service is a small Caddy proxy that requires `Authorization: Bearer <PROXY_TOKEN>` on every request. The token is generated at deploy.

A lighter variant with FalkorDB inside the Graphiti container (no separate database service) is in [graphiti-falkordb](../graphiti-falkordb/).

## Architecture

```
MCP client (Claude, Cursor, agents)
   │  HTTPS, Authorization: Bearer <PROXY_TOKEN>
   ▼
┌──────────────────────────┐   private network   ┌──────────────────────────┐   Bolt TLS (bolt+ssc)   ┌───────────────────────────┐
│ Token Proxy (public)     │ ──────────────────▶ │ Graphiti (private)       │ ──────────────────────▶ │ Neo4j (Browser public,    │
│ caddy:2.11.9-alpine :8080│   http :8000 /mcp   │ knowledge-graph-mcp      │        :7687            │ password; Bolt TCP proxy) │
│ 401 without the token    │                     │ 1.1.3 (graphiti 0.31.2)  │                         │ neo4j:2026.10.1-community │
└──────────────────────────┘                     └────────────┬─────────────┘                         │ volume /data              │
                                                              │ HTTPS                                 └───────────────────────────┘
                                                              ▼
                                                   OpenAI (or compatible) API
                                                   LLM extraction + embeddings
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Token Proxy | `caddy:2.11.9-alpine` | Public HTTPS. Checks the bearer token, forwards to Graphiti, streams responses without buffering |
| Graphiti | `zepai/knowledge-graph-mcp:1.1.3-graphiti-0.31.2-standalone` | MCP server (streamable HTTP at `/mcp`), private, no domain |
| Neo4j | `neo4j:2026.10.1-community` | Graph database with APOC, volume. Browser over HTTPS and a Bolt TCP proxy (TLS, self-signed certificate), both behind a generated password |

The `-standalone` tag is the MCP server alone (for an external Neo4j or FalkorDB). The tag without `-standalone` bundles FalkorDB; the FalkorDB variant uses that one.

## After deploy

1. Open the **Token Proxy** service, Variables tab. Copy `MCP_URL` (`https://<domain>/mcp`) and `PROXY_TOKEN`.
2. Add the server to your client (below).
3. Ask your agent to remember something, then ask about it later. Each `add_memory` call returns at once; extraction runs in the background and takes 10 to 60 seconds per memory.

### Claude Code

```bash
claude mcp add --transport http graphiti https://<domain>/mcp \
  --header "Authorization: Bearer <PROXY_TOKEN>"
```

### Cursor (`~/.cursor/mcp.json` or `.cursor/mcp.json`)

```json
{
  "mcpServers": {
    "graphiti": {
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
    "graphiti": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://<domain>/mcp", "--header", "Authorization:${GRAPHITI_AUTH}"],
      "env": { "GRAPHITI_AUTH": "Bearer <PROXY_TOKEN>" }
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

Without the header the proxy answers `401`.

## MCP tools

`add_memory`, `search_nodes`, `search_memory_facts`, `get_episodes`, `get_episode_entities`, `get_entity_edge`, `delete_episode`, `delete_entity_edge`, `add_triplet`, `build_communities`, `summarize_saga`, `clear_graph`, `get_status`.

Memories are namespaced by `group_id`. Clients that don't pass one use `GRAPHITI_GROUP_ID` (default `main`). Use one group per user or project to keep memories apart; everyone with the token can read and delete every group.

## Environment variables

### User-configurable (Graphiti service)

| Variable | Default | Notes |
|----------|---------|-------|
| `OPENAI_API_KEY` | (you enter it) | Required. Used for entity extraction and embeddings |
| `OPENAI_API_URL` | `https://api.openai.com/v1` | Any OpenAI-compatible API (OpenRouter, a LiteLLM gateway, vLLM). The model must support structured output (JSON schema) |
| `MODEL_NAME` | `gpt-5.4-mini` | Extraction model |
| `EMBEDDER_MODEL` | `text-embedding-3-small` | Keep it fixed after the first memory (1536-dimensional vectors) |
| `GRAPHITI_GROUP_ID` | `main` | Default namespace |
| `SEMAPHORE_LIMIT` | `5` | Memories processed in parallel. Lower to 1–2 if your provider returns 429 |

Other providers (Anthropic, Gemini, Groq, Azure OpenAI, Voyage embeddings) are configured with `LLM__PROVIDER`, `EMBEDDER__PROVIDER` and the provider's key variable (`ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`, ...). See upstream's [config.yaml](https://github.com/getzep/graphiti/blob/v0.31.2/mcp_server/config/config.yaml). Untested here.

### User-configurable (Token Proxy service)

| Variable | Default | Notes |
|----------|---------|-------|
| `PROXY_TOKEN` | generated, 48 letters and digits | Change it to rotate the token. Letters and digits only, at least 32 characters; the proxy refuses to start otherwise |
| `CADDYFILE` | the proxy rules | Caddy configuration written at start |

### Auto-configured (do not change)

| Variable | Service | Value | Why |
|----------|---------|-------|-----|
| `DATABASE__PROVIDER` | Graphiti | `neo4j` | Upstream defaults to FalkorDB |
| `NEO4J_URI` / `NEO4J_USER` / `NEO4J_PASSWORD` | Graphiti | `${{Neo4j.BOLT_URL}}`, `${{Neo4j.DB_USER}}`, `${{Neo4j.DB_PASSWORD}}` | Bolt over TLS on the private network (`bolt+ssc://`) |
| `SERVER__HOST` / `SERVER__PORT` / `SERVER__TRANSPORT` | Graphiti | `0.0.0.0`, `8000`, `http` | Upstream's default config binds `127.0.0.1`. `::` would be IPv6 only in this server and fails Railway's healthcheck. The service has no domain, so only the proxy reaches it |
| `UPSTREAM_URL` | Token Proxy | `http://${{Graphiti.RAILWAY_PRIVATE_DOMAIN}}:8000` | Where authorized requests go |
| `MCP_URL` / `PUBLIC_URL` | Token Proxy | `https://${{RAILWAY_PUBLIC_DOMAIN}}/mcp` | For copying into clients |
| Neo4j variables | Neo4j | memory limits, Bolt TLS, generated password | See the [Neo4j template](../neo4j/) |

## Explore the graph in Neo4j

Open `BROWSER_URL` from the Neo4j service and log in as `neo4j` with `DB_PASSWORD`:

```cypher
MATCH (n:Entity)-[r:RELATES_TO]->(m:Entity) RETURN n, r, m LIMIT 100
```

Episodes are `:Episodic` nodes linked to the entities they mention by `:MENTIONS`.

## Security notes

- The proxy checks the token before anything reaches Graphiti, including `/health`. Only `/healthz` (answered by the proxy itself) is open.
- The token is a single shared secret with full access: anyone holding it can read, add and delete memories in every group.
- Upstream states the MCP server has no protection against prompt injection: text stored as memory is returned to your agent later. Don't store memories from untrusted sources in a group your agent trusts.
- Neo4j Browser and the Bolt TCP proxy are protected by the generated Neo4j password. Remove the Neo4j domain and TCP proxy if you don't need them.

## Resources and costs

Measured on Railway at idle: Neo4j 1.0–1.25 GB, Graphiti about 0.25 GB, proxy under 0.05 GB. Your LLM provider bills every `add_memory` (extraction plus embeddings) and every search (embeddings) separately. The Graphiti image is about 3.5 GB, so the first deploy takes a few minutes to pull.

## Troubleshooting

- **401 from the proxy**: the header must be exactly `Authorization: Bearer <PROXY_TOKEN>` (one space). Check that the client really sends headers (Claude Desktop's connector dialog has no header field; use `mcp-remote`).
- **Graphiti restarts at first deploy**: it exits if Neo4j isn't accepting connections yet and the restart policy retries; it connects once Neo4j is up.
- **Memories are added but searches return nothing**: extraction failed. Check the Graphiti logs for `401` (wrong API key), `429` (lower `SEMAPHORE_LIMIT`) or a model without structured output support.
- **`EquivalentSchemaRuleAlreadyExists` errors in the Graphiti log at start**: harmless. Graphiti creates its indexes in parallel and Neo4j reports the duplicates.

## Test notes

2026-11-09, on Railway:

- Deploy: all three services healthy. Graphiti logged `Using database: neo4j` and connected over `bolt+ssc://neo4j.railway.internal:7687`.
- Proxy: `/healthz` returns 200. With no token, a wrong token, the token plus extra characters, or Basic auth, `/mcp` returns 401. Graphiti's own `/health` also returns 401 without the token.
- With the token, an MCP client (Python `mcp` SDK 2.3, streamable HTTP) on both `/mcp` and `/mcp/` initialized, listed 13 tools and got `get_status` "connected to neo4j database".
- One real run with OpenAI (`gpt-5.4-mini`, `text-embedding-3-small`):
  - `add_memory` with two sentences about a person, a company and a preference was processed within about 30 seconds.
  - `search_nodes` and `search_memory_facts` returned the extracted entities and facts.
  - Neo4j's HTTPS Query API showed 1 `Episodic` and 6 `Entity` nodes, plus `MENTIONS` and `RELATES_TO` relationships.
- Memory at idle: Neo4j 1.0–1.25 GB, Graphiti 0.24 GB, proxy 0.02–0.04 GB.
