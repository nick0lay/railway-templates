# Neo4j 2026.10 Community

Deploy Neo4j 2026.10 Community on Railway with a persistent volume, a generated password, the APOC plugin, Neo4j Browser over HTTPS, private Bolt for your Railway services and a password-protected TCP proxy for outside drivers.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/neo4j-202610-community?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Overview

- **Neo4j** from the official `neo4j:2026.10.1-community` image
- **Volume** at `/data`: databases, transaction logs and users survive redeploys
- **APOC core** loaded from the image (no download at start)
- **Explicit memory**: 512 MB heap and 256 MB page cache, so the JVM doesn't size itself from the container limit
- **Neo4j Browser and HTTP Query API** on the public HTTPS domain, both behind the database password
- **Bolt** on the private network for services in the project, and on a TCP proxy for drivers outside Railway

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                            Internet                              │
└───────────────┬───────────────────────────────────┬──────────────┘
                │ HTTPS (public domain)             │ TCP proxy
                │ Browser + Query API, password     │ Bolt, password, no TLS
                ▼                                   ▼
┌──────────────────────────────────────────────────────────────────┐
│ Neo4j 2026.10.1 Community (+ APOC)                               │
│                                                                  │
│   7474 HTTP   Browser at /browser/, Query API at /db/neo4j/...   │
│   7687 Bolt   private network (neo4j.railway.internal) + proxy   │
│                                                                  │
│        ┌──────────────────────────────────────┐                  │
│        │  /data  (volume)                     │                  │
│        └──────────────────────────────────────┘                  │
└──────────────────────────────────────────────────────────────────┘
                ▲
                │ bolt://neo4j.railway.internal:7687
┌───────────────┴───────────────┐
│ Your services (same project)  │
└───────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Neo4j | `neo4j:2026.10.1-community` | Graph database. Public HTTPS domain for Browser (password), private Bolt, Bolt TCP proxy |

## Environment Variables

### User-Configurable

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_PASSWORD` | generated (32 letters and digits) | Password of the `neo4j` user. Applied on the **first start only**, see [Changing the password](#changing-the-password) |
| `NEO4J_server_memory_heap_initial__size` | `512m` | JVM heap at start. Keep it equal to the max size |
| `NEO4J_server_memory_heap_max__size` | `512m` | JVM heap limit. Raise it for big transactions or many concurrent queries |
| `NEO4J_server_memory_pagecache_size` | `256m` | Page cache for graph data and indexes. Ideally about the size of your store on disk |
| `NEO4J_PLUGINS` | `["apoc"]` | Plugins loaded at start. APOC core ships in the image. Other plugins (for example `"graph-data-science"`) are downloaded at every start |

Any other Neo4j setting can be added as a variable: prefix it with `NEO4J_`, replace `.` with `_` and `_` with `__`. For example `db.transaction.timeout` becomes `NEO4J_db_transaction_timeout`.

### Auto-Configured (Do Not Change)

| Variable | Value | Why |
|----------|-------|-----|
| `NEO4J_AUTH` | `neo4j/${{DB_PASSWORD}}` | Initial credentials, read by the image on the first start |
| `DB_USER` | `neo4j` | The admin user of Community Edition. Reference it as `${{Neo4j.DB_USER}}` |
| `BOLT_URL` | `bolt://${{RAILWAY_PRIVATE_DOMAIN}}:7687` | Driver URI for services in this project: `${{Neo4j.BOLT_URL}}` |
| `BOLT_PUBLIC_URL` | `bolt://${{RAILWAY_TCP_PROXY_DOMAIN}}:${{RAILWAY_TCP_PROXY_PORT}}` | Driver URI for clients outside Railway |
| `HTTP_URL` | `http://${{RAILWAY_PRIVATE_DOMAIN}}:7474` | HTTP Query API on the private network |
| `BROWSER_URL` | `https://<domain>/browser/?dbms=https://neo4j@<domain>:443` | Neo4j Browser link with the connection form filled in |
| `NEO4J_server_default__listen__address` | `::` | Listens on IPv6 and IPv4. Railway's private network is IPv6 |
| `PORT` | `7474` | Port of the public domain and the healthcheck |
| `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` | `60` | Time to close the store cleanly on redeploy |

The variables your apps reference (`DB_*`, `BOLT_*`, `HTTP_URL`) don't start with `NEO4J_` on purpose: the image turns every `NEO4J_*` variable into a Neo4j setting, and Neo4j refuses to start on settings it doesn't know.

## Connecting

### Neo4j Browser

Open `BROWSER_URL` from the Neo4j service's Variables and log in as `neo4j` with `DB_PASSWORD`.

If you open `https://<domain>/browser/` directly, the form suggests `neo4j://<domain>:7687`, which doesn't work on Railway. Choose protocol **`https://`** and enter **`<domain>:443`**. Browser then runs your queries over the HTTP Query API on the same domain.

### From a service in the same Railway project

```
NEO4J_URI=${{Neo4j.BOLT_URL}}
NEO4J_USERNAME=${{Neo4j.DB_USER}}
NEO4J_PASSWORD=${{Neo4j.DB_PASSWORD}}
```

Use the names your app expects. For example, LightRAG and Graphiti read `NEO4J_URI`, `NEO4J_USERNAME` / `NEO4J_USER` and `NEO4J_PASSWORD`. Traffic stays on the private network (no TLS, no egress cost). `neo4j://` works as well as `bolt://`.

### From outside Railway (drivers, Cypher Shell)

Read `BOLT_PUBLIC_URL` and `DB_PASSWORD` from the Neo4j service's Variables.

```python
from neo4j import GraphDatabase

with GraphDatabase.driver("bolt://<proxy-domain>:<port>", auth=("neo4j", "<DB_PASSWORD>")) as driver:
    driver.verify_connectivity()
    records, _, _ = driver.execute_query("RETURN apoc.version() AS apoc")
    print(records[0]["apoc"])
```

```bash
cypher-shell -a bolt://<proxy-domain>:<port> -u neo4j -p '<DB_PASSWORD>'
```

`neo4j://<proxy-domain>:<port>` works too: no advertised address is set, so Neo4j routes clients back to the address they used. The TCP proxy checks the password but does not encrypt traffic. Prefer the private network for sensitive data, or delete the TCP proxy in the service's Networking settings if you don't need it.

### HTTP Query API

```bash
curl -u neo4j:<DB_PASSWORD> -H 'Content-Type: application/json' \
  -d '{"statement": "MATCH (n) RETURN count(n) AS nodes"}' \
  https://<domain>/db/neo4j/query/v2
```

### Encrypted Bolt over WebSocket (optional)

Tools that speak Bolt over WebSocket (the hosted Browser at browser.neo4j.io, the JavaScript driver) can connect with TLS through Railway's HTTPS edge. In the Neo4j service's Settings → Networking, add a second public domain with target port **7687**, then connect with `neo4j+s://<that-domain>:443`. Python and Java drivers don't support WebSocket; they use the TCP proxy.

## Changing the password

`DB_PASSWORD` is written to the auth store on the first start. Changing the variable later does not change the database password. To rotate it:

1. In Browser, run `ALTER CURRENT USER SET PASSWORD FROM '<old>' TO '<new>'`.
2. Set `DB_PASSWORD` on the Neo4j service to the new value, so the services that reference `${{Neo4j.DB_PASSWORD}}` get it, and redeploy them.

## Backups

- **Railway volume backups**: enable them on the Neo4j volume (service → Volume → Backups) for scheduled snapshots.
- **Export with APOC**: `CALL apoc.export.cypher.all(null, {stream: true})` returns the whole graph as Cypher statements you can save and replay.
- **Offline dump**: Community Edition supports `neo4j-admin database dump` only while the database is stopped, so snapshots or APOC exports are easier on Railway.

## Cost and plan

Neo4j idles at about 1.3 to 1.7 GB of RAM with the default settings (measured on Railway). The JVM holds 512 MB of heap and about 0.2 GB of non-heap memory, and the rest is native memory and file cache. Grow the heap and page cache together with your data, and the volume when the store grows.

## Troubleshooting

- **Browser says it can't connect to `neo4j://...:7687`**: choose protocol `https://` and port `443`, or open `BROWSER_URL`.
- **`The client is unauthorized due to authentication failure`**: the password in your app doesn't match the database. If you changed `DB_PASSWORD` after the first start, see [Changing the password](#changing-the-password).
- **`Unrecognized setting. No declared setting with name: ...`**: a variable starting with `NEO4J_` isn't a valid Neo4j setting (for example `NEO4J_URI` on the Neo4j service). Rename or remove it.
- **Connection refused from another service**: use `${{Neo4j.BOLT_URL}}` (private domain, port 7687). Check that `NEO4J_server_default__listen__address` is still `::`.
- **Out of memory or slow queries**: raise the heap and page cache variables, and the service memory with them.
- **A plugin fails to download at start**: plugins other than APOC are fetched from the internet on every start. Remove them from `NEO4J_PLUGINS` to check.

## Testing

Tested on 2026-11-09: clean deploy from the template; a node written and read through the TCP proxy with the Python driver (`bolt://` and `neo4j://`) and from a service on the private network; `apoc.version()` returned 2026.10.1; wrong passwords rejected on Bolt and HTTP; Neo4j Browser loaded over HTTPS and ran queries with the `https://` protocol; Bolt over WebSocket on a second domain worked with `neo4j+s://`; data still there after redeploys.
