# Railway Templates

Curated Railway templates for popular self-hosted tools.

## Solutions

Pre-configured multi-service deployments with authentication and best practices.

| Solution | Description | Deploy |
|----------|-------------|--------|
| [BentoPDF + Caddy](./solutions/bentopdf-caddy/) | PDF toolkit with password protection | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/bentopdf-auth?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |
| [NocoDB + MinIO](./solutions/nocodb-minio/) | Airtable alternative with persistent file storage | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/nocodb-minio-console-and-storage?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |
| [Stirling-PDF](./solutions/stirling-pdf/) | PDF manipulation platform with 50+ tools, REST API, and built-in authentication | [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/ylMH5M?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic) |

## Structure

```
railway-templates/
└── solutions/
    ├── bentopdf-caddy/     # BentoPDF with Caddy authentication
    │   └── README.md
    ├── nocodb-minio/       # NocoDB with MinIO storage
    │   ├── README.md
    │   └── minio-init/     # Bucket initialization sidecar
    └── stirling-pdf/       # Stirling-PDF single service
        ├── README.md
        └── app/            # Custom Dockerfile for single-volume support
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

MIT
