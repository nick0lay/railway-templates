# RAGFlow 1.0.0

Deploy RAGFlow 1.0.0, the open-source RAG engine with deep document understanding and knowledge graphs (GraphRAG), on Railway. You get the full upstream stack: Elasticsearch, MySQL, Kvrocks and NATS on the private network, uploaded files in a Railway Bucket, and public sign-up closed.

Deploy: not yet published.

## Overview

- **RAGFlow** from the official `infiniflow/ragflow:v1.0.0` image (the Go rewrite: 0.36 GB image, no bundled models, embeddings and chat through your LLM provider)
- **Elasticsearch 8.11.3** for chunks, vectors, full-text search and knowledge-graph data, 1 GB heap, with a volume
- **MySQL 8.0.40** for users, datasets, documents and pipelines, with a volume
- **Kvrocks 2.16.0**, RAGFlow's Redis-protocol cache (the only cache v1.0 supports), with a volume
- **NATS 2.14.2** with JetStream, the ingestion queue between the API and the ingestion worker, with a volume
- **Railway Bucket** (S3) for uploaded files, instead of MinIO
- **Login on the only public service**: public sign-up is off, the first user is created with a generated password, and the superuser can only use `/admin`

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                            Internet                              │
└──────────────────────────────┬───────────────────────────────────┘
                               │ HTTPS (public domain), login
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│ RAGFlow v1.0.0                                                   │
│   :80   nginx  ── web UI, /api/v1 ──► Go API server :9380        │
│                └─ /api/v1/admin ────► admin server :9381         │
│   ingestion worker (parse, chunk, embed, compile graphs)         │
└───┬───────────────┬──────────────┬──────────────┬────────────┬───┘
    │ :9200         │ :3306        │ :6379        │ :4222      │ HTTPS (S3)
    ▼               ▼              ▼              ▼            ▼
┌──────────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌──────────┐
│Elasticsearch │ │  MySQL    │ │ Kvrocks   │ │ NATS      │ │ Railway  │
│ 8.11.3       │ │  8.0.40   │ │ 2.16.0    │ │ JetStream │ │ Bucket   │
│ (volume)     │ │ (volume)  │ │ (volume)  │ │ (volume)  │ │ (files)  │
└──────────────┘ └───────────┘ └───────────┘ └───────────┘ └──────────┘
        all private (*.railway.internal), generated passwords
```

## Services

| Service | Source | Role |
|---------|--------|------|
| RAGFlow | `infiniflow/ragflow:v1.0.0` | Web UI, REST/OpenAI-compatible/MCP API, ingestion worker, admin server (public, login) |
| Elasticsearch | `elasticsearch:8.11.3` | Document engine: chunks, vectors, graphs (private, volume) |
| MySQL | `mysql:8.0.40` | Metadata database (private, volume) |
| Kvrocks | `apache/kvrocks:2.16.0` | Cache, locks and agent run state, Redis protocol with a password (private, volume) |
| NATS | `nats:2.14.2` | JetStream ingestion queue (private, volume) |
| Bucket | Railway Bucket | S3 storage for uploaded files |

## Getting Started

1. Deploy. The first start takes 2–3 minutes: MySQL and Elasticsearch initialize, then RAGFlow runs its migrations.
2. Open the RAGFlow URL and sign in with `RAGFLOW_USER_EMAIL` and `RAGFLOW_USER_PASSWORD` from the RAGFlow service's Variables tab.
3. Avatar, then **Model providers**: add your provider's key, then set the default chat and embedding models.
4. **Dataset**: create one, upload files and parse them. **Chat**: create an assistant on the dataset and ask questions.

### Knowledge graph (GraphRAG)

RAGFlow 1.0 builds graphs through *knowledge compilation*:

1. **Agent** > **Compilation operator** > create a template from **Graph**. Optionally adjust the entity and relation types.
2. **Agent** > **Ingestion pipeline**: Parser > Chunker > Compiler (with your template and a chat model) > Indexer. Then **Publish**.
3. In the dataset's **Configuration** > **Parsing mode**, select the published pipeline version and parse the documents again.

The extracted entities and relations appear on the document's structure view and are used in retrieval.

## Users, admin and sign-up

- `ENABLE_REGISTER=0` closes the public sign-up form. The API refuses it too (`user registration is disabled`).
- The **superuser** (`DEFAULT_SUPERUSER_EMAIL`, `DEFAULT_SUPERUSER_PASSWORD`) is created on the first start. It signs in at `https://<your-domain>/admin` to add users, reset passwords, grant admin and see service health. RAGFlow does not let it sign in on the main page ("super admin should not login to this page").
- The **first normal user** (`RAGFLOW_USER_EMAIL`, `RAGFLOW_USER_PASSWORD`) is created once, by a small helper in the start command that calls the local admin API. It is skipped if the user already exists, and it does nothing if you empty either variable.
- Both are created only once. Later changes to these variables do not change existing accounts: use `/admin`, or the user's own settings page.

## Environment Variables

### User-Configurable

| Service | Variable | Default | Description |
|---------|----------|---------|-------------|
| RAGFlow | `RAGFLOW_USER_EMAIL` | `user@ragflow.io` | First user, created on the first start |
| RAGFlow | `RAGFLOW_USER_PASSWORD` | generated (24) | Its password |
| RAGFlow | `DEFAULT_SUPERUSER_EMAIL` | `admin@ragflow.io` | Superuser for `/admin` |
| RAGFlow | `DEFAULT_SUPERUSER_PASSWORD` | generated (24) | Its password (first start only) |
| RAGFlow | `ENABLE_REGISTER` | `0` | `1` = anyone with the URL can sign up |
| RAGFlow | `TZ` | `Etc/UTC` | Log time zone |
| RAGFlow | `S3_PREFIX_PATH` | `ragflow` | Folder inside the bucket |
| Elasticsearch | `ES_HEAP_SIZE` | `1g` | JVM heap. Raise it with the service memory for millions of chunks |
| MySQL | `MYSQL_BUFFER_POOL` | `256M` | InnoDB buffer pool (upstream uses 1G for large installs) |

### Auto-Configured (Do Not Change)

| Service | Variable | Value | Why |
|---------|----------|-------|-----|
| RAGFlow | `ES_HOST`, `ELASTIC_PASSWORD` | `${{Elasticsearch.RAILWAY_PRIVATE_DOMAIN}}`, `${{Elasticsearch.ELASTIC_PASSWORD}}` | Document engine connection |
| RAGFlow | `MYSQL_HOST`, `MYSQL_DBNAME`, `MYSQL_PASSWORD` | `${{MySQL.*}}` | Metadata database (root user) |
| RAGFlow | `KVROCKS_HOST`, `REDIS_PASSWORD` | `${{Kvrocks.*}}` | Cache connection |
| RAGFlow | `NATS_HOST` | `${{NATS.RAILWAY_PRIVATE_DOMAIN}}` | Ingestion queue |
| RAGFlow | `S3_ENDPOINT`, `S3_BUCKET`, `S3_REGION`, `S3_ACCESS_KEY`, `S3_SECRET_KEY` | `${{Bucket.*}}` | Railway Bucket credentials |
| RAGFlow | `S3_ADDRESSING_STYLE` | `virtual` | S3 URL style, tested with the Railway Bucket |
| RAGFlow | `DOC_ENGINE`, `DB_TYPE`, `STORAGE_IMPL`, `DEVICE` | `elasticsearch`, `mysql`, `s3`, `cpu` | Backend selection. Changing them needs a data migration |
| RAGFlow | `RAGFLOW_SECRET_KEY` | generated (48) | Signs login tokens. Changing it signs everyone out |
| RAGFlow | `PORT` | `80` | RAGFlow's built-in nginx, used by the domain and the healthcheck (`/api/v1/system/ping`) |
| RAGFlow | `RAGFLOW_SERVICE_CONF` | upstream template + S3 block | Written over the image's `service_conf.yaml.template` on every start. Upstream's template has no S3 section, so the Bucket needs this |
| RAGFlow | `RAGFLOW_FIRST_USER_SH` | shell script | Creates the first user (see above) |
| Elasticsearch | `node.store.allow_mmap` | `false` | Railway does not allow raising `vm.max_map_count` |
| Elasticsearch | `network.host` | `::0` | Listen on IPv6 for Railway's private network |
| Kvrocks | `KVROCKS_START_SH` | shell script | Writes `kvrocks.conf` (IPv6 bind, password). Kvrocks has no env or CLI password option |
| NATS | start command | `-js -sd /data -a ::` | JetStream on the volume, listening on IPv6 |

NATS has no password: RAGFlow 1.0's NATS client has no auth setting. It is reachable only from inside the project's private network.

## Resources and plan

Measured idle on 2026-11-09 after a test ingest: Elasticsearch 1.75 GB, RAGFlow 0.7–0.9 GB, MySQL 0.5 GB, Kvrocks 0.1 GB, NATS 0.01 GB, about **3 GB** in total. Use Hobby or Pro: it does not fit the Trial plan. Parsing large PDFs (layout analysis and OCR run on the CPU in the RAGFlow service) uses more CPU and memory while it runs.

## Tested

2026-11-09, on Railway from this template:

- Sign-up refused, superuser refused on the main page and accepted on `/admin`, first user signs in, API without a token refused
- OpenAI provider added with `gpt-5.4-mini` and `text-embedding-3-small`, dataset created, text file uploaded (stored in the Railway Bucket and downloaded back), parsed into chunks, retrieval found the chunk, chat answered with a citation
- Knowledge graph: a Graph compilation template in an ingestion pipeline extracted 7 entities (people, companies, places, product) from the test file

## Troubleshooting

- **RAGFlow restarts on the first deploy**: it runs database migrations before starting and exits if MySQL is not reachable yet. Railway restarts it (up to 20 times) until MySQL and Elasticsearch are up.
- **Parsing or chat fails with a model error**: add the provider key and set the default chat and embedding models under **Model providers**. The dataset's embedding model is fixed once documents are parsed.
- **Parsing stays queued**: check the RAGFlow logs for `ingestor_server` lines and the NATS service status. The worker reads tasks from NATS.
- **Elasticsearch out of memory on big datasets**: raise `ES_HEAP_SIZE` (for example `2g`) and give the service at least twice that in memory.
- **Lost a password**: an admin resets any user's password in `/admin`.

## Links

- RAGFlow: https://github.com/infiniflow/ragflow (Apache-2.0)
- Docs: https://ragflow.io/docs/
- Upstream Docker setup: https://github.com/infiniflow/ragflow/tree/v1.0.0/docker
