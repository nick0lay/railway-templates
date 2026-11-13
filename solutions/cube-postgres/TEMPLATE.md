# Deploy and Host Cube 1.8 + Postgres 18 on Railway

Cube is the open-source semantic layer: define metrics and dimensions once, then query them from apps, BI tools and AI agents over REST and GraphQL with consistent numbers and fast cached answers. This template runs Cube Core 1.8.22 in its production layout. A private Postgres comes pre-connected, with a sample `orders` table (1000 rows) and a matching data model created on the first start.

## About Hosting Cube 1.8 + Postgres 18

A production Cube deployment has four parts: API instances, a refresh worker that builds pre-aggregations, Cube Store (router and workers) that stores and serves them, and storage that Cube Store's nodes share. This template wires all of them on Railway's private network, with a Railway Bucket as Cube Store's S3 storage. Only the API is public. Every request needs a JWT signed with a generated secret, and dev mode (the Playground) is off. The data model lives in a variable, so you can edit it in Railway without a repository, or move it to git later.

## Common Use Cases

- One definition of revenue, active users or churn for dashboards, apps and AI agents
- Customer-facing analytics in a SaaS app, with row-level security from the JWT
- Fast APIs over large tables: pre-aggregations answer in milliseconds
- A governed metrics layer for LLM agents instead of raw SQL
- Analytics on Postgres without slow aggregate queries on the primary

## Dependencies for Cube 1.8 + Postgres 18 Hosting

- Cube 1.8.22 (`cubejs/cube`), API and refresh worker
- Cube Store 1.8.22 (`cubejs/cubestore`), router and worker
- Railway Bucket (S3 storage for Cube Store)
- Postgres 18 (`ghcr.io/railwayapp-templates/postgres-ssl`)

### Deployment Dependencies

- Cube docs: https://docs.cube.dev
- Production checklist: https://docs.cube.dev/admin/deployment/core#production-checklist
- Data model reference: https://docs.cube.dev/reference/data-modeling/cube
- REST API: https://docs.cube.dev/reference/core-data-apis/rest-api
- Cube on GitHub: https://github.com/cube-js/cube

### Implementation Details

**What you set:** nothing. The API secret, passwords and the sample model are ready.

**After deploy:** copy `CUBEJS_API_SECRET` from the Cube API variables, mint a JWT and query:

```bash
CUBEJS_API_SECRET="<from the Cube API variables>"
b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
H=$(printf '{"alg":"HS256","typ":"JWT"}' | b64url)
P=$(printf '{"exp":%d}' $(( $(date +%s) + 3600 )) | b64url)
S=$(printf '%s.%s' "$H" "$P" | openssl dgst -sha256 -hmac "$CUBEJS_API_SECRET" -binary | b64url)
curl -s "https://<domain>/cubejs-api/v1/load" -H "Authorization: Bearer $H.$P.$S" \
  -G --data-urlencode 'query={"measures":["orders.count"],"dimensions":["orders.status"]}'
```

The answer comes from the `orders_by_month` pre-aggregation in Cube Store, built by the refresh worker a minute or two after the first deploy.

**Data model:** edit `CUBE_MODEL` (YAML cubes and views) on Cube API, then redeploy Cube API and Cube Refresh Worker. For bigger models, keep a `model/` folder in a repo with a two-line Dockerfile (`FROM cubejs/cube:v1.8.22`, `COPY model /cube/conf/model`) and point both Cube services at it; the README shows how. `CUBE_CONFIG_JS` takes an optional `cube.js` for row-level security or multi-tenancy.

**This template:**

- Pins Cube and Cube Store 1.8.22, Postgres 18
- Runs the production layout: API, refresh worker, Cube Store router + worker, Railway Bucket
- Keeps Cube Store, Postgres and the refresh worker private; only the API is public
- Requires a JWT (HS256, generated 64-character secret) on every request; dev mode off
- Writes the data model from a variable, since Railway can't mount files
- Creates the sample table only when it is missing or empty, so redeploys keep your data
- Keeps built pre-aggregations in the bucket across redeploys
- Healthchecks on Cube API, the refresh worker and the Cube Store router (`/readyz`)

**Scaling:** add Cube Store workers by duplicating the worker service and listing it in `CUBESTORE_WORKERS`; one worker is enough for small and medium data. The SQL API for BI tools is off by default; the README shows how to turn it on with a password.

**Resources:** about 0.85 GB RAM in total at idle (measured on Railway). Licence: Apache 2.0 (Cube Core).

## Why Deploy Cube 1.8 + Postgres 18 on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Cube 1.8 + Postgres 18 on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
