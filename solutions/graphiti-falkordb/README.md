# Graphiti 0.31 MCP + FalkorDB

The lighter variant of [Graphiti 0.31 MCP + Neo4j](../graphiti-neo4j/): the same Graphiti MCP server and bearer-token proxy, with FalkorDB (a Redis-based graph database) running inside the Graphiti container instead of a separate Neo4j service. Client setup, tools, variables and security notes are the same; read the [Neo4j variant's README](../graphiti-neo4j/README.md) for them.

**Upstream's MCP server has no authentication of its own.** The MCP server is private and the only public service is a Caddy proxy that requires `Authorization: Bearer <PROXY_TOKEN>` on every request.

## Architecture

```
MCP client ──HTTPS + Bearer token──▶ Token Proxy (public, caddy:2.11.9-alpine :8080)
                                         │ private network, http :8000 /mcp
                                         ▼
                                   Graphiti (private, zepai/knowledge-graph-mcp:1.1.3-graphiti-0.31.2)
                                     ├─ MCP server :8000
                                     └─ FalkorDB on localhost:6379, append-only file on the volume
                                        /var/lib/falkordb/data
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Token Proxy | `caddy:2.11.9-alpine` | Public HTTPS, bearer token required, streams responses |
| Graphiti | `zepai/knowledge-graph-mcp:1.1.3-graphiti-0.31.2` | MCP server plus FalkorDB in one container, private, volume |

## Differences from upstream's combined image

The image's own start script runs FalkorDB with protected mode off on all interfaces, without an append-only file, and starts the FalkorDB Browser (which has no login) on port 3000. Redis is started as a background daemon, so on a redeploy it never gets a clean shutdown and writes since the last snapshot can be lost. This template replaces the start command:

- FalkorDB listens on localhost only (`--bind 127.0.0.1 ::1`), so no other service can reach it.
- Append-only persistence (`--appendonly yes --appendfsync everysec`) on the volume: at most about one second of writes can be lost on a redeploy.
- No FalkorDB Browser.

## Variables

Same as the Neo4j variant, except:

| Variable | Value | Notes |
|----------|-------|-------|
| `DATABASE__PROVIDER` | `falkordb` | |
| `FALKORDB_URI` | `redis://localhost:6379` | FalkorDB inside the container |
| `FALKORDB_DATABASE` | `default_db` | Graph name |

## Neo4j or FalkorDB?

- **FalkorDB**: one container, much less RAM (see the test notes), no separate database to manage. No graph browser in this template; you query through the MCP tools. FalkorDB is licensed under SSPL v1 (fine for running it yourself; not for offering it as a service to others).
- **Neo4j**: Neo4j Browser and Cypher over HTTPS, a Bolt TCP proxy for your own tools, APOC, a database you can also use for other data. About 1 GB more RAM.

You can't switch an existing deploy between them; memories would have to be added again.

## Test notes

2026-11-09, on Railway:

- Deploy: both services healthy. The log shows `FalkorDB ready (append-only file on the volume)` and `Database: falkordb`.
- Proxy: same checks as the Neo4j variant. Without the token every request gets 401. With it, an MCP client initialized, listed the tools and got `get_status` "connected to falkordb database".
- After a redeploy of the Graphiti service (append-only files already on the volume), FalkorDB started again and all checks passed. The graph was empty on Railway, so data surviving a restart was checked locally only: in Docker, a graph written to FalkorDB survived a container restart with this start command.
- Not tested on Railway: memory extraction (no LLM run on this variant). It runs the same Graphiti code path as the Neo4j variant, which was tested with OpenAI.
- Memory at idle with an empty graph: Graphiti plus FalkorDB 0.26 GB, proxy 0.02 GB.
