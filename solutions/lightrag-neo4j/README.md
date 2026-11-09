# LightRAG 1.5.7 + Neo4j (GraphRAG)

[LightRAG](https://github.com/HKUDS/LightRAG) GraphRAG server with its knowledge graph in Neo4j 2026.10 Community, and documents, chunks and vectors in PostgreSQL 18 with pgvector. Web UI with login, REST API with an API key, Neo4j Browser over HTTPS behind the Neo4j password.

Deploy button: coming soon (the template is not published yet).

This is the Neo4j variant of the [LightRAG 1.5.7](../lightrag/) template. Both are built from the same services and share one README: architecture, variables, models, API examples, backups, upgrades and troubleshooting are in **[../lightrag/README.md](../lightrag/README.md)**. The Neo4j service is the same as in the [Neo4j 2026.10 Community](../neo4j/) template.

## Services

| Service | Source | Role |
|---------|--------|------|
| LightRAG | `ghcr.io/hkuds/lightrag:v1.5.7` | Web UI, REST API and document pipeline (public, login and API key, volume) |
| Postgres | `pgvector/pgvector:0.8.7-pg18` | Documents, chunks, LLM cache, document status and vectors (private, volume) |
| Neo4j | `neo4j:2026.10.1-community` | Knowledge graph with APOC. Browser on the public HTTPS domain and a Bolt TCP proxy, both behind the generated password (volume) |

## What differs from the Postgres-only template

| | LightRAG 1.5.7 | LightRAG 1.5.7 + Neo4j |
|---|---|---|
| Graph store | `PGTableGraphStorage` (Postgres tables) | `Neo4JStorage` (`NEO4J_URI=${{Neo4j.BOLT_URL}}`) |
| Look at the graph | LightRAG web UI | LightRAG web UI, Neo4j Browser, Cypher, any Neo4j driver |
| Idle RAM (our test) | about 0.4 to 0.75 GB | about 1.6 to 2.5 GB (Neo4j adds 1.2 to 1.7 GB) |

## Query the graph in Neo4j

Open `BROWSER_URL` from the Neo4j service's Variables and log in as `neo4j` with `DB_PASSWORD`. LightRAG's entities are nodes labelled `base`, with `entity_id`, `entity_type` and `description` properties; relationships are `DIRECTED` with `keywords`, `description` and `weight`.

```cypher
MATCH (n:base)-[r]-(m) RETURN n, r, m LIMIT 100
```

```cypher
MATCH (n:base) RETURN n.entity_type AS type, count(*) AS entities ORDER BY entities DESC
```

Don't rename or delete LightRAG's nodes by hand while it is processing documents; edit entities through the LightRAG web UI or the `/graph/entity/edit` API instead, so the vectors in Postgres stay in step.

## Testing

See the Testing section of [../lightrag/README.md](../lightrag/README.md#testing).
