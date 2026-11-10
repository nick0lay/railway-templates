# PuppyGraph 1.18 + Postgres

Deploy PuppyGraph 1.18 on Railway next to a Postgres 18 database that already holds a demo graph. PuppyGraph runs openCypher and Gremlin queries directly on SQL tables, so there's no ETL and no second copy of your data. Every endpoint needs the generated login.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/puppygraph-118-postgres?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Overview

- **PuppyGraph** from `puppygraph/puppygraph:1.18.1`, the free Developer edition (see [Licence](#licence))
- **Postgres** from `pgvector/pgvector:0.8.7-pg18`, private, with demo tables in schema `modern`
- **Demo schema** uploaded on the first start, so the first query works without setup
- **Schema kept across redeploys**: the current schema, with its data source connections, is saved to a volume every 30 seconds and loaded back on every start
- **Login everywhere**: web UI, REST API, Gremlin and Bolt. The image's defaults leave Gremlin and Bolt open and use a public password and public signing keys; this template generates all of them
- **Volumes** for the saved schema and uploaded JDBC drivers, and for Postgres

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                            Internet                              │
└───────────────────────────────┬──────────────────────────────────┘
                                │ HTTPS (public domain)
                                │ web UI + REST API, login required
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│ PuppyGraph 1.18.1 (Developer edition)                            │
│                                                                  │
│   8081 web UI / REST   public, basic auth or UI login            │
│   8182 Gremlin         private network, login required           │
│   7687 Bolt (Cypher)   private network, login required           │
│                                                                  │
│   /data (volume): saved schema, JDBC drivers                     │
└───────────────────────────────┬──────────────────────────────────┘
                                │ JDBC, private network
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│ Postgres 18 + pgvector (private)                                 │
│   database app, schema modern: person, software, knows, created  │
│   /var/lib/postgresql (volume)                                   │
└──────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| PuppyGraph | `puppygraph/puppygraph:1.18.1` | Graph query engine. Public HTTPS domain for the web UI and REST API (login). Gremlin and Bolt on the private network (login) |
| Postgres | `pgvector/pgvector:0.8.7-pg18` | Data source with the demo graph tables. Private |

## Environment Variables

### User-Configurable

| Variable | Service | Default | Description |
|----------|---------|---------|-------------|
| `PUPPYGRAPH_USERNAME` | PuppyGraph | `puppygraph` | Login for the web UI, REST API, Gremlin and Bolt. Set before the first start; it can't be renamed later |
| `PUPPYGRAPH_PASSWORD` | PuppyGraph | generated | Password for that login |
| `QUERY_TIMEOUT` | PuppyGraph | `5m` | Per-query timeout |
| `PUPPYGRAPH_SEED_SCHEMA` | PuppyGraph | `true` | Upload the demo schema on the first start (no saved schema yet). Set `false` to start empty |
| `PUPPYGRAPH_SCHEMA_SYNC_SECONDS` | PuppyGraph | `30` | How often the current schema is saved to the volume |
| `POSTGRES_DB` | Postgres | `app` | Database created on the first start. Holds the demo tables |

### Auto-Configured (Do Not Change)

| Variable | Service | Value | Why |
|----------|---------|-------|-----|
| `GREMLINSERVER_AUTHENTICATION_ENABLED`, `BOLTSERVER_AUTHENTICATION_ENABLED` | PuppyGraph | `true` | The image's default is `false`: Gremlin and Bolt would answer queries from anyone who can reach them |
| `AUTHENTICATION_JWT_SECRETKEY`, `CLUSTER_SECURITYKEY` | PuppyGraph | generated | Unset, both fall back to the public default `puppygraph`, and anyone could mint tokens |
| `STORAGE_PATH_ROOT` | PuppyGraph | `/var/lib/puppygraph` | PuppyGraph's own storage, on the container disk (see [How it starts](#how-it-starts)) |
| `PUPPYGRAPH_SCHEMA_BACKUP` | PuppyGraph | `/data/railway/schema.json` | Saved schema on the volume |
| `PUPPYGRAPH_SEED_SCHEMA_JSON` | PuppyGraph | demo schema | Maps the `modern` tables to `person`/`software` nodes and `knows`/`created` edges. The JDBC connection is filled in from `${{Postgres.*}}` |
| `PUPPYGRAPH_BOOT_SCRIPT`, `PUPPYGRAPH_SEED_SCRIPT` | PuppyGraph | scripts | Start script and schema script, see below |
| `RAILWAY_RUN_UID` | PuppyGraph | `0` | The start script prepares the volume as root, then runs the upstream entrypoint |
| `PUPPYGRAPH_URL` | PuppyGraph | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Web UI and REST API |
| `BOLT_URL` | PuppyGraph | `bolt://${{RAILWAY_PRIVATE_DOMAIN}}:7687` | Neo4j drivers in this project: `${{PuppyGraph.BOLT_URL}}` |
| `GREMLIN_URL` | PuppyGraph | `ws://${{RAILWAY_PRIVATE_DOMAIN}}:8182/gremlin` | Gremlin clients in this project: `${{PuppyGraph.GREMLIN_URL}}` |
| `PORT` | PuppyGraph | `8081` | Public domain and healthcheck (`/readyz`) |
| `POSTGRES_PASSWORD`, `DATABASE_URL`, `PGDATA`, `PGVECTOR_INIT_SQL` | Postgres | generated / derived | Superuser password, private connection string, data directory on the volume, first-start SQL (vector extension and demo tables) |

## How it starts

**Postgres** runs its first-start SQL once, on an empty volume: it enables `vector` and creates the demo tables in schema `modern` (`person`, `software`, `knows`, `created`), the graph PuppyGraph's own Postgres tutorial uses.

**PuppyGraph** runs a short start script before the upstream entrypoint. It prepares `/data/railway` on the volume and starts the schema script in the background.

PuppyGraph's query engine (a StarRocks frontend inside the image) refuses to start when its storage has less than 5 GB free. That check is fixed, and a Railway volume is often 5 GB in total. So PuppyGraph's own storage (`STORAGE_PATH_ROOT`) is on the container disk and starts fresh on every deploy. The schema script makes that invisible:

1. It waits for `/readyz`.
2. It loads the schema saved on the volume. On the very first start there is none, so it loads the demo schema instead (unless `PUPPYGRAPH_SEED_SCHEMA=false`).
3. Every 30 seconds it reads the full schema, including data source connections (the same export as the UI's schema backup), and saves it to the volume when it changed. A deleted schema is saved as empty, so it stays deleted after a redeploy.

What is not kept across redeploys: extra users, roles and service accounts created in the UI, query history, and local tables. The login itself comes from the variables, so it always works. The saved schema file contains the data source passwords; it lives on your volume, readable only inside the service.

## Using it

Sign in at `PUPPYGRAPH_URL` with `PUPPYGRAPH_USERNAME` and `PUPPYGRAPH_PASSWORD`, then run this in **Query**:

```
MATCH path = (p:person)-[:knows]->()-[:created]->()
WHERE p.name = 'marko'
RETURN path
```

Two paths come back: marko knows josh, who created lop and ripple. The same question in Gremlin:

```
g.V().hasLabel('person').has('name','marko').out('knows').out('created').values('name')
```

**REST API** (basic auth):

```bash
curl -u puppygraph:$PUPPYGRAPH_PASSWORD -X POST https://<domain>/submitCypher \
  -H 'Content-Type: application/json' \
  -d '{"query":"MATCH (p:person)-[:knows]->(f) RETURN p.name, f.name"}'
```

**From another service in this project**, a Neo4j driver over Bolt:

```python
from neo4j import GraphDatabase
driver = GraphDatabase.driver(os.environ["PUPPYGRAPH_BOLT"],  # ${{PuppyGraph.BOLT_URL}}
                              auth=(os.environ["PUPPYGRAPH_USERNAME"], os.environ["PUPPYGRAPH_PASSWORD"]))
```

**Your own data:** create tables in the Postgres service (connect with its `DATABASE_URL`, or add a TCP proxy for outside tools), or add another data source in the UI, then build or upload a schema in **Schema**. The Developer edition connects up to 2 data sources at once.

## Licence

PuppyGraph is proprietary. The Developer edition is free under the [PuppyQuery Software License Agreement](https://puppygraph.com/eula), which allows evaluation, internal demonstration, testing and other non-production or non-commercial use. Deploying this template means you accept it. For production, PuppyGraph sells commercial editions. This template only references PuppyGraph's public image; nothing is redistributed.

## Resources

- PuppyGraph's documented minimum for dev and test is 8 GB RAM and 10 GB disk.
- Measured on Railway (idle, demo schema loaded): PuppyGraph 2.9 to 3.4 GB, Postgres 0.05 to 0.1 GB.
- The PuppyGraph image is about 3.4 GB, so the first deploy takes a few minutes to pull it.

## Troubleshooting

### The schema is missing after a redeploy

Check the PuppyGraph logs for `[puppygraph-schema]` lines. "saved to the volume" means a change was stored; "uploaded the saved schema" means it was restored. A schema changed less than 30 seconds before a redeploy may not have been saved yet. If you deleted the schema, it stays deleted: upload one in **Schema** or with `POST /schema`.

### A data source password changed

The saved schema keeps the connection details it had. Update the catalog in **Schema** (or upload a corrected schema); the new version is saved within 30 seconds.

### `Free capacity left for meta dir ... is less than 5GB`

PuppyGraph's storage must stay on the container disk (`STORAGE_PATH_ROOT=/var/lib/puppygraph`). Pointing it at the volume triggers this check.

### Gremlin or Bolt clients get authentication errors

Both need `PUPPYGRAPH_USERNAME` and `PUPPYGRAPH_PASSWORD`. Keep `GREMLINSERVER_AUTHENTICATION_ENABLED` and `BOLTSERVER_AUTHENTICATION_ENABLED` equal; PuppyGraph warns against enabling one without the other.

### Exposing Bolt or Gremlin outside Railway

They're private on purpose. If you add a TCP proxy, the login still applies, but the traffic is not encrypted (Railway's TCP proxy adds no TLS). Prefer the HTTPS REST API from outside.

## Tests

Tested on Railway on 2026-11-09:

- A fresh deploy of the template loaded the demo schema by itself. The tutorial Cypher query returned its 2 paths, and the Gremlin query returned `lop` and `ripple`, over the REST API with basic auth.
- Without a login, or with the tutorial password `puppygraph123`, the REST API returned 401, and so did schema upload.
- Through a temporary TCP proxy, Bolt (Neo4j Python driver) and Gremlin (gremlinpython) answered with the generated password. Both refused a wrong password and a connection without credentials.
- A schema changed through the API (one edge removed) was saved to the volume and came back after a redeploy, including its Postgres connection. A plain redeploy restored the demo schema the same way.
