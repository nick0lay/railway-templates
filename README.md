# Railway Templates

Curated Railway templates for popular self-hosted tools.

## Solutions

Pre-configured multi-service deployments with authentication and best practices.

| Solution | Description | Deploy |
|----------|-------------|--------|
| [BentoPDF + Caddy](./solutions/bentopdf-caddy/) | PDF toolkit with password protection | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/bentopdf-auth?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |
| [NocoDB + MinIO](./solutions/nocodb-minio/) | Airtable alternative with persistent file storage | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/nocodb-minio-console-and-storage?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |
| [Stirling-PDF](./solutions/stirling-pdf/) | PDF manipulation platform with 50+ tools, REST API, and built-in authentication | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/stirling-pdf?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |
| [OpenClaw](./solutions/openclaw/) | AI assistant platform with multi-channel chat and S3-backed backup | Unpublished |
| [ClickHouse + CH-UI](./solutions/clickhouse-chui/) | OLAP database with web SQL editor and database explorer | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/clickhouse-ch-ui-1?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |
| [EverShop](./solutions/evershop/) | E-commerce platform with React storefront, admin panel, and GraphQL API | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/evershop-1?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |
| [QuestDB](./solutions/questdb/) | Time-series database with built-in web console and multi-protocol access | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/questdb?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |
| [StarRocks](./solutions/starrocks/) | MPP analytical database with MySQL-protocol access and web UI | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/starrocks-is-an-open-source-mpp-analytic?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |
| [Marqo + Navigator](./solutions/marqo-navigator/) | Ecommerce & multimodal vector search with admin UI, both password-protected | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/marqo?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |
| [ClickHouse](./solutions/clickhouse/) | Single-node OLAP database with persistent volume and ready-made connection URLs | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/clickhouse-1?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |
| [Trigger.dev](./solutions/trigger-dev/) | Background jobs platform: webapp, Postgres, Redis, ClickHouse and a Railway Bucket, with a DigitalOcean supervisor | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/triggerdev?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |
| [Langfuse v4](./solutions/langfuse/) | LLM observability: tracing, prompts and evals, with ClickHouse, Postgres, Redis and a Railway Bucket | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/langfuse-v4-2?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |
| [Langfuse v4 + LiteLLM](./solutions/langfuse-litellm/) | LiteLLM AI gateway with every LLM call traced in Langfuse v4, no code changes | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/langfuse-v4-litellm?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |
| [Typebot](./solutions/typebot/) | Visual chatbot builder with Mailpit sign-in (no SMTP needed) and a Railway Bucket for uploads | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/typebot-3?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |

## Structure

Each solution has a `README.md` (setup and variables), a `TEMPLATE.md` (the description shown on Railway) and one folder per service that Railway builds. Solutions that only use upstream images have no service folders.

```
railway-templates/
├── railway/
│   └── SAMPLE-TEMPLATE.md      # Starting point for a new TEMPLATE.md
└── solutions/
    ├── bentopdf-caddy/         # BentoPDF behind Caddy password auth (img/: screenshots)
    ├── nocodb-minio/
    │   └── minio-init/         # One-time bucket setup sidecar
    ├── stirling-pdf/
    │   └── app/                # Entrypoint for single-volume storage
    ├── openclaw/               # Built from nick0lay/openclaw
    ├── clickhouse-chui/
    │   └── clickhouse/         # ClickHouse with Railway networking
    ├── clickhouse/
    │   └── clickhouse/         # ClickHouse with volume, network and system-log config
    ├── evershop/
    │   └── evershop/           # EverShop with admin auto-setup
    ├── questdb/
    │   └── questdb/            # QuestDB with Railway PORT mapping
    ├── starrocks/
    │   └── starrocks/          # StarRocks all-in-one with a Railway entrypoint
    ├── marqo-navigator/        # DEPLOYMENT.md: manual setup; docker-compose.yml: local harness
    │   ├── vespa/              # Vespa, run as admin and node roles
    │   ├── vespa-init/         # One-shot cluster bootstrap and app package
    │   ├── marqo/              # Marqo in external vector store mode
    │   └── navigator/          # Navigator UI
    ├── trigger-dev/
    │   ├── webapp/             # Patched Trigger.dev webapp image
    │   └── registry/           # Docker registry with basic auth
    ├── trigger-dev-v4.8/
    │   ├── clickhouse/         # ClickHouse config for Trigger.dev
    │   └── registry/           # Docker registry with basic auth
    ├── langfuse/               # Uses ../clickhouse/clickhouse
    ├── langfuse-litellm/
    └── typebot/
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

MIT
