# Deploy and Host Neo4j LLM Graph Builder 0.8.7 on Railway

Neo4j LLM Graph Builder is an open-source app from Neo4j Labs that turns documents into a knowledge graph. An LLM reads your PDFs, Word files, web pages, Wikipedia articles or YouTube transcripts, extracts entities and relationships into Neo4j, and then lets you chat with your documents using vector, graph and hybrid GraphRAG retrieval.

## About Hosting Neo4j LLM Graph Builder 0.8.7

Neo4j Labs publishes no Docker images, so this template builds release v0.8.7 from source on Railway: a React web UI and a FastAPI backend, next to Neo4j 2026.10 Community with APOC. Upstream's only login is Auth0, so the template puts the whole site behind a login (HTTP basic auth with a generated password) and keeps the backend private: the UI forwards API calls to it over Railway's private network. The backend connects to Neo4j server-side with Bolt over TLS, so the database password never reaches the browser. Neo4j keeps its data on a volume, and its Browser (HTTPS) and Bolt TCP proxy (TLS) are protected by a generated password. You only enter your OpenAI API key at deploy. The first build takes about 10 minutes.

## Common Use Cases

- Turn contracts, research papers, manuals or support tickets into a knowledge graph of people, companies, products and how they relate
- Chat with your documents and get answers with sources, using vector, graph, full-text or combined (GraphRAG) retrieval
- Explore the extracted graph in the built-in viewer or in Neo4j Browser with Cypher, and use it from your own apps with any Neo4j driver
- Shape the graph with your own schema (allowed node and relationship types), then merge duplicates and clean up in post-processing

## Dependencies for Neo4j LLM Graph Builder 0.8.7 Hosting

- Graph Builder: web UI built from `neo4j-labs/llm-graph-builder` v0.8.7, nginx with login (public)
- Backend: FastAPI backend built from v0.8.7 (private)
- Neo4j 2026.10.1 Community with APOC (`neo4j:2026.10.1-community`), Browser and Bolt TCP proxy behind its password, Bolt TLS, volume
- An OpenAI API key (other providers can be added with variables)

### Deployment Dependencies

- LLM Graph Builder on GitHub: https://github.com/neo4j-labs/llm-graph-builder
- Backend settings and model formats: https://github.com/neo4j-labs/llm-graph-builder/blob/v0.8.7/backend/example.env
- Neo4j Cypher manual: https://neo4j.com/docs/cypher-manual/current/

### Implementation Details

After deploy:

1. Open the Graph Builder URL and log in with `BASIC_AUTH_USER` (default `admin`) and `BASIC_AUTH_PASSWORD` from the Graph Builder service's Variables tab. The app is already connected to Neo4j.
2. Drop a file (or add a web page, Wikipedia or YouTube link), keep `openai_gpt_5.4_mini` and click **Generate Graph**.
3. When it shows **Completed**, open **Preview Graph**, and ask questions in the chat. For Cypher, open `BROWSER_URL` from the Neo4j service and log in as `neo4j` with `DB_PASSWORD`:

```cypher
MATCH (d:Document)<-[:PART_OF]-(c:Chunk)-[:HAS_ENTITY]->(e) RETURN d, c, e LIMIT 50
```

| Variable | Default | Purpose |
|---|---|---|
| `OPENAI_API_KEY` (Backend) | (you enter it) | Extraction, chat and embeddings |
| `VITE_LLM_MODELS` (Graph Builder) | `openai_gpt_5.4_mini,openai_gpt_5.5` | Models in the UI; each needs an `LLM_MODEL_CONFIG_*` variable on the Backend |
| `EMBEDDING_PROVIDER` / `EMBEDDING_MODEL` (Backend) | `openai` / `text-embedding-3-small` | Or `sentence-transformer` / `all-MiniLM-L6-v2` to embed locally without a key. Choose before the first upload |
| `LGB_VERSION` (both) | `v0.8.7` | Upstream release that is built |

Neo4j Community has no Graph Data Science plugin, so community summaries and the "global search" chat mode are turned off; the other six chat modes work. Everyone with the login shares one graph. In our test the services used about 2.1 GB of RAM at idle (backend 0.8 GB, Neo4j 1.2 to 1.3 GB, web UI under 0.01 GB). Your LLM provider bills extraction and chat separately.

## Why Deploy Neo4j LLM Graph Builder 0.8.7 on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Neo4j LLM Graph Builder 0.8.7 on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
