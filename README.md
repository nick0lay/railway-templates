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

## Structure

```
railway-templates/
└── solutions/
    ├── bentopdf-caddy/     # BentoPDF with Caddy authentication
    │   └── README.md
    ├── nocodb-minio/       # NocoDB with MinIO storage
    │   ├── README.md
    │   └── minio-init/     # Bucket initialization sidecar
    ├── stirling-pdf/       # Stirling-PDF single service
    │   ├── README.md
    │   └── app/            # Custom Dockerfile for single-volume support
    ├── openclaw/           # OpenClaw AI assistant with S3 backup
    │   └── README.md
    ├── clickhouse-chui/    # ClickHouse OLAP database with CH-UI web interface
    │   ├── README.md
    │   └── clickhouse/     # Custom Dockerfile for Railway networking
    ├── evershop/           # EverShop e-commerce platform with PostgreSQL
    │   ├── README.md
    │   └── evershop/       # Custom Dockerfile with admin auto-setup
    ├── questdb/            # QuestDB time-series database
    │   ├── README.md
    │   └── questdb/        # Custom Dockerfile for Railway PORT mapping
    ├── starrocks/          # StarRocks MPP analytical database
    │   ├── README.md
    │   └── starrocks/      # Custom Dockerfile + Railway entrypoint wrapper
    ├── marqo-navigator/    # Marqo vector search with UI behind Caddy auth
    │   ├── README.md
    │   ├── DEPLOYMENT.md   # Per-service Railway setup walkthrough
    │   ├── docker-compose.yml  # Local harness (pids_limit mirrors Railway)
    │   ├── vespa/          # Vespa image, run as admin and node roles
    │   ├── vespa-init/     # One-shot cluster bootstrap + app package
    │   ├── marqo/          # Custom Dockerfile, external vector store mode
    │   └── navigator/      # Custom Dockerfile pinning Express 4
    ├── clickhouse/         # Single ClickHouse server with volume
    │   ├── README.md
    │   └── clickhouse/     # Dockerfile, network + system-log config
    └── trigger-dev/        # Trigger.dev webapp + data services
        ├── README.md
        └── webapp/         # Dockerfile pinning the patched Trigger.dev image
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

MIT
