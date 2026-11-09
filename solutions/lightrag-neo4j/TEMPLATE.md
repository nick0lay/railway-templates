# Deploy and Host LightRAG 1.5.7 + Neo4j on Railway

LightRAG is an open-source GraphRAG server from HKU. It reads your documents, uses an LLM to build a knowledge graph of entities and relationships, and answers questions by combining graph retrieval with vector search. This template stores the knowledge graph in Neo4j, so you can also explore and query it with Neo4j Browser and Cypher.

## About Hosting LightRAG 1.5.7 + Neo4j

This template runs three official images: LightRAG v1.5.7 (`ghcr.io/hkuds/lightrag`), Neo4j 2026.10 Community with APOC, and PostgreSQL 18 with pgvector 0.8.7. The knowledge graph goes to Neo4j (`Neo4JStorage`) over the private network. Documents, chunks, the LLM cache, document status and the vectors (HNSW index) go to Postgres. Every service has a volume, so nothing is lost on redeploy. LightRAG's web UI asks for a login with a generated admin password, and the API and Ollama-compatible routes need a generated API key. Neo4j Browser runs over HTTPS and a Bolt TCP proxy is open for drivers, both behind a generated Neo4j password. Postgres is private. Neo4j's memory is capped (512 MB heap, 256 MB page cache). You only enter your OpenAI (or OpenAI-compatible) API key at deploy.

## Common Use Cases

- Turn company documents, research papers or support tickets into a knowledge graph you can query in Cypher and explore in Neo4j Browser
- Ask questions across your documents with answers that combine graph relationships and vector search, with sources
- Give an AI agent a GraphRAG backend over the REST API, or as an Ollama-compatible model in Open WebUI
- Combine LightRAG's extracted graph with your own Neo4j data, APOC procedures and graph queries

## Dependencies for LightRAG 1.5.7 + Neo4j Hosting

- LightRAG v1.5.7 (`ghcr.io/hkuds/lightrag:v1.5.7`), public, login and API key required, volume
- Neo4j 2026.10.1 Community with APOC (`neo4j:2026.10.1-community`), Browser and TCP proxy behind its password, volume
- PostgreSQL 18 with pgvector 0.8.7 (`pgvector/pgvector:0.8.7-pg18`), private, volume
- An API key for OpenAI or any OpenAI-compatible provider (OpenRouter, Groq, DeepSeek, a LiteLLM gateway, vLLM)

### Deployment Dependencies

- LightRAG on GitHub: https://github.com/HKUDS/LightRAG
- All server settings: https://github.com/HKUDS/LightRAG/blob/v1.5.7/env.example
- Neo4j Cypher manual: https://neo4j.com/docs/cypher-manual/current/
- pgvector: https://github.com/pgvector/pgvector

### Implementation Details

After deploy:

1. Open the LightRAG URL and log in with `ADMIN_USERNAME` (default `admin`) and `ADMIN_PASSWORD` from the LightRAG service's Variables tab.
2. Upload documents on **Documents**. The LLM extracts entities and relationships into Neo4j in the background.
3. Explore the graph on **Knowledge Graph**, ask questions on **Retrieval**, or open `BROWSER_URL` from the Neo4j service and log in as `neo4j` with `DB_PASSWORD`:

```cypher
MATCH (n:base)-[r]-(m) RETURN n, r, m LIMIT 100
```

Call the API with the generated `LIGHTRAG_API_KEY` (header `X-API-Key`); API docs are at `/docs`. Choose the models **before the first upload**:

| Variable | Default | Purpose |
|---|---|---|
| `LLM_BINDING_API_KEY` | (you enter it) | Your provider's API key, also used for embeddings |
| `LLM_BINDING_HOST` | `https://api.openai.com/v1` | Any OpenAI-compatible API |
| `LLM_MODEL` | `gpt-5.4-mini` | Chat model for extraction and answers |
| `EMBEDDING_MODEL` / `EMBEDDING_DIM` | `text-embedding-3-small` / `1536` | Use `3072` for `text-embedding-3-large`. Changing the model later means re-processing your documents |

In our test LightRAG used 0.35 to 0.7 GB of RAM at idle, Postgres about 0.05 GB and Neo4j 1.2 to 1.7 GB. Your LLM provider bills extraction and queries separately. For a lighter setup with the graph in Postgres, use the **LightRAG 1.5.7** template.

## Why Deploy LightRAG 1.5.7 + Neo4j on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying LightRAG 1.5.7 + Neo4j on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
