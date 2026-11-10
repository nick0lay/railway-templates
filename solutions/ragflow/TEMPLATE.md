# Deploy and Host RAGFlow 1.0.0 on Railway

RAGFlow is an open-source RAG engine from InfiniFlow for deep document understanding. It parses PDFs, Office files, scans and tables, chunks and embeds them, and answers questions with citations. Version 1.0 is a Go rewrite and adds knowledge compilation: knowledge graphs (GraphRAG), trees, mind maps, timelines and wikis built by an LLM from your documents.

## About Hosting RAGFlow 1.0.0

This template runs the official `infiniflow/ragflow:v1.0.0` image with the same backends as upstream's Docker Compose setup:

- Elasticsearch 8.11.3 for chunks, vectors and graphs
- MySQL 8.0.40 for metadata
- Kvrocks 2.16.0 as the cache
- NATS 2.14.2 with JetStream for the ingestion queue
- A Railway Bucket instead of MinIO, so uploaded files are kept in S3 storage

Only RAGFlow has a public domain. Everything else is private, with a volume and generated passwords. Public sign-up is closed. Your first user is created for you, and its password is generated at deploy. You add your LLM key (OpenAI or any of 50+ providers) in the RAGFlow UI.

## Common Use Cases

- Chat with company documents, contracts, manuals and research papers, with answers that cite the source chunk
- Build a knowledge graph (GraphRAG) of people, organizations and products from your files with a Graph compilation template
- Give an agent or app a retrieval backend over RAGFlow's REST API, OpenAI-compatible chat API or MCP endpoint
- Ingest tables, scanned PDFs and slides with layout-aware parsing (DeepDoc), not just plain text

## Dependencies for RAGFlow 1.0.0 Hosting

- RAGFlow v1.0.0 (`infiniflow/ragflow:v1.0.0`): web UI, API, ingestion worker and admin server. Public, login required
- Elasticsearch 8.11.3, private, volume, 1 GB heap
- MySQL 8.0.40, private, volume
- Kvrocks 2.16.0 (Redis protocol), private, volume
- NATS 2.14.2 with JetStream, private, volume
- Railway Bucket (S3) for uploaded files
- An API key for an LLM provider (OpenAI, Anthropic, Gemini, OpenRouter, Ollama, and many more)

### Deployment Dependencies

- RAGFlow on GitHub: https://github.com/infiniflow/ragflow
- Documentation: https://ragflow.io/docs/
- HTTP API reference: https://ragflow.io/docs/http_api_reference
- Knowledge compilation (GraphRAG): https://ragflow.io/docs/knowledge_compilation/overview

### Implementation Details

After deploy:

1. Open the RAGFlow URL and sign in with `RAGFLOW_USER_EMAIL` (default `user@ragflow.io`) and `RAGFLOW_USER_PASSWORD`, both on the RAGFlow service's Variables tab.
2. Open your avatar, then **Model providers**. Add your provider's API key and choose the default chat and embedding models (for example `gpt-5.4-mini` and `text-embedding-3-small`).
3. Create a **Dataset**, upload files and click parse. Then create a **Chat** on the dataset and ask questions.

For a knowledge graph:

1. Open **Agent**, then **Compilation operator**, and create a template from **Graph**.
2. Create an **Ingestion pipeline** (Parser, Chunker, Compiler, Indexer) that uses this template, and publish it.
3. Select the published pipeline in the dataset's **Parsing mode**, and parse again.

**Users and admin.** Public sign-up is off (`ENABLE_REGISTER=0`). The superuser (`DEFAULT_SUPERUSER_EMAIL` / `DEFAULT_SUPERUSER_PASSWORD`) can only sign in at `/admin`. There it adds users, resets passwords and shows service status. RAGFlow refuses the superuser on the main sign-in page by design. The first normal user is created once on the first start. Changing the two `RAGFLOW_USER_*` variables later does not change an existing user: use `/admin` for that.

| Variable | Default | Purpose |
|---|---|---|
| `RAGFLOW_USER_EMAIL` | `user@ragflow.io` | First user, created on the first start |
| `RAGFLOW_USER_PASSWORD` | generated | Its password |
| `DEFAULT_SUPERUSER_EMAIL` | `admin@ragflow.io` | Admin for `/admin` only |
| `DEFAULT_SUPERUSER_PASSWORD` | generated | Its password |
| `ENABLE_REGISTER` | `0` | `1` opens public sign-up to anyone with the URL |
| `ES_HEAP_SIZE` (Elasticsearch) | `1g` | Raise for millions of chunks |

API keys for the REST, OpenAI-compatible and MCP APIs are created in the RAGFlow UI.

**Resources.** In our test on 2026-11-09 the idle stack used about 2.8 GB of RAM: Elasticsearch 1.7 GB, RAGFlow 0.7–0.9 GB, MySQL 0.3 GB, Kvrocks 0.1 GB, NATS 0.01 GB. That is beyond Railway's Trial plan, so use Hobby or Pro. Parsing large PDFs uses more CPU and memory while it runs. Your LLM provider bills parsing, embeddings and chat separately.

## Why Deploy RAGFlow 1.0.0 on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying RAGFlow 1.0.0 on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
