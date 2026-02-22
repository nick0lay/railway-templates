# Railway Templates

Curated Railway templates for popular self-hosted tools.

## Solutions

Pre-configured multi-service deployments with authentication and best practices.

| Solution | Description | Deploy |
|----------|-------------|--------|
| [BentoPDF + Caddy](./solutions/bentopdf-caddy/) | PDF toolkit with password protection | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/bentopdf-auth?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |
| [NocoDB + MinIO](./solutions/nocodb-minio/) | Airtable alternative with persistent file storage | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/nocodb-minio-console-and-storage?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |
| [Stirling-PDF](./solutions/stirling-pdf/) | PDF manipulation platform with 50+ tools, REST API, and built-in authentication | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/ylMH5M?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |
| [OpenClaw](./solutions/openclaw/) | AI assistant platform with multi-channel chat and S3-backed backup | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/openclaw-moltbot-clawdbot-data-backupres?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |
| [ClickHouse + CH-UI](./solutions/clickhouse-chui/) | OLAP database with web SQL editor and database explorer | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/clickhouse-ch-ui-1?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |

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
    └── clickhouse-chui/    # ClickHouse OLAP database with CH-UI web interface
        ├── README.md
        └── clickhouse/     # Custom Dockerfile for Railway networking
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

MIT
