# txtai 9.14

Self-hosted [txtai](https://github.com/neuml/txtai) on Railway. txtai is an embeddings database: a vector index, a SQLite content store and a semantic graph in one process, with semantic search, graph queries, retrieval augmented generation (RAG) and a Model Context Protocol (MCP) server behind one REST API.

It is the lightweight end of GraphRAG: no separate graph or vector database, no LLM needed to build the graph (documents are linked by embedding similarity), and an LLM only for the final RAG answer.

## Architecture

```
   Apps / scripts / AI agents (Authorization: Bearer <API_TOKEN>)
                 │ HTTPS (REST API, MCP over SSE at /mcp)
                 ▼
┌──────────────────────────────────────────────────────────────┐
│ Railway project                                              │
│                                                              │
│  txtai :8000 (public, bearer token on every route)           │
│    embeddings (CPU, sentence-transformers)                   │
│    vector index + SQLite content + semantic graph            │
│    volume /data (index, model cache)                         │
└──────────────────────────────────────────────────────────────┘
                 │ HTTPS (only for /rag)
                 ▼
   Your LLM provider (OpenAI, or any LiteLLM provider)
```

## Services

| Service | Source | Role |
|---------|--------|------|
| txtai | `neuml/txtai-cpu:9.14.0` | REST API, MCP server, embeddings, index and graph (public, bearer token, volume `/data`) |

## What this template does

- **Official image, pinned.** `neuml/txtai-cpu:9.14.0`, the CPU build published by NeuML. No custom build.
- **Bearer token on every route.** txtai's API has token auth built in but off by default, and it expects the SHA-256 hash of the token in `TOKEN`. The start command hashes the generated `API_TOKEN` into `TOKEN` before it starts the server, so you only ever handle the plain token. The MCP endpoint (`/mcp` and `/mcp/messages/`) is checked by the same token.
- **Data on a volume.** The index is saved to `/data/index` after every `/index` or `/upsert` call and loaded again at start. The Hugging Face model cache is on the volume too (`HF_HOME=/data/hf`), so the model is downloaded once.
- **Works without an API key.** Embeddings run inside the service. Search, the graph and indexing need no key. `/rag` uses LiteLLM, so any provider works.
- **IPv4 and IPv6.** The server listens on one dual-stack socket, so both Railway's public edge and the IPv6 private network reach it.
- **Configuration as one variable.** `CONFIG` holds txtai's YAML configuration. It references `EMBEDDINGS_MODEL` and `LLM_MODEL`, so the common changes are one variable each.

## After deploy

1. Copy `API_TOKEN` from the txtai service's **Variables** tab.
2. Add documents with `POST /add`, then call `GET /upsert` (or `GET /index` to rebuild from scratch). Until then the index is empty.
3. Search with `GET /search`.

```bash
URL=https://<your-domain>; AUTH="Authorization: Bearer $API_TOKEN"

curl -X POST "$URL/add" -H "$AUTH" -H "Content-Type: application/json" -d '[
  {"id": "ada", "text": "Ada Lovelace wrote the first program for the Analytical Engine."},
  {"id": "babbage", "text": "Charles Babbage designed the Analytical Engine."}
]'
curl "$URL/upsert" -H "$AUTH"
curl "$URL/count" -H "$AUTH"

# Semantic search (with content: true, results include the text)
curl "$URL/search?query=who+programmed+the+engine&limit=3" -H "$AUTH"

# SQL over the content store
curl -G "$URL/search" -H "$AUTH" --data-urlencode "query=select id, text, score from txtai where similar('analytical engine') limit 5"

# Graph: the results and the edges between them
curl "$URL/search?query=analytical+engine&graph=true" -H "$AUTH"

# Graph path query (openCypher-style)
curl -G "$URL/search" -H "$AUTH" --data-urlencode 'query=MATCH P=({id: "ada"})-[*1..3]->({id: "babbage"}) RETURN P' --data-urlencode "graph=true"

# RAG (needs a provider key, see below)
curl "$URL/rag?query=Who+wrote+the+first+program" -H "$AUTH"
```

The interactive API docs are at `https://<your-domain>/docs` (the page loads without the token; use **Authorize** to call routes).

## MCP

`mcp: true` in `CONFIG` adds an MCP server at `https://<your-domain>/mcp` (SSE transport). Every API route becomes a tool: `search`, `batchsearch`, `add`, `upsert`, `index`, `delete`, `count`, `rag` and more. Configure your MCP client with the URL and the header `Authorization: Bearer <API_TOKEN>`. To hide write tools from agents, add `mcpargs` to the `mcp` section (for example `include_operations: [search_search_get, rag_rag_get]`).

## Variables

### User-configurable

| Variable | Default | Notes |
|---|---|---|
| `API_TOKEN` | generated (48 characters) | Bearer token for the API and MCP. Change it and redeploy to rotate |
| `EMBEDDINGS_MODEL` | `sentence-transformers/all-MiniLM-L6-v2` | Any sentence-transformers model. Larger models are better and use more RAM. After a change, re-add your documents and call `/index` |
| `LLM_MODEL` | `openai/gpt-5.4-mini` | LiteLLM model name for `/rag`: `anthropic/...`, `openrouter/...`, `groq/...` and so on |
| `OPENAI_API_KEY` | empty | Only for `/rag` with OpenAI. For other providers add their variable (`ANTHROPIC_API_KEY`, `OPENROUTER_API_KEY`, ...) |
| `CONFIG` | see below | txtai YAML configuration |

The default `CONFIG`:

```yaml
path: /data/index          # index saved here after /index and /upsert
writable: true
embeddings:
  path: ${{EMBEDDINGS_MODEL}}
  content: true             # store text in SQLite, enables SQL queries
  graph:                    # semantic graph between similar documents
    approximate: false
    minscore: 0.3
rag:
  path: ${{LLM_MODEL}}
  system: You answer questions using only the context provided.
  template: |
    Answer the following question using only the context below. If the context does not contain the answer, say so.
    Question: {question}
    Context: {context}
  context: 5
  output: flatten
mcp: true
```

Edit it for hybrid search (`hybrid: true`), topic modelling on the graph (`graph: topics: {}`), more pipelines (summary, translation, transcription) or workflows; see the [configuration reference](https://neuml.github.io/txtai/api/configuration/). Removing the `rag` section turns off `/rag`.

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `HF_HOME` | `/data/hf` | Model cache on the volume |
| `HF_HUB_DISABLE_TELEMETRY` | `1` | No Hugging Face telemetry |
| `PORT` | `8000` | The public domain points to this port |

## Resources

In our test on 2026-11-09 the service used about 1 GB of RAM after start with the default model, and slightly more after indexing a few documents. The image is large (about 1.2 GB compressed, with PyTorch for CPU), so the first deploy takes a few minutes. Larger embedding models and big indexes need more memory; the index is held in RAM.

## Tested

2026-11-09 on Railway, from the template: unauthenticated requests to every API route and to the MCP endpoints return 401; a wrong token returns 401. With the token: documents added and indexed, semantic search, graph search and a graph path query return the expected documents, the MCP client lists the tools and runs a search, and a RAG answer from OpenAI `gpt-5.4-mini` is correct. The index survived a redeploy. Startup without an LLM key works; `/rag` then returns an error until a key is set.

## Troubleshooting

- **401 on every call.** Send `Authorization: Bearer <API_TOKEN>`, the plain token from Variables. Do not hash it yourself.
- **`/search` returns `[]`.** Documents added with `/add` are only searchable after `/upsert` or `/index`.
- **`/rag` returns 500.** No provider key, or `LLM_MODEL` does not match the key you set. The service logs show LiteLLM's error.
- **Slow first start.** The image is large and the embedding model downloads on the first start; later starts use the cache on the volume.

## Links

- txtai: https://github.com/neuml/txtai
- API docs: https://neuml.github.io/txtai/api/
- Graph: https://neuml.github.io/txtai/embeddings/configuration/graph/
