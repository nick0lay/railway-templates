# Deploy and Host txtai 9.14 on Railway

txtai is an open-source, all-in-one embeddings database from NeuML. One service holds a vector index, a SQLite content store and a semantic graph that links similar documents. On top of it you get semantic search, graph queries, retrieval augmented generation (RAG) with any LLM, and an MCP server for AI agents, all behind one REST API.

## About Hosting txtai 9.14

This template runs the official `neuml/txtai-cpu` image, pinned to 9.14.0, as a single service with a volume. The index, the content database, the graph and the downloaded embedding model all live on the volume at `/data`, so restarts and redeploys keep your data. Every API route and the MCP endpoint need a generated bearer token: upstream ships the API without a token, and this template turns it on. Embeddings run on CPU inside the service (default `all-MiniLM-L6-v2`), so indexing and search need no API key at all. Add an OpenAI key (or any LiteLLM provider) only if you want `/rag` answers.

## Common Use Cases

- Semantic search API for your app, docs or support tickets, without a separate vector database or an embeddings bill
- RAG backend: answers from your own documents with any LLM (OpenAI, Anthropic, OpenRouter and more through LiteLLM)
- Long-term memory and knowledge search for AI agents over MCP (Claude Code, Cursor and other MCP clients that can send a header)
- Explore how documents relate: graph search returns the nodes and edges between results, and graph path queries walk the links

## Dependencies for txtai 9.14 Hosting

- txtai 9.14.0 (`neuml/txtai-cpu:9.14.0`), public, bearer token required, volume for index and model cache
- Optional: an OpenAI API key or another LiteLLM-supported provider key for `/rag`

### Deployment Dependencies

- txtai on GitHub: https://github.com/neuml/txtai
- API documentation: https://neuml.github.io/txtai/api/
- Configuration reference: https://neuml.github.io/txtai/api/configuration/
- Semantic graph: https://neuml.github.io/txtai/embeddings/configuration/graph/

### Implementation Details

After deploy, copy `API_TOKEN` from the txtai service's Variables tab and send it as a bearer token:

```bash
URL=https://<your-domain>; AUTH="Authorization: Bearer <API_TOKEN>"

# Add documents, then build and save the index
curl -X POST "$URL/add" -H "$AUTH" -H "Content-Type: application/json" \
  -d '[{"id": "ada", "text": "Ada Lovelace wrote the first program for the Analytical Engine."}]'
curl "$URL/upsert" -H "$AUTH"

# Semantic search, and the same search as a graph of related documents
curl "$URL/search?query=who+programmed+the+engine&limit=3" -H "$AUTH"
curl "$URL/search?query=who+programmed+the+engine&graph=true" -H "$AUTH"

# RAG answer (needs OPENAI_API_KEY or another provider key)
curl "$URL/rag?query=Who+wrote+the+first+program" -H "$AUTH"
```

**MCP.** The MCP endpoint is `https://<your-domain>/mcp` (SSE transport) with the header `Authorization: Bearer <API_TOKEN>`. It exposes search, add, upsert, delete, count and RAG as tools. In Claude Code:

```bash
claude mcp add --transport sse txtai https://<your-domain>/mcp --header "Authorization: Bearer <API_TOKEN>"
```

| Variable | Default | Purpose |
|---|---|---|
| `API_TOKEN` | generated | Bearer token for every route and MCP |
| `EMBEDDINGS_MODEL` | `sentence-transformers/all-MiniLM-L6-v2` | Any sentence-transformers model from Hugging Face. Changing it means re-indexing |
| `LLM_MODEL` | `openai/gpt-5.4-mini` | LiteLLM model for `/rag`, for example `anthropic/claude-haiku-4-5` (then set `ANTHROPIC_API_KEY`) |
| `OPENAI_API_KEY` | empty | Only needed for `/rag` with OpenAI |
| `CONFIG` | template YAML | Full txtai configuration: index path, graph settings, RAG prompt, MCP |

The API docs page (`/docs`) and `/openapi.json` stay open so Railway can health-check the service; they list routes but return no data. In our test txtai used about 1 GB of RAM at idle with the default model. Your LLM provider bills RAG answers separately.

## Why Deploy txtai 9.14 on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying txtai 9.14 on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
