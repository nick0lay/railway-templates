# Deploy and Host LightRAG 1.5.7 on Railway

LightRAG is an open-source GraphRAG server from HKU. It reads your documents, uses an LLM to build a knowledge graph of entities and relationships, and answers questions by combining graph retrieval with vector search. It has a web UI for uploads, a knowledge graph explorer and a query panel, a REST API, and an Ollama-compatible chat API.

## About Hosting LightRAG 1.5.7

This template runs the official `ghcr.io/hkuds/lightrag` image, pinned to v1.5.7, with PostgreSQL 18 and pgvector 0.8.7. All of LightRAG's data lives in Postgres: documents, chunks and the LLM cache (`PGKVStorage`), vectors with an HNSW index (`PGVectorStorage`), document status, and the knowledge graph itself in plain Postgres tables (`PGTableGraphStorage`, no Apache AGE needed). Nothing is lost on redeploy. The web UI asks for a login with a generated admin password, the API and the Ollama-compatible routes need a generated API key, and Postgres has no public endpoint. You only enter your OpenAI (or OpenAI-compatible) API key at deploy.

## Common Use Cases

- Ask questions across your company documents, wikis, contracts or research papers, with answers that cite their sources
- Build a knowledge graph of people, products and concepts from unstructured text, and explore it visually
- Give an AI agent or chatbot a GraphRAG backend over the REST API, or as an Ollama-compatible model in Open WebUI
- Compare graph retrieval with plain vector search on the same data (local, global, hybrid, naive and mix query modes)

## Dependencies for LightRAG 1.5.7 Hosting

- LightRAG v1.5.7 (`ghcr.io/hkuds/lightrag:v1.5.7`), public, login and API key required, volume for uploaded files
- PostgreSQL 18 with pgvector 0.8.7 (`pgvector/pgvector:0.8.7-pg18`), private, with a volume
- An API key for OpenAI or any OpenAI-compatible provider (OpenRouter, Groq, DeepSeek, a LiteLLM gateway, vLLM)

### Deployment Dependencies

- LightRAG on GitHub: https://github.com/HKUDS/LightRAG
- All server settings: https://github.com/HKUDS/LightRAG/blob/v1.5.7/env.example
- LightRAG paper: https://arxiv.org/abs/2410.05779
- pgvector: https://github.com/pgvector/pgvector

### Implementation Details

After deploy:

1. Open the LightRAG URL and log in with `ADMIN_USERNAME` (default `admin`) and `ADMIN_PASSWORD` from the LightRAG service's Variables tab.
2. Upload documents (PDF, DOCX, PPTX, XLSX, Markdown, text) on **Documents**. The LLM extracts entities and relationships in the background.
3. Explore the result on **Knowledge Graph** and ask questions on **Retrieval**.

Call the API with the generated `LIGHTRAG_API_KEY`:

```bash
curl -X POST "https://<your-domain>/query" \
  -H "X-API-Key: <LIGHTRAG_API_KEY>" -H "Content-Type: application/json" \
  -d '{"query": "What are the main topics?", "mode": "mix"}'
```

API docs are at `/docs`. Choose the models **before the first upload**:

| Variable | Default | Purpose |
|---|---|---|
| `LLM_BINDING_API_KEY` | (you enter it) | Your provider's API key, also used for embeddings |
| `LLM_BINDING_HOST` | `https://api.openai.com/v1` | Any OpenAI-compatible API |
| `LLM_MODEL` | `gpt-5.4-mini` | Chat model for extraction and answers |
| `EMBEDDING_MODEL` / `EMBEDDING_DIM` | `text-embedding-3-small` / `1536` | Use `3072` for `text-embedding-3-large`. Changing the model later means re-processing your documents |

The vector index (`HNSW_HALFVEC`) supports embeddings up to 4,000 dimensions. In our test LightRAG used 0.35 to 0.7 GB of RAM at idle and Postgres about 0.05 GB. Your LLM provider bills extraction and queries separately. Want the graph in Neo4j instead, with Neo4j Browser and Cypher? Use the **LightRAG 1.5.7 + Neo4j** template.

## Why Deploy LightRAG 1.5.7 on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying LightRAG 1.5.7 on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
