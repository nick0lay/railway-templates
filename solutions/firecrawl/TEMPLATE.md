# Deploy and Host Firecrawl 2.11 (Self-Hosted, API Key) on Railway

Firecrawl turns any website into clean, LLM-ready markdown or structured data. Scrape a page, crawl a whole site, map its URLs or batch-scrape lists, with JavaScript rendering in a real browser. This template runs the open-source Firecrawl stack from the official images, behind a generated API key, so the Firecrawl SDKs, n8n, LangChain and the MCP server work with your own server.

## About Hosting Firecrawl 2.11 (Self-Hosted, API Key)

Self-hosted Firecrawl is six services: the API with its job workers, a Playwright browser service, a Postgres job queue (NuQ, with pg_cron), Redis and RabbitMQ. Out of the box the self-hosted API has no authentication unless you also run Supabase, so an exposed server can be used by anyone. Here the Firecrawl API is private, and the only public service is a small Caddy proxy that requires `Authorization: Bearer your-api-key`, the same header the official SDKs send. The key (`fc-...`) is generated at deploy. Postgres, Redis and RabbitMQ keep their data on volumes and have generated passwords. Playwright and the databases have no public domain or TCP proxy. All images are pinned: API `ghcr.io/firecrawl/firecrawl:2.11.781`, with the matching Playwright and NuQ Postgres builds.

## Common Use Cases

- Feed websites and docs into RAG pipelines and AI agents as clean markdown
- Crawl a site on a schedule from n8n, Dify or your own code, and get the result as JSON
- Give Claude or Cursor web access through the Firecrawl MCP server pointed at your instance
- Extract structured data (prices, listings, contacts) with your own OpenAI-compatible model or Ollama
- Replace per-page cloud credits with your own server for high-volume scraping

## Dependencies for Firecrawl 2.11 (Self-Hosted, API Key) Hosting

- Firecrawl API with queue, extract and NuQ workers (`ghcr.io/firecrawl/firecrawl:2.11.781`), private
- Firecrawl proxy (`caddy:2.11.9-alpine`), public, API key required
- Playwright service (`ghcr.io/firecrawl/playwright-service`, pinned commit build), private
- NuQ Postgres (`ghcr.io/firecrawl/nuq-postgres`, Postgres 17 with pg_cron, pinned commit build), volume, private
- Redis 8.10, password, volume, private
- RabbitMQ 3.13.7, generated password, volume, private

### Deployment Dependencies

- Firecrawl on GitHub: https://github.com/firecrawl/firecrawl
- Self-hosting guide: https://docs.firecrawl.dev/contributing/self-host
- API reference: https://docs.firecrawl.dev/api-reference/introduction

### Implementation Details

After deploy, open the **Firecrawl** service's Variables tab and copy `FIRECRAWL_API_URL` and `FIRECRAWL_API_KEY`. Wait until the Firecrawl API service is healthy.

```bash
curl -s https://your-domain/v2/scrape \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com", "formats": ["markdown"]}'
```

Python SDK:

```python
from firecrawl import Firecrawl

app = Firecrawl(api_key="YOUR_API_KEY", api_url="https://your-domain")
print(app.scrape("https://example.com", formats=["markdown"]).markdown)
```

Firecrawl MCP server for Claude Desktop or Cursor:

```json
{
  "mcpServers": {
    "firecrawl": {
      "command": "npx",
      "args": ["-y", "firecrawl-mcp"],
      "env": { "FIRECRAWL_API_URL": "https://your-domain", "FIRECRAWL_API_KEY": "YOUR_API_KEY" }
    }
  }
}
```

In n8n, Dify, LangChain or LlamaIndex, use the Firecrawl integration with your domain as the base URL and the key as the API key. Both `/v1` and `/v2` endpoints work.

| Variable (Firecrawl API service) | Purpose |
|---|---|
| `OPENAI_API_KEY` | Enables `/extract`, the JSON format and summaries |
| `OPENAI_BASE_URL`, `MODEL_NAME` | Any OpenAI-compatible provider |
| `OLLAMA_BASE_URL` | Use Ollama instead |
| `PROXY_SERVER`, `PROXY_USERNAME`, `PROXY_PASSWORD` | Outbound proxy for sites that block datacenter IPs |
| `SEARXNG_ENDPOINT` | SearXNG for the search endpoint |
| `NUQ_WORKER_COUNT` | Scrape workers (default 5); lower it to save memory |

Rotate the key by changing `FIRECRAWL_API_KEY` on the Firecrawl service. Requests without it get `401`. Anyone holding the key can make your server fetch any URL, so share it only with apps you trust. Features that depend on Firecrawl's cloud (its anti-bot engine, agent and browser sessions) are not part of the open-source release.

In our test at idle the stack used about 2.9 GB of RAM: 2.3 GB for the API container (the API plus about ten workers), 0.24 GB for Playwright, and under 0.2 GB each for the rest. Lower `NUQ_WORKER_COUNT` on light workloads to save memory.

Firecrawl is licensed under AGPL-3.0. Compliance with the licence and with the terms of the sites you scrape is your responsibility.

## Why Deploy Firecrawl 2.11 (Self-Hosted, API Key) on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Firecrawl 2.11 (Self-Hosted, API Key) on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
