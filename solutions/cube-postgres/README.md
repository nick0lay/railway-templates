# Cube 1.8 + Postgres 18

A self-hosted [Cube](https://cube.dev) semantic layer: define metrics and dimensions once in a data model, then query them from apps, BI tools and AI agents over REST and GraphQL. Cube Core is open source (Apache 2.0). Cube comes pre-connected to a private Postgres 18. On the first start the template creates a sample `orders` table (1000 rows) and a matching data model, so your first query works right after deploy.

The template runs Cube's production layout: an API instance, a refresh worker that builds pre-aggregations, and a Cube Store cluster (router + worker) that serves them, with a Railway Bucket as shared storage. Only the API is public, and every API request needs a JWT signed with a generated secret. The Playground (dev mode) is off.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/cube-18-postgres-18?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
Your app, BI tool or AI agent
   │ HTTPS + Authorization: Bearer <JWT signed with CUBEJS_API_SECRET>
   ▼
┌──────────────────────────┐                    ┌──────────────────────────┐
│ Cube API (public) :4000  │        SQL         │ Postgres (private)       │
│ cubejs/cube:v1.8.22      │ ─────────────────▶ │ postgres-ssl:18, volume  │
│ REST, GraphQL, JWT       │                    │ sample table `orders`    │
└─────────────┬────────────┘                    └─────────────┬────────────┘
              │ rollups, :3030                                ▲
              ▼                                               │ SQL
┌──────────────────────────┐   builds rollups   ┌─────────────┴────────────┐
│ Cube Store Router        │ ◀───────────────── │ Cube Refresh Worker      │
│ (private) :3030, :9999   │                    │ (private)                │
│ cubejs/cubestore:v1.8.22 │                    │ cubejs/cube:v1.8.22      │
└─────────────┬────────────┘                    └──────────────────────────┘
              │ :10001
              ▼
┌──────────────────────────┐
│ Cube Store Worker        │
│ (private) v1.8.22        │
└─────────────┬────────────┘
              │ S3: rollup files and metastore snapshots (router and worker)
              ▼
┌──────────────────────────┐
│ Railway Bucket (private) │
└──────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Cube API | `cubejs/cube:v1.8.22` | Public. REST (`/cubejs-api/v1`) and GraphQL API, JWT required. Reads the data model from `CUBE_MODEL` |
| Cube Refresh Worker | `cubejs/cube:v1.8.22` | Private. Builds and refreshes pre-aggregations into Cube Store on schedule (`CUBEJS_REFRESH_WORKER=true`). Shares the API's settings |
| Cube Store Router | `cubejs/cubestore:v1.8.22` | Private. Cube Store metastore and query router; Cube API queries pre-aggregations here |
| Cube Store Worker | `cubejs/cubestore:v1.8.22` | Private. Stores and scans pre-aggregation partitions |
| Bucket | Railway Bucket | Private S3 storage shared by router and worker: pre-aggregation files and metastore snapshots |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Private. Database with the sample `orders` table, volume, password |

## After deploy

1. Wait until all services are green. On the first start the refresh worker builds the sample pre-aggregation within a minute or two.
2. Open **Cube API**, Variables tab, and copy `CUBEJS_API_SECRET`. The public domain is under Settings, Networking (`CUBE_API_URL` shows the REST base URL).
3. Mint a token and run a query. The snippet needs only bash, openssl and curl:

```bash
CUBE_URL="https://<your Cube API domain>"
CUBEJS_API_SECRET="<CUBEJS_API_SECRET from the Cube API variables>"

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
HEADER=$(printf '{"alg":"HS256","typ":"JWT"}' | b64url)
PAYLOAD=$(printf '{"exp":%d}' $(( $(date +%s) + 3600 )) | b64url)
SIG=$(printf '%s.%s' "$HEADER" "$PAYLOAD" | openssl dgst -sha256 -hmac "$CUBEJS_API_SECRET" -binary | b64url)
TOKEN="$HEADER.$PAYLOAD.$SIG"

curl -s "$CUBE_URL/cubejs-api/v1/load" \
  -H "Authorization: Bearer $TOKEN" \
  -G --data-urlencode 'query={"measures":["orders.count","orders.total_amount"],"dimensions":["orders.status"]}'
```

You get the sample rows, answered from the pre-aggregation in Cube Store:

```json
{"data": [{"orders.status": "completed", "orders.count": "600", "orders.total_amount": "152405"},
          {"orders.status": "shipped", "orders.count": "200", "orders.total_amount": "52257"}, ...],
 "usedPreAggregations": {"prod_pre_aggregations.orders_orders_by_month": {...}}, ...}
```

Each token here is valid for one hour (`exp`). In your app, sign tokens on your backend with the same secret (any JWT library, HS256), never in the browser. Put user or tenant data in the payload and use it in `CUBE_CONFIG_JS` (see below) for row-level security.

Other endpoints: `GET /cubejs-api/v1/meta` lists cubes, measures and dimensions; `POST /cubejs-api/graphql` is the GraphQL API; `/readyz` and `/livez` are open health checks. Client libraries: https://docs.cube.dev/reference.

## The data model

Cube reads its data model from files. Railway can't mount files, so the template keeps the model in the `CUBE_MODEL` variable on **Cube API** (YAML with `cubes:` and `views:`) and writes it to `model/railway-model.yml` at every start. The refresh worker reads the same variable. To change the model:

1. Edit `CUBE_MODEL` on Cube API (Railway's variable editor accepts multi-line values).
2. Redeploy **Cube API** and **Cube Refresh Worker**.

The sample cube `orders` has the measures `count`, `total_amount`, `average_amount`, the dimensions `status`, `category`, `city`, `created_at`, and the pre-aggregation `orders_by_month`. Model reference: https://docs.cube.dev/reference/data-modeling/cube.

**Bigger models: keep them in git.** One variable is fine for a handful of cubes. For a real project, keep the model in a repository:

1. Create a repo with a `model/` folder (your `.yml` or `.js` files) and this Dockerfile:

```dockerfile
FROM cubejs/cube:v1.8.22
COPY model /cube/conf/model
# optional: COPY cube.js /cube/conf/cube.js
```

2. On both Cube API and Cube Refresh Worker: Settings, Source, connect the repo (Railway builds the Dockerfile).
3. Clear `CUBE_MODEL` on Cube API. The start script leaves the image's `model/` folder alone when `CUBE_MODEL` is empty.

Every push then redeploys both services with the new model.

**`CUBE_CONFIG_JS`** (optional) holds a `cube.js` configuration file, for example `queryRewrite` for row-level security or `contextToAppId` for multi-tenancy: https://docs.cube.dev/reference/configuration/config.

## Your own data

The sample table lives in the Postgres service next to your data. Load your tables into the same database (or point `CUBEJS_DB_*` on Cube API at another one), then add cubes for them to `CUBE_MODEL`. `CUBE_SEED_SAMPLE_DATA=true` only creates `orders` when it is missing or empty and never touches other tables; set it to `false` once you have dropped the sample.

Postgres has no public domain. To load data from outside Railway, connect from another service in the project, or add a TCP proxy (Postgres) or a domain (ClickHouse HTTP) to the Postgres service yourself: it is password-protected, but then reachable from the internet.

## Pre-aggregations and Cube Store

Queries that match a pre-aggregation are answered from Cube Store and never reach the database. The refresh worker builds them on schedule (`refresh_key`) and the API never builds them itself (Cube's production default). Right after a deploy or a model change, a query that matches a pre-aggregation which is not built yet fails with "No pre-aggregation partitions were built yet"; it works once the refresh worker has built it, usually within a minute or two for small tables. Queries that match no pre-aggregation go to the database directly.

Cube Store runs as a router and one worker. Router and worker share the Railway Bucket for pre-aggregation files and the router's metastore snapshots; Cube Store has no volume. On a redeploy the router downloads its metastore from the bucket and the built pre-aggregations are served again without a rebuild (tested). A pre-aggregation built in the last minute before a redeploy may be rebuilt, because the router uploads metastore snapshots periodically. **One worker and one API instance** keep the idle cost low and are enough to try Cube and for small datasets. Cube's production sizing guide asks for more: at least two API instances (3 GB RAM each), two or more Cube Store workers and several GB of RAM per Cube Store node, and about one worker per million rows a query scans ([sizing](https://docs.cube.dev/admin/deployment/core#appropriate-cluster-sizing)). Cube API is stateless: raise its replicas under Settings, Deploy. To add a Cube Store worker:

1. Duplicate the Cube Store Worker service and give it a new name, e.g. `Cube Store Worker 2`.
2. On Cube Store Router, append `,${{Cube Store Worker 2.RAILWAY_PRIVATE_DOMAIN}}:10001` to `CUBESTORE_WORKERS`. Workers copy the router's list.
3. Redeploy the router and all workers.

## Security

- Only Cube API has a public domain. Cube Store, the refresh worker, Postgres and the bucket are private (Cube Store has no authentication of its own; it must stay private).
- Every API request needs `Authorization: Bearer <JWT>` signed with `CUBEJS_API_SECRET` (HS256, 64 generated characters). Requests without a token, with a token signed by another secret, with an expired token or with `alg: none` get 403.
- `CUBEJS_DEV_MODE=false`: no Playground, no unauthenticated access. Never turn it on with a public domain.
- To rotate the secret, change `CUBEJS_API_SECRET` on Cube API and redeploy both Cube services; old tokens stop working.
- The SQL API (Postgres wire protocol, for BI tools like Metabase, Superset or Tableau) is off. To turn it on, set `CUBEJS_PG_SQL_PORT=15432`, `CUBEJS_SQL_USER` and a strong `CUBEJS_SQL_PASSWORD` on Cube API and add a TCP proxy to port 15432.

## Environment variables

### User-configurable (Cube API)

| Variable | Default | Description |
|----------|---------|-------------|
| `CUBE_MODEL` | sample model | Data model (YAML). Redeploy Cube API and Cube Refresh Worker after a change |
| `CUBE_CONFIG_JS` | empty | Optional `cube.js` configuration |
| `CUBEJS_DB_TYPE`, `CUBEJS_DB_HOST`, `CUBEJS_DB_PORT`, `CUBEJS_DB_NAME`, `CUBEJS_DB_USER`, `CUBEJS_DB_PASS`, `CUBEJS_DB_SSL` | Postgres service | Database connection |
| `CUBE_SEED_SAMPLE_DATA` | `true` | Create the sample `orders` table (Postgres or ClickHouse) when missing or empty |
| `CUBEJS_API_SECRET` | generated (64) | Signs and verifies API tokens |
| `CUBEJS_LOG_LEVEL` | `info` | `error`, `warn`, `info`, `trace` |
| `CUBEJS_TELEMETRY` | `false` | Anonymous usage data to Cube |

### Auto-configured (do not change)

| Variable | Service | Why |
|----------|---------|-----|
| `CUBEJS_DEV_MODE=false` | Cube API, Refresh Worker | Production mode: tokens required, no Playground |
| `CUBEJS_REFRESH_WORKER=true` | Refresh Worker | Makes it the instance that builds pre-aggregations |
| `${{Cube API.*}}` references | Refresh Worker | The worker must use the same secret, database and model as the API |
| `CUBEJS_CUBESTORE_HOST`, `CUBEJS_CUBESTORE_PORT` | Cube API, Refresh Worker | Cube Store router on the private network, port 3030 |
| `CUBE_RUN_SH`, `CUBE_SEED_JS` | Cube API | Start script and sample data script |
| `CUBESTORE_SERVER_NAME`, `CUBESTORE_META_PORT`, `CUBESTORE_META_ADDR`, `CUBESTORE_WORKER_PORT`, `CUBESTORE_WORKERS`, `CUBESTORE_*_BIND_ADDR` | Cube Store | Cluster addresses on the private network (IPv4 and IPv6) |
| `CUBESTORE_MINIO_*` | Cube Store | The Railway Bucket (S3, path style) |
| `PORT=3031` | Cube Store Router | Status port for Railway's healthcheck (`/readyz`); workers have no status server |

## Resource use

Measured on Railway with the sample data, about 20 minutes after deploy (the Cube Store router uses about 0.34 GB in its first minutes, then settles):

| Service | Idle memory |
|---------|------------:|
| Cube API | 0.17 GB |
| Cube Refresh Worker | 0.16 GB |
| Cube Store Router | 0.13 GB |
| Cube Store Worker | 0.28 GB |
| Postgres | 0.06 to 0.11 GB |

Cube Store memory grows with the size of your pre-aggregations; the bucket grows with them too (the sample uses a few kilobytes).

## Troubleshooting

- **403 on every request**: the token is not signed with the current `CUBEJS_API_SECRET`, has expired, or is missing the `Bearer ` prefix. Re-run the snippet with the secret copied again.
- **"No pre-aggregation partitions were built yet"**: the refresh worker has not built that pre-aggregation yet. Wait a minute; check the Cube Refresh Worker logs for errors. After a model change, redeploy the worker too.
- **Cube API stays unhealthy**: `/readyz` checks the database and Cube Store. Check `CUBEJS_DB_*` and the Cube API logs; a wrong password shows up there.
- **A model change has no effect**: redeploy both Cube API and Cube Refresh Worker; both read `CUBE_MODEL` at start.
- **Cube Store errors about the bucket**: the `CUBESTORE_MINIO_*` variables must point at the Bucket; don't remove the Bucket.

## Versions

- Cube 1.8.22 and Cube Store 1.8.22: pinned tags; update both together (same version).
- Postgres 18 (`ghcr.io/railwayapp-templates/postgres-ssl:18`).

## Tested

2026-11-13 on Railway: a fresh deploy reached all-green; the sample table was created in Postgres, the rollup was built by the refresh worker within a minute and served from Cube Store; requests without a token, with a token signed by another secret, an expired token and an `alg: none` token got 403; the snippet above returned the sample rows; a query outside the rollup read the 1000 rows from Postgres; only Cube API has a public domain. A redeploy of every service kept the data and restored the rollup from the bucket without a rebuild.

## Links

- Cube docs: https://docs.cube.dev
- Deployment (production checklist): https://docs.cube.dev/admin/deployment/core#production-checklist
- Data modeling: https://docs.cube.dev/docs/data-modeling/overview
- REST API: https://docs.cube.dev/reference/core-data-apis/rest-api
- Cube on GitHub: https://github.com/cube-js/cube
