# Neo4j LLM Graph Builder 0.8.7 (documents to knowledge graph)

[LLM Graph Builder](https://github.com/neo4j-labs/llm-graph-builder) from Neo4j Labs turns PDFs, Word files, web pages, Wikipedia articles and YouTube transcripts into a knowledge graph in Neo4j, using an LLM to extract entities and relationships. Then you chat with your documents through vector, graph and hybrid (GraphRAG) retrieval. This template builds release v0.8.7 from source, puts the web UI behind a login, keeps the backend private and stores the graph in Neo4j 2026.10 Community.

Not yet published on the Railway marketplace.

## Architecture

```
                 Internet (HTTPS)
                        |
                        v
        +-------------------------------+
        | Graph Builder  (public)       |   nginx :8080
        |  basic auth on every path     |   React UI (built from v0.8.7)
        |  /api/*  -> Backend           |
        +-------------------------------+
                        | private network (http, IPv6)
                        v
        +-------------------------------+
        | Backend  (private)            |   FastAPI :8000
        |  extraction, embeddings, chat |   --> OpenAI API (your key)
        +-------------------------------+
                        | bolt+ssc:// (TLS), private network
                        v
        +-------------------------------+
        | Neo4j 2026.10 Community       |   volume /data
        |  APOC, Browser on HTTPS       |   Browser :7474 (public, password)
        |  Bolt TCP proxy (TLS)         |   Bolt :7687 (TCP proxy, password)
        +-------------------------------+
```

The browser only talks to Graph Builder. The backend has no public domain, and the Neo4j password never reaches the browser: the backend reads it from its own variables.

## Services

| Service | Source | Role |
|---------|--------|------|
| Graph Builder | `solutions/llm-graph-builder/frontend/Dockerfile` | React UI built from the upstream `v0.8.7` tag, served by nginx 1.30 with HTTP basic auth; forwards `/api/` to the backend (public) |
| Backend | `solutions/llm-graph-builder/backend/Dockerfile` | Upstream FastAPI backend built from the `v0.8.7` tag: file loading, LLM extraction, embeddings, chat (private) |
| Neo4j | `neo4j:2026.10.1-community` | Graph and vector store with APOC. Browser on the public HTTPS domain and a Bolt TCP proxy (TLS, `bolt+ssc://`), both behind the generated password (volume) |

Neo4j Labs publishes no Docker images for LLM Graph Builder, so both app services are built by Railway: each Dockerfile clones the upstream repository at `LGB_VERSION` and builds it. The first deploy takes about 10 minutes, mostly the backend build (PyTorch CPU, LibreOffice, Tesseract).

## After deploy

1. Open the Graph Builder URL. Log in with `BASIC_AUTH_USER` (default `admin`) and `BASIC_AUTH_PASSWORD` from the Graph Builder service's Variables tab.
2. The app connects to Neo4j by itself (the backend's `NEO4J_*` variables), so there is no connect dialog.
3. Drop a file into the upload area, or add a web page, Wikipedia article or YouTube link. Pick the model (`openai_gpt_5.4_mini` by default) and click **Generate Graph**.
4. When the status is **Completed**, click **Preview Graph** or **Query Graph** to see the entities and relationships, and ask questions in the chat on the right. The chat answers with sources, and you can switch retrieval modes.
5. For Cypher, open `BROWSER_URL` from the Neo4j service and log in as `neo4j` with `DB_PASSWORD`. The **Explore Graph** button in the UI (upstream opens Neo4j Bloom there) also opens this Neo4j Browser.

```cypher
MATCH (d:Document)<-[:PART_OF]-(c:Chunk)-[:HAS_ENTITY]->(e) RETURN d, c, e LIMIT 50
```

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---------|----------|---------|-------|
| Backend | `OPENAI_API_KEY` | (you enter it) | Used for extraction, chat and embeddings. If it is empty when the app first connects, upstream silently falls back to the local MiniLM embeddings and creates a 384-dimension vector index (see Troubleshooting) |
| Graph Builder | `BASIC_AUTH_USER` / `BASIC_AUTH_PASSWORD` | `admin` / generated | Login for the whole site. Changing them takes effect on the next restart |
| Graph Builder | `VITE_LLM_MODELS` | `openai_gpt_5.4_mini,openai_gpt_5.5` | Models in the dropdown. Compiled into the UI: redeploy after a change. Each one needs a matching backend variable (below) |
| Backend | `LLM_MODEL_CONFIG_OPENAI_GPT_5_4_MINI` | `gpt-5.4-mini,${{OPENAI_API_KEY}}` | `model,api_key` for the `openai_gpt_5.4_mini` entry |
| Backend | `LLM_MODEL_CONFIG_OPENAI_GPT_5_5` | `gpt-5.5,${{OPENAI_API_KEY}}` | Same for `openai_gpt_5.5` |
| Backend | `EMBEDDING_PROVIDER` / `EMBEDDING_MODEL` | `openai` / `text-embedding-3-small` | `sentence-transformer` / `all-MiniLM-L6-v2` runs the embedding model inside the backend (no key, about 0.3 GB more RAM). Choose before the first upload: the vector index dimension is fixed then |
| Backend | `ENTITY_EMBEDDING` | `True` | Embeds entities too, for the "entity search+vector" chat mode |
| Backend | `WEB_CONCURRENCY` | `1` | gunicorn workers. Keep 1 (see notes) |
| Both | `LGB_VERSION` | `v0.8.7` | Upstream release tag that is built. Keep both services on the same tag |

**Other models.** Upstream supports Anthropic, Gemini (Vertex AI), Groq, Fireworks, Bedrock, Azure OpenAI, Ollama and Diffbot through `LLM_MODEL_CONFIG_<NAME>` variables; the formats are in the upstream [backend/example.env](https://github.com/neo4j-labs/llm-graph-builder/blob/v0.8.7/backend/example.env). Add the variable on the Backend and the matching name (lower case, `_` and `.` as in the env name, for example `anthropic_claude_4.6_sonnet` for `LLM_MODEL_CONFIG_ANTHROPIC_CLAUDE_4_6_SONNET`) to `VITE_LLM_MODELS`, then redeploy Graph Builder.

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---------|----------|-------|-----|
| Graph Builder | `BACKEND_HOST` / `BACKEND_PORT` | `${{Backend.RAILWAY_PRIVATE_DOMAIN}}` / `${{Backend.PORT}}` | Where nginx forwards `/api/`. nginx looks the name up again every 10 s, because a redeploy gives the backend a new private IP |
| Graph Builder | `VITE_BLOOM_URL` | `${{Neo4j.BROWSER_URL}}` | Target of the graph-explore button (upstream opens Neo4j Bloom, which can't reach a private database) |
| Backend | `NEO4J_URI` / `NEO4J_USERNAME` / `NEO4J_PASSWORD` | `${{Neo4j.BOLT_URL}}` / `${{Neo4j.DB_USER}}` / `${{Neo4j.DB_PASSWORD}}` | Server-side connection, `bolt+ssc://` over the private network |
| Backend | `AUTHENTICATION_REQUIRED` | `False` | Upstream's Auth0 check. The Graph Builder login protects the site instead |
| Neo4j | `NEO4J_*`, `DB_*`, `BOLT_*` | see the [Neo4j template](../neo4j/) | Memory caps, Bolt TLS, generated password |

## Notes and limits

- **Login.** Upstream's only login is Auth0. This template turns it off (`VITE_SKIP_AUTH=true`, `AUTHENTICATION_REQUIRED=False`) and puts HTTP basic auth in front of everything, including the API. Everyone who logs in shares one Neo4j database and one chat history.
- **No community summaries.** "Global search" and community detection need the Graph Data Science plugin, which Neo4j Community doesn't include. The backend reports GDS as unavailable, and the app then hides the global chat mode and the community options. The other chat modes stay available: vector, graph, graph+vector, fulltext, graph+vector+fulltext, entity search+vector (our test used the default mode).
- **Live status.** Upstream reports processing progress over server-sent events tied to an Auth0 user, so without Auth0 that call gets a 401 (visible in the browser console). It doesn't stop anything: small files show **Completed** when extraction returns, and files above 5 MB (uploaded in chunks and processed in the background) show their final status after a page refresh.
- **One worker.** Uploaded chunks, chat sessions and caches live in the backend process, and each extra worker loads its own copy of the Python libraries. For more throughput, give the service more CPU rather than more workers.
- **Uploads aren't kept.** Uploaded files are deleted after processing; the graph and chunks stay in Neo4j. Click **Reprocess** only for files you upload again.
- **Sources.** Local files, web pages, Wikipedia and YouTube are enabled. S3 and Google Cloud Storage need credentials typed into the UI and are off (change `VITE_REACT_APP_SOURCES` in the Dockerfile to add them). YouTube transcripts may be blocked from cloud IPs; upstream supports `YOUTUBE_TRANSCRIPT_PROXY` on the backend.
- **Costs.** Extraction calls the LLM once per chunk, plus embeddings. Start with a short document to see the cost on your provider's dashboard.

## Upgrading

1. Read the upstream [release notes](https://github.com/neo4j-labs/llm-graph-builder/releases).
2. Set `LGB_VERSION` to the new tag on both Graph Builder and Backend, and redeploy both. If the release adds models, update the `LLM_MODEL_CONFIG_*` variables and `VITE_LLM_MODELS`.
3. For Neo4j, follow the [Neo4j template](../neo4j/) README.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Browser asks for the password again and again | Use `BASIC_AUTH_USER` / `BASIC_AUTH_PASSWORD` from the Graph Builder service. After changing them, restart Graph Builder |
| "Backend connection status" is red | The backend is still starting (it loads PyTorch) or crashed: check the Backend deploy logs |
| Extraction fails with an OpenAI 401 or 429 | Check `OPENAI_API_KEY` and your provider's quota |
| Model in the dropdown fails with "Environment variable 'LLM_MODEL_CONFIG_...' is not defined" | Add that variable to the Backend, or remove the model from `VITE_LLM_MODELS` and redeploy Graph Builder |
| "Unable to connect backend DB" | Neo4j is down or the password changed. If you rotated the Neo4j password, set `DB_PASSWORD` on Neo4j to the new value and redeploy Backend |
| Chat answers "Something went wrong" and **Details** says the embedding and vector index dimensions don't match | The index was created with another embedding model (for example while `OPENAI_API_KEY` was empty, which falls back to 384-dimension MiniLM). The connect dialog that offers a fix isn't shown in this setup, so recreate the indexes in Neo4j Browser (below), then reprocess files that were embedded with the old model |

Recreate the vector indexes for `text-embedding-3-small` (1536 dimensions; existing embeddings of that size are indexed again automatically):

```cypher
DROP INDEX vector IF EXISTS;
DROP INDEX entity_vector IF EXISTS;
CREATE VECTOR INDEX vector IF NOT EXISTS FOR (c:Chunk) ON (c.embedding)
  OPTIONS {indexConfig: {`vector.dimensions`: 1536, `vector.similarity_function`: 'cosine'}};
CREATE VECTOR INDEX entity_vector IF NOT EXISTS FOR (e:__Entity__) ON (e.embedding)
  OPTIONS {indexConfig: {`vector.dimensions`: 1536, `vector.similarity_function`: 'cosine'}};
```

## Testing

Tested on 2026-11-09 with this configuration in a Railway project (Graph Builder and Backend built from the Dockerfiles in this folder, real OpenAI key):

- Without credentials or with a wrong password the site and `/api/` return 401; `/healthz` answers without login.
- The UI loads through the login, shows the Neo4j connection `bolt+ssc://neo4j.railway.internal:7687` and a green backend status, with no connect dialog.
- A three-sentence text file was uploaded and processed with `openai_gpt_5.4_mini`: status **Completed**, 7 nodes and 13 relationships, about 1,800 tokens. In Neo4j the entities came out typed (Company, Person, Location, Product) with relationships such as `FOUNDER`, `BUILDS`, `DEPLOYS`; chunk embeddings and vector indexes are 1536-dimensional.
- The chat (default mode) answered a question that needed two facts from the document correctly.
- The backend reports no GDS (`gds_status: false`), and the global search mode is hidden.

Idle memory (Railway metrics): Graph Builder about 0.005 GB, Backend about 0.8 GB, Neo4j 1.2 to 1.3 GB, about 2.1 GB together. The backend image is large (PyTorch CPU, LibreOffice, Tesseract); a full build took about 8 minutes.
