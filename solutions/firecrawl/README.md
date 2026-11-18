# Firecrawl 2.11 (self-hosted, API key)

Turn any website into clean markdown or structured data for LLMs and agents. This template runs the open-source [Firecrawl](https://github.com/firecrawl/firecrawl) stack (by Firecrawl, AGPL-3.0) on Railway from the official prebuilt images, with a generated API key in front of it.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/firecrawl-211-self-hosted-api-key?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

**An API key, unlike the open self-hosted default.** Self-hosted Firecrawl has no API authentication unless you also run Supabase (`USE_DB_AUTHENTICATION`). Exposed directly, anyone who finds the URL can use your server and its IP to scrape. Here the Firecrawl API is private, and the only public service is a small Caddy proxy that requires `Authorization: Bearer <FIRECRAWL_API_KEY>`, the same header the Firecrawl SDKs and integrations send. In the Python and Node SDKs, the n8n node, LangChain, LlamaIndex, Dify or the Firecrawl MCP server, set the API URL to your domain and the API key to the generated key.

## Architecture

```
Your app / SDK / n8n / MCP
   │  HTTPS, Authorization: Bearer <FIRECRAWL_API_KEY>
   ▼
┌───────────────────────────┐ private  ┌──────────────────────────────┐        ┌───────────────────────────┐
│ Firecrawl (public)        │ ───────▶ │ Firecrawl API (private)      │ ─────▶ │ Playwright (private)      │
│ caddy:2.11.9-alpine :8080 │  :3002   │ ghcr.io/firecrawl/firecrawl  │  :3000 │ firecrawl/playwright-     │
│ 401 without the key       │          │ API + queue, extract and NuQ │        │ service, headless Chromium│
└───────────────────────────┘          │ workers in one container     │        └───────────────────────────┘
                                       └──────┬─────────┬─────────┬───┘
                                              │ :5432   │ :6379   │ :5672
                                              ▼         ▼         ▼
                                   ┌──────────────┐ ┌────────┐ ┌──────────┐
                                   │ NuQ Postgres │ │ Redis  │ │ RabbitMQ │
                                   │ pg_cron, vol │ │ volume │ │ volume   │
                                   └──────────────┘ └────────┘ └──────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Firecrawl | `caddy:2.11.9-alpine` | Public HTTPS. Checks the API key on every request, then forwards to the API. `/healthz` is the only open path |
| Firecrawl API | `ghcr.io/firecrawl/firecrawl:2.11.781` | REST API (`/v1`, `/v2`) plus the queue worker, extract worker and NuQ job workers, started together by upstream's process supervisor as in the official Docker Compose. Private |
| Playwright | `ghcr.io/firecrawl/playwright-service:sha-8b950c45c8ca` | Headless Chromium for JavaScript-heavy pages, private |
| NuQ Postgres | `ghcr.io/firecrawl/nuq-postgres:sha-a7a63b4bfabf` | Job queue database (Postgres 17 with pg_cron and the NuQ schema), volume, private |
| Redis | `redis:8.10` | Crawl state and rate limits, password, AOF persistence, volume, private |
| RabbitMQ | `rabbitmq:3.13.7-alpine` | Job notifications for the NuQ queue, generated password, volume, private |

All images are pinned. Upstream publishes the Playwright and NuQ Postgres images with commit tags only (no release tags), so they are pinned to the commit builds that match the API release.

## After deploy

1. Open the **Firecrawl** service, Variables tab. Copy `FIRECRAWL_API_URL` (`https://<domain>`) and `FIRECRAWL_API_KEY` (`fc-...`).
2. Wait until **Firecrawl API** is healthy (the first start takes a minute or two).
3. Try it:

```bash
curl -s https://<domain>/v2/scrape \
  -H "Authorization: Bearer <FIRECRAWL_API_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com", "formats": ["markdown"]}'
```

### Python SDK

```python
from firecrawl import Firecrawl

app = Firecrawl(api_key="fc-...", api_url="https://<domain>")
doc = app.scrape("https://example.com", formats=["markdown"])
print(doc.markdown)
```

### Node SDK

```js
import Firecrawl from "@mendable/firecrawl-js";

const app = new Firecrawl({ apiKey: "fc-...", apiUrl: "https://<domain>" });
const doc = await app.scrape("https://example.com", { formats: ["markdown"] });
```

### Firecrawl MCP server (Claude, Cursor)

```json
{
  "mcpServers": {
    "firecrawl": {
      "command": "npx",
      "args": ["-y", "firecrawl-mcp"],
      "env": { "FIRECRAWL_API_URL": "https://<domain>", "FIRECRAWL_API_KEY": "fc-..." }
    }
  }
}
```

### n8n, Dify, LangChain, LlamaIndex

Use the Firecrawl integration and set the base URL to `https://<domain>` and the API key to `FIRECRAWL_API_KEY`.

## What works self-hosted

| Endpoint | Works | Notes |
|----------|-------|-------|
| `/v2/scrape`, `/v1/scrape` | yes | markdown, HTML, links, screenshots (Playwright) |
| `/v2/crawl`, `/v1/crawl` | yes | async jobs, status at `/v2/crawl/<id>` |
| `/v2/map`, `/v1/map` | yes | from the site's sitemap and links (no search index self-hosted) |
| `/v2/batch/scrape` | expected | part of the open-source API; not covered by our test |
| `/v2/extract`, JSON format, summaries | with `OPENAI_API_KEY` (or `OPENAI_BASE_URL` / `OLLAMA_BASE_URL`) | LLM features need a model provider |
| `/v2/search` | with `SEARXNG_ENDPOINT` | point it at your own SearXNG instance; not covered by our test |
| Fire-engine (anti-bot), agent and browser sessions | no | Firecrawl cloud only |

## Environment variables

### User-configurable (Firecrawl service, the proxy)

| Variable | Default | Notes |
|----------|---------|-------|
| `FIRECRAWL_API_KEY` | generated, `fc-` plus 40 letters and digits | Change it to rotate the key. Letters, digits, `-` and `_`, at least 32 characters; the proxy refuses to start otherwise |
| `CADDYFILE` | the proxy rules | Caddy configuration written at start |

### User-configurable (Firecrawl API service)

| Variable | Default | Notes |
|----------|---------|-------|
| `OPENAI_API_KEY` | empty | Enables `/extract`, JSON format and other LLM features |
| `OPENAI_BASE_URL`, `MODEL_NAME` | empty | OpenAI-compatible provider and model |
| `OLLAMA_BASE_URL` | empty | Use Ollama instead |
| `PROXY_SERVER`, `PROXY_USERNAME`, `PROXY_PASSWORD` | empty | Outbound proxy for scraping (Playwright reads the same values) |
| `SEARXNG_ENDPOINT` | empty | SearXNG instance for `/search` |
| `SELF_HOSTED_WEBHOOK_URL` | empty | Receives crawl events |
| `NUQ_WORKER_COUNT` | `5` | Scrape worker processes. Lower it to save memory |
| `NUM_WORKERS_PER_QUEUE`, `CRAWL_CONCURRENT_REQUESTS`, `MAX_CONCURRENT_JOBS`, `BROWSER_POOL_SIZE` | `8`, `10`, `5`, `5` | Upstream defaults |
| `LOGGING_LEVEL` | `INFO` | |

### Auto-configured (do not change)

| Variable | Service | Value | Why |
|----------|---------|-------|-----|
| `UPSTREAM_URL` | Firecrawl | `http://${{Firecrawl API.RAILWAY_PRIVATE_DOMAIN}}:3002` | Where authorized requests go |
| `HOST`, `PORT` | Firecrawl API | `::`, `3002` | Listen on IPv4 and IPv6 for Railway's private network |
| `USE_DB_AUTHENTICATION` | Firecrawl API | `false` | Upstream's key system needs Supabase; the proxy checks the key instead |
| `EXPRESS_TRUST_PROXY` | Firecrawl API | `1` | Status URLs in responses use `https://` |
| `REDIS_URL`, `REDIS_RATE_LIMIT_URL` | Firecrawl API | `${{Redis.REDIS_URL}}?family=0` | `family=0` lets the Redis client use IPv6 |
| `POSTGRES_*` | Firecrawl API | from NuQ Postgres | The job queue database |
| `NUQ_RABBITMQ_URL` | Firecrawl API | `${{RabbitMQ.RABBITMQ_URL}}` | Job notifications |
| `PLAYWRIGHT_MICROSERVICE_URL` | Firecrawl API | `http://${{Playwright.RAILWAY_PRIVATE_DOMAIN}}:3000/scrape` | Browser rendering |
| `POSTGRES_DB` | NuQ Postgres | `postgres` | The queue's pg_cron maintenance jobs run in this database |
| `RABBITMQ_NODENAME` | RabbitMQ | `rabbit@localhost` | Keeps the node's data on the volume usable after a redeploy (the container hostname changes) |

## Security notes

- Every request except `/healthz` needs the key. The API, Playwright, databases and RabbitMQ have no public domain and no TCP proxy.
- The key is one shared secret. Anyone with it can make your server scrape any URL, including addresses on the private network of the project. Share it only with apps you trust, and rotate it if it leaks.
- Upstream's admin routes (`BULL_AUTH_KEY`, `ADMIN_INTERNAL_PORT`) stay off.

## Resources and costs

The Firecrawl API container runs the API plus about ten worker processes, so it is the largest service. Measured on Railway at idle: Firecrawl API 2.3 GB, Playwright 0.24 GB, RabbitMQ 0.18 GB, NuQ Postgres 0.17 GB, Redis and the proxy 0.02 GB each, about 2.9 GB in total. Playwright uses more while it renders pages. Lower `NUQ_WORKER_COUNT` to save memory on light workloads.

## Troubleshooting

- **401**: send exactly `Authorization: Bearer <FIRECRAWL_API_KEY>`. In SDKs, set both the API URL and the key.
- **502 right after deploy**: the API is still starting; wait for the Firecrawl API service to turn healthy.
- **A site returns empty content or is blocked**: many sites block datacenter IPs. Set `PROXY_SERVER` (and user and password) on the Firecrawl API service. Firecrawl cloud's anti-bot engine is not part of the open-source release.
- **`/extract` or the JSON format fails**: set `OPENAI_API_KEY` (or `OPENAI_BASE_URL` and `MODEL_NAME`) on the Firecrawl API service.

## Licence

Firecrawl is licensed under AGPL-3.0 (the SDKs under MIT). If you modify Firecrawl and offer it to others over a network, the AGPL requires you to publish your changes. Complying with the licence and with the terms of the sites you scrape is your responsibility.

## Test notes

2026-11-18, deploy of the stored template config on Railway (all six services healthy):

- Only the Firecrawl proxy has a domain; the API, Playwright, NuQ Postgres, Redis and RabbitMQ have no domain and no TCP proxy.
- `/healthz` returns 200. On `/v2/scrape`, `/v2/crawl/<id>` and `/`, no key, a wrong key, the key without `Bearer` and the key minus one character all return 401.
- With the key, `/v2/scrape` and `/v1/scrape` of example.com returned markdown, also with `waitFor`. The API logs show the scrapes went through the Playwright service.
- `/v2/map` of docs.firecrawl.dev returned 20 links. A `/v2/crawl` job completed, and its status URL was `https://` on the public domain.
- NuQ used RabbitMQ for job prefetch, and the API logs had no Redis, Postgres or RabbitMQ connection errors. On the very first boot two workers log a RabbitMQ `noproc` error while the queues are being created. They fall back to Postgres for that one read, and it does not recur.
- After a redeploy of the API, NuQ Postgres, Redis and RabbitMQ, the earlier crawl was still readable as completed, the key was still enforced, and a new scrape and crawl worked.
- Memory at idle: Firecrawl API 2.3 GB, Playwright 0.24 GB, RabbitMQ 0.18 GB, NuQ Postgres 0.17 GB, Redis and the proxy 0.02 GB each, about 2.9 GB in total.
- Not tested: `/extract` and the JSON format (they need an LLM key), `/search`, batch scrape, the SDKs and the MCP server.
