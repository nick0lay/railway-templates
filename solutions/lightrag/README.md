# LightRAG 1.5.7 (GraphRAG)

Self-hosted [LightRAG](https://github.com/HKUDS/LightRAG) on Railway. LightRAG is a GraphRAG server: it reads your documents, uses an LLM to extract a knowledge graph of entities and relationships, and answers questions by combining graph retrieval with vector search. It comes with a web UI for uploads, a graph explorer and a query panel, a REST API, and an Ollama-compatible chat API.

There are two templates, built from the same tested parts:

| Template | Services | Graph store | Deploy |
|---|---|---|---|
| [LightRAG 1.5.7](./) | LightRAG + Postgres (pgvector) | Postgres tables | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/lightrag-157?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |
| [LightRAG 1.5.7 + Neo4j](../lightrag-neo4j/) | LightRAG + Postgres (pgvector) + Neo4j | Neo4j | Deploy button in [lightrag-neo4j](../lightrag-neo4j/) |

This README covers both. The Neo4j variant's folder has its own marketplace description and a short README with the Neo4j-specific parts.

Choose **LightRAG 1.5.7** to start: one database, about 0.4 to 0.75 GB of RAM at idle. Choose **+ Neo4j** when you want to explore and query the knowledge graph with Cypher and Neo4j Browser, or when the graph gets large. Neo4j adds about 1.2 to 1.7 GB of RAM.

In both templates the web UI needs a login, the API needs an API key, and the databases are private (Neo4j's Browser and Bolt TCP proxy need the Neo4j password).

## Architecture

### LightRAG 1.5.7

```
        Browser (web UI, login)        Apps / scripts (X-API-Key)
                 │ HTTPS                         │ HTTPS
                 ▼                               ▼
┌──────────────────────────────────────────────────────────────┐
│ Railway project                                              │
│                                                              │
│  LightRAG :9621 (public, login + API key)                    │
│    web UI /webui, REST API, Ollama-compatible /api/*         │
│    volume /data (uploaded files)                             │
│        │ private network                                     │
│        ▼                                                     │
│  Postgres :5432 (private, pgvector)                          │
│    documents, chunks, LLM cache, document status,            │
│    vectors (HNSW), knowledge graph tables                    │
│    volume /var/lib/postgresql                                │
└──────────────────────────────────────────────────────────────┘
        │ HTTPS
        ▼
  Your LLM and embedding provider (OpenAI or any OpenAI-compatible API)
```

### LightRAG 1.5.7 + Neo4j

```
        Browser (web UI, login)        Apps / scripts (X-API-Key)
                 │ HTTPS                         │ HTTPS
                 ▼                               ▼
┌──────────────────────────────────────────────────────────────┐
│ Railway project                                              │
│                                                              │
│  LightRAG :9621 (public, login + API key), volume /data      │
│        │                          │                          │
│        ▼                          ▼  bolt+ssc:// (TLS)       │
│  Postgres :5432 (private)    Neo4j 2026.10 Community         │
│    documents, chunks,          knowledge graph               │
│    vectors, status             Browser on HTTPS (password)   │
│                                Bolt TCP proxy (TLS, password)│
│                                volume /data                  │
└──────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| LightRAG | `ghcr.io/hkuds/lightrag:v1.5.7` | Web UI, REST API and document pipeline (public, login and API key, volume) |
| Postgres | `pgvector/pgvector:0.8.7-pg18` | PostgreSQL 18 with pgvector 0.8.7: key-value data, vectors, document status and (in the first template) the graph (private, volume) |
| Neo4j (+ Neo4j template only) | `neo4j:2026.10.1-community` | Knowledge graph, with APOC. Browser on the public HTTPS domain and a Bolt TCP proxy (TLS), both behind the generated password (volume) |

## What these templates do

- **Official images, pinned.** LightRAG `v1.5.7` from the project's own registry, pgvector's official image, and the official Neo4j image. No custom builds.
- **Everything in databases.** LightRAG's default JSON and NetworkX files are replaced with `PGKVStorage`, `PGVectorStorage` and `PGDocStatusStorage`. The graph goes into `PGTableGraphStorage` (plain Postgres tables, no Apache AGE extension needed) or into Neo4j (`Neo4JStorage`). Restarts and redeploys keep everything.
- **Login on every public endpoint.** A generated admin password for the web UI (`AUTH_ACCOUNTS` + `TOKEN_SECRET`), a generated `LIGHTRAG_API_KEY` for the API, and `WHITELIST_PATHS=/health`, so the Ollama-compatible `/api/*` routes need the key too. Upstream leaves `/api/*` open by default.
- **One key to fill in.** Enter your OpenAI (or OpenAI-compatible) API key at deploy. Embeddings use the same key unless you change it.
- **Vector index that fits any OpenAI model.** `HNSW_HALFVEC` supports up to 4,000 dimensions, so `text-embedding-3-large` (3072) works as well as the default `text-embedding-3-small` (1536). Plain HNSW stops at 2,000.
- **Volume for uploads.** Uploaded files are kept on a volume at `/data` (`/data/inputs`), outside the image's `/app/data`, so the bundled tokenizer cache stays usable without a download.

## After deploy

1. Open the LightRAG URL. It redirects to the web UI and shows a login page.
2. Log in with `ADMIN_USERNAME` (default `admin`) and `ADMIN_PASSWORD` from the LightRAG service's **Variables** tab.
3. On **Documents**, upload files (PDF, DOCX, PPTX, XLSX, Markdown, text and more) or paste text. Processing runs in the background: the LLM extracts entities and relationships from each chunk, so a large document takes a while and uses LLM tokens.
4. Look at the result on **Knowledge Graph**, and ask questions on **Retrieval**. Query modes: `local` (entities), `global` (relationships), `hybrid`, `naive` (vector only) and `mix` (graph + vectors, the default).

## Using the API

Every API call needs the `X-API-Key` header with `LIGHTRAG_API_KEY` (LightRAG service → Variables). The interactive API docs are at `https://<your-domain>/docs`.

```bash
# Add a document
curl -X POST "https://<your-domain>/documents/text" \
  -H "X-API-Key: $LIGHTRAG_API_KEY" -H "Content-Type: application/json" \
  -d '{"text": "Ada Lovelace wrote the first program for the Analytical Engine.", "file_source": "notes.txt"}'

# Ask a question
curl -X POST "https://<your-domain>/query" \
  -H "X-API-Key: $LIGHTRAG_API_KEY" -H "Content-Type: application/json" \
  -d '{"query": "Who wrote the first program?", "mode": "mix"}'

# Retrieved entities, relationships and chunks without an LLM answer
curl -X POST "https://<your-domain>/query/data" \
  -H "X-API-Key: $LIGHTRAG_API_KEY" -H "Content-Type: application/json" \
  -d '{"query": "Who wrote the first program?", "mode": "hybrid"}'
```

**Ollama-compatible API.** Chat clients that speak Ollama (Open WebUI, for example) can use LightRAG as a model named `lightrag:latest` at `https://<your-domain>/api`. They must send the API key as `X-API-Key`, because `/api/*` is not open in these templates.

## Choosing models

Set the models **before the first upload**:

| Variable | Default | Notes |
|---|---|---|
| `LLM_BINDING_HOST` | `https://api.openai.com/v1` | Any OpenAI-compatible API: OpenRouter (`https://openrouter.ai/api/v1`), Groq, Together, DeepSeek, a LiteLLM gateway, vLLM |
| `LLM_MODEL` | `gpt-5.4-mini` | Extraction runs on every chunk, so upstream recommends a fast, non-thinking model for it (set `EXTRACT_LLM_MODEL` to use a different model for extraction than for answers) |
| `EMBEDDING_BINDING_HOST` | `https://api.openai.com/v1` | Separate from the LLM host, so you can use one provider for chat and another for embeddings |
| `EMBEDDING_BINDING_API_KEY` | same as `LLM_BINDING_API_KEY` | Set it when the embedding provider is different |
| `EMBEDDING_MODEL` / `EMBEDDING_DIM` | `text-embedding-3-small` / `1536` | For `text-embedding-3-large` use `3072` |

The vector tables are named after the embedding model and dimension (for example `lightrag_vdb_chunks_text_embedding_3_small_1536d`). If you change the embedding model later, LightRAG creates new, empty vector tables, and you have to re-process your documents.

Other providers have their own bindings (`azure_openai`, `gemini`, `bedrock`, `ollama`). See LightRAG's [env.example](https://github.com/HKUDS/LightRAG/blob/v1.5.7/env.example) for their variables.

## Variables

### User-configurable (LightRAG service)

| Variable | Default | Notes |
|---|---|---|
| `LLM_BINDING_API_KEY` | (required) | Your LLM provider's API key |
| `LLM_BINDING`, `LLM_BINDING_HOST`, `LLM_MODEL` | `openai`, OpenAI, `gpt-5.4-mini` | See [Choosing models](#choosing-models) |
| `EMBEDDING_BINDING`, `EMBEDDING_BINDING_HOST`, `EMBEDDING_BINDING_API_KEY`, `EMBEDDING_MODEL`, `EMBEDDING_DIM` | OpenAI `text-embedding-3-small`, 1536 | Fixed after the first upload |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | `admin` / generated | Web UI login |
| `AUTH_ACCOUNTS` | `${{ADMIN_USERNAME}}:${{ADMIN_PASSWORD}}` | Add more users as comma-separated `user:password` pairs |
| `LIGHTRAG_API_KEY` | generated | API key (`X-API-Key` header) |
| `TOKEN_SECRET` | generated | Signs login tokens. Changing it logs everyone out |
| `SUMMARY_LANGUAGE` | `English` | Language of extracted entities, summaries and answers |
| `WEBUI_TITLE` | `LightRAG` | Name in the web UI header and the login page |
| `RERANK_BY_DEFAULT` | `false` | No reranker is configured. To add one, set `RERANK_BINDING` (`cohere`, `jina`, `aliyun`), `RERANK_MODEL`, `RERANK_BINDING_HOST` and `RERANK_BINDING_API_KEY`, then remove this variable |

Any other LightRAG setting from [env.example](https://github.com/HKUDS/LightRAG/blob/v1.5.7/env.example) can be added as a variable, for example `MAX_ASYNC_LLM` (parallel LLM calls, default 4), `CHUNK_SIZE` or `ENABLE_LLM_CACHE`.

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| LightRAG | `LIGHTRAG_KV_STORAGE`, `LIGHTRAG_VECTOR_STORAGE`, `LIGHTRAG_DOC_STATUS_STORAGE` | `PGKVStorage`, `PGVectorStorage`, `PGDocStatusStorage` | Data lives in Postgres |
| LightRAG | `LIGHTRAG_GRAPH_STORAGE` | `PGTableGraphStorage` or `Neo4JStorage` | Where the knowledge graph lives. Switching it later starts an empty graph |
| LightRAG | `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DATABASE` | From the Postgres service | Private network connection, no TLS (Railway's private network is encrypted) |
| LightRAG | `POSTGRES_VECTOR_INDEX_TYPE` | `HNSW_HALFVEC` | Vector index for up to 4,000 dimensions. Set before the first start |
| LightRAG | `NEO4J_URI`, `NEO4J_USERNAME`, `NEO4J_PASSWORD`, `NEO4J_DATABASE` (+ Neo4j only) | `${{Neo4j.BOLT_URL}}`, `${{Neo4j.DB_USER}}`, `${{Neo4j.DB_PASSWORD}}`, `neo4j` | Bolt over the private network with TLS (`bolt+ssc://neo4j.railway.internal:7687`: Neo4j's self-signed certificate, not verified) |
| LightRAG | `WHITELIST_PATHS` | `/health` | Only the healthcheck is open without a login or key |
| LightRAG | `WORKING_DIR`, `INPUT_DIR`, `PROMPT_DIR` | `/data/rag_storage`, `/data/inputs`, `/data/prompts` | Paths on the volume |
| LightRAG | `HOST`, `PORT` | `0.0.0.0`, `9621` | Railway routes the public domain to 9621 |
| LightRAG | `ENTITY_EXTRACTION_USE_JSON` | `true` | JSON output for extraction, as upstream recommends |
| Postgres | `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` | `lightrag`, `postgres`, generated | Applied when the database is created |
| Postgres | `PGDATA`, `PGVECTOR_INIT_SQL` | `/var/lib/postgresql/18/docker`, `CREATE EXTENSION vector` | Data directory on the volume; the extension is enabled on first start |
| Neo4j | `DB_PASSWORD`, `NEO4J_AUTH` | generated | Neo4j password, applied on the first start only |
| Neo4j | `NEO4J_server_memory_*` | heap 512m, page cache 256m | Memory limits for a small service. Raise them for a large graph |

## Neo4j template: looking at the graph

- **Neo4j Browser:** open `BROWSER_URL` from the Neo4j service's Variables. It connects over `https://` on port 443; log in with `neo4j` and `DB_PASSWORD`. LightRAG's entities are nodes with the label `base` (plus their entity type), so `MATCH (n:base)-[r]-(m) RETURN n, r, m LIMIT 100` shows the graph.
- **Drivers outside Railway:** `BOLT_PUBLIC_URL` is a TCP proxy, password-protected and TLS-encrypted by Neo4j with a self-signed certificate. Connect with `bolt+ssc://` or `neo4j+ssc://`; plain `bolt://` is refused. Remove the TCP proxy from the Neo4j service if you don't need it.
- More about the Neo4j service in the [Neo4j template's README](../neo4j/README.md).

## Backups

- **Postgres** holds all documents, chunks, vectors and status, and the graph in the first template. Turn on Railway volume backups, or `pg_dump` it.
- **Neo4j** (second template) holds the graph. Back up its volume, or use `neo4j-admin database dump` with the database stopped.
- **LightRAG's volume** keeps uploaded files in `/data/inputs`. They can be re-uploaded, but the processed data is in the databases.

## Cost

Measured at idle in our tests:

| Service | LightRAG 1.5.7 | + Neo4j |
|---|---|---|
| LightRAG | 0.35 to 0.7 GB | 0.35 to 0.7 GB |
| Postgres | about 0.05 GB | about 0.05 GB |
| Neo4j | (none) | 1.2 to 1.7 GB |
| **Total** | **about 0.4 to 0.75 GB** | **about 1.6 to 2.5 GB** |

LightRAG uses more memory and CPU while it processes documents. Your LLM provider bills extraction and queries separately: every chunk of every document goes through the LLM once, so ingesting a large library costs real tokens. Use a small model for extraction (`EXTRACT_LLM_MODEL`) and a larger one for answers (`QUERY_LLM_MODEL`) to save money.

## Upgrading

Change the LightRAG image tag (for example `ghcr.io/hkuds/lightrag:v1.5.8`) and redeploy. LightRAG migrates its Postgres tables on start. Read the [release notes](https://github.com/HKUDS/LightRAG/releases) first and back up Postgres before upgrading.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| LightRAG restarts once with `Database neo4j ... is not available` (+ Neo4j template) | LightRAG started while Neo4j was restarting, for example when both are redeployed together. It exits, Railway restarts it, and it connects within a few minutes. A Neo4j restart while LightRAG keeps running needs no restart |
| `ERROR: PostgreSQL database, error:relation "lightrag_doc_full" does not exist` on the first start | Expected: LightRAG checks for its tables before it creates them. The next lines create them |
| Documents end as **Failed** with an authentication or model error | Check `LLM_BINDING_API_KEY`, `LLM_MODEL` and the embedding settings, then click **Scan/Retry** on the Documents page (it reprocesses failed documents) |
| Queries answer "not able to provide an answer ... [no-context]" | No document has been processed yet, or the embedding model changed after the first upload (new, empty vector tables) |
| `401` from the API | Send `X-API-Key: <LIGHTRAG_API_KEY>`. The Ollama-compatible `/api/*` routes need it too |
| Login fails after changing `ADMIN_PASSWORD` | `AUTH_ACCOUNTS` is built from it; redeploy LightRAG so the new value is read |
| Processing is slow | Raise `MAX_ASYNC_LLM` (parallel LLM requests) and `MAX_PARALLEL_INSERT` (documents in parallel) if your provider's rate limits allow it |

## License

LightRAG is [MIT](https://github.com/HKUDS/LightRAG/blob/main/LICENSE). PostgreSQL uses the PostgreSQL License and pgvector the PostgreSQL License. Neo4j Community Edition is GPL-3.0.

## Testing

Tested on 2026-11-09 with LightRAG v1.5.7, in throwaway Railway projects for both templates. All services deployed and stayed healthy. No real LLM key was used: a small OpenAI-compatible stand-in service answered the extraction, keyword and answer prompts with fixed JSON and returned word-hashed embeddings, so the whole pipeline ran, but answer quality with a real model was not tested.

- **Login and keys:** `/` redirects to the web UI login page, and the generated admin logged in (browser and `POST /login`). A wrong password got 401. The documents API returned 401 without a key or with a wrong key, and 200 with the API key or the login token. The Ollama-compatible `/api/tags` returned 401 without a key. Anonymous `/health` showed only liveness; with the key it listed the configured storages.
- **Ingest and query (both templates):** a text document was accepted, processed, and produced three entities and two relationships. `/graph/label/list` and the graph view returned them, `hybrid`, `naive` and `mix` queries returned an answer with a reference to the document, and `/query/data` returned the entities and the chunk.
- **Storage:** the logs showed Postgres connected over the private network without SSL, the tables and `HNSW_HALFVEC` indexes created, and `PGTableGraphStorage initialized`. In the Neo4j template, LightRAG logged `Connected to neo4j at bolt://neo4j.railway.internal:7687` (after Bolt TLS was turned on later that day: `bolt+ssc://neo4j.railway.internal:7687`), and a Cypher query over Neo4j's HTTPS API returned the extracted nodes and relationships.
- **Persistence:** after redeploying all services, the documents, graph and query results were unchanged in both templates.
- **Neo4j restarts:** a Neo4j-only redeploy needed no LightRAG restart. When all three services were redeployed together, LightRAG's first start timed out on Neo4j and the automatic restart connected (see Troubleshooting).
- **Default settings:** both templates were also deployed with its default model settings and a deliberately invalid OpenAI key. Login and key checks passed, LightRAG connected to its storages (and to Neo4j), and the test document failed with OpenAI's `401 Incorrect API key provided`, so the default configuration reaches the provider as expected.
- **Neo4j with Bolt TLS (later on 2026-11-09):** the whole ingest and query run passed again with LightRAG connecting over `bolt+ssc://`, and the graph was in Neo4j. The published template, deployed with an OpenAI key that had no credit left, connected to Neo4j over TLS and the document failed with OpenAI's `429 insufficient_quota`, so the defaults reach OpenAI. A run with a real model is still to do.
- **Memory at idle:** LightRAG 0.35 to 0.7 GB, Postgres about 0.05 GB, Neo4j 1.2 to 1.7 GB.

Not tested: a real LLM provider, file uploads (PDF, DOCX), rerankers, other LLM bindings, and custom domains.
