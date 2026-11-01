# Deploy and Host ClickHouse on Railway

ClickHouse is an open-source column-oriented database for real-time analytics. It runs analytical queries over billions of rows in seconds, compresses data 5–10x, and speaks SQL over a simple HTTP interface, so almost any language or BI tool can use it.

## About Hosting ClickHouse

This template runs the official ClickHouse server image on Railway (the newest tested LTS release by default), with a persistent volume for your data. User, password and database are created on first start, and the template exposes ready-made connection URLs for other services in your project and for clients outside Railway. ClickHouse's high-volume internal log tables are switched off and the useful ones are kept for 7 days, so the volume holds your data, not diagnostics. A `/ping` healthcheck and restart-on-failure policy keep the service available.

## Common Use Cases

- Product and web analytics over event streams
- Log, metrics and observability storage
- Dashboards in Grafana, Metabase or Superset with sub-second queries
- Fast analytical copy of a transactional Postgres or MySQL database

## Dependencies for ClickHouse Hosting

- Official `clickhouse/clickhouse-server` image (newest tested LTS release by default)
- A Railway volume at `/var/lib/clickhouse` (included)

### Deployment Dependencies

- ClickHouse documentation: https://clickhouse.com/docs
- Docker Hub tags: https://hub.docker.com/r/clickhouse/clickhouse-server/tags
- Template source: https://github.com/nick0lay/railway-templates/tree/main/solutions/clickhouse

### Implementation Details

Connect from another service in the same project:

```
CLICKHOUSE_URL=${{ClickHouse.CLICKHOUSE_URL}}
```

Query from your machine:

```bash
curl -u "clickhouse:<password>" "https://<your-domain>/" --data-binary "SELECT version()"
```

Leave `CLICKHOUSE_IMAGE_TAG` empty to get the newest LTS release tested with this template, or set any tag from Docker Hub (for example `26.10` or `latest`) to pick the version yourself. Test upgrades on a copy first: ClickHouse can't be downgraded once newer versions have written data.

## Why Deploy ClickHouse on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying ClickHouse on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
