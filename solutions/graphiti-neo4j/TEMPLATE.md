# Deploy and Host Graphiti 0.31 MCP + Neo4j on Railway

Graphiti is Zep's open-source temporal knowledge graph for AI agent memory. Agents send it what they learn, an LLM extracts entities and facts, and Graphiti stores them in Neo4j with the time each fact was valid. Claude, Cursor or any MCP client can then search that memory. This template runs the official Graphiti MCP server behind a bearer-token proxy.

## About Hosting Graphiti 0.31 MCP + Neo4j

Upstream's MCP server has no authentication: Zep calls it a reference implementation and warns not to expose it to an untrusted network. Other Graphiti templates put it on a public domain anyway. Here the MCP server (`zepai/knowledge-graph-mcp:1.1.3-graphiti-0.31.2`) is private, and the only public service is a small Caddy proxy that requires `Authorization: Bearer <token>` on every request. The token is generated at deploy. Responses stream through without buffering (MCP streamable HTTP). Graphiti talks to Neo4j 2026.10 Community over the private network with Bolt encrypted by TLS. Neo4j keeps the graph on a volume, and its memory is capped (512 MB heap, 256 MB page cache). Neo4j Browser and a Bolt TCP proxy are protected by a generated password. All images are pinned. You only enter your OpenAI (or OpenAI-compatible) API key.

## Common Use Cases

- Long-term memory for Claude Code, Claude Desktop, Cursor or VS Code: preferences, project decisions and procedures that persist across sessions
- Shared memory for a team of agents, with one `group_id` per user or project
- A temporal knowledge graph for agent frameworks (LangGraph, CrewAI, custom agents) that tracks how facts change over time
- Exploring what your agents know in Neo4j Browser with Cypher

## Dependencies for Graphiti 0.31 MCP + Neo4j Hosting

- Graphiti MCP server 1.1.3 with graphiti-core 0.31.2 (`zepai/knowledge-graph-mcp:1.1.3-graphiti-0.31.2-standalone`), private
- Token Proxy (`caddy:2.11.9-alpine`), public, bearer token required
- Neo4j 2026.10.1 Community with APOC (`neo4j:2026.10.1-community`), Browser and Bolt TCP proxy behind its password, Bolt TLS, volume
- An API key for OpenAI or an OpenAI-compatible provider whose models support structured output

### Deployment Dependencies

- Graphiti on GitHub: https://github.com/getzep/graphiti
- MCP server documentation: https://github.com/getzep/graphiti/tree/v0.31.2/mcp_server
- Model Context Protocol: https://modelcontextprotocol.io

### Implementation Details

After deploy, open the **Token Proxy** service's Variables tab and copy `MCP_URL` and `PROXY_TOKEN`.

Claude Code:

```bash
claude mcp add --transport http graphiti https://<domain>/mcp \
  --header "Authorization: Bearer <PROXY_TOKEN>"
```

Cursor (`~/.cursor/mcp.json`):

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

Claude Desktop's custom connector dialog has no field for custom headers, so use the `mcp-remote` bridge in `claude_desktop_config.json`:

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

Requests without the token get `401`. The tools are `add_memory`, `search_nodes`, `search_memory_facts`, `get_episodes`, `delete_episode`, `add_triplet`, `build_communities`, `clear_graph` and more. `add_memory` returns at once and extracts in the background (10 to 60 seconds).

| Variable (Graphiti service) | Default | Purpose |
|---|---|---|
| `OPENAI_API_KEY` | (you enter it) | LLM extraction and embeddings |
| `OPENAI_API_URL` | `https://api.openai.com/v1` | Any OpenAI-compatible API |
| `MODEL_NAME` | `gpt-5.4-mini` | Extraction model (needs structured output) |
| `EMBEDDER_MODEL` | `text-embedding-3-small` | Keep it fixed after the first memory |
| `GRAPHITI_GROUP_ID` | `main` | Default memory namespace |
| `SEMAPHORE_LIMIT` | `5` | Parallel extractions; lower it on 429 errors |

The token gives full access to every group, so share it only with clients you trust. Text stored as memory comes back to your agent later, so don't store memories from untrusted sources (upstream has no prompt-injection protection). Rotate the token by changing `PROXY_TOKEN`.

In our test at idle, Neo4j used 1.0 to 1.25 GB of RAM, Graphiti about 0.25 GB and the proxy under 0.02 GB. Your LLM provider bills extraction and embeddings separately. For a lighter setup with the graph database inside the Graphiti service, use the **Graphiti 0.31 MCP + FalkorDB** template.

## Why Deploy Graphiti 0.31 MCP + Neo4j on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Graphiti 0.31 MCP + Neo4j on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
