# Memgraph 3.14 + Lab

Deploy Memgraph 3.14 with MAGE graph algorithms and Memgraph Lab on Railway: a persistent volume, a generated user and password, a memory limit, Bolt with TLS for your Railway services and for outside drivers through a TCP proxy, and Lab on HTTPS behind the Memgraph login.

Not yet published on Railway.

## Overview

- **Memgraph** from `memgraph/memgraph-mage:3.14.0`: the database plus MAGE (PageRank, community detection, centrality, shortest paths, link prediction and more)
- **Memgraph Lab** from `memgraph/lab:3.14.2`: web IDE for Cypher, graph views, schema, import and logs
- **Volume** at `/var/lib/memgraph`: snapshots, write-ahead log, users and the TLS certificate survive redeploys
- **Generated password** for the `memgraph` user, created on the first start
- **Memory limit** of 2048 MiB by default, so a query that would use more fails cleanly
- **Bolt TLS** with a self-signed certificate created on the first start. Railway's TCP proxy forwards raw TCP, so Memgraph encrypts Bolt itself. Plaintext Bolt is refused
- **Lab** on a public HTTPS domain. It shows nothing until you log in with the Memgraph user and password, and its server connects to Memgraph over the private network

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                            Internet                              │
└───────────────┬───────────────────────────────────┬──────────────┘
                │ HTTPS (public domain)             │ TCP proxy
                │ Lab, Memgraph login               │ Bolt, TLS, password
                ▼                                   │
┌───────────────────────────────┐                   │
│ Memgraph Lab 3.14.2           │                   │
│ 3000 HTTP                     │                   │
└───────────────┬───────────────┘                   │
                │ bolt+ssc://memgraph.railway.internal:7687
                │ (Lab's server, private network)   │
                ▼                                   ▼
┌──────────────────────────────────────────────────────────────────┐
│ Memgraph 3.14.0 + MAGE                                           │
│                                                                  │
│   7687 Bolt (TLS)   private network + TCP proxy                  │
│   7444 logs         private network (Lab's log viewer)           │
│                                                                  │
│        ┌──────────────────────────────────────┐                  │
│        │  /var/lib/memgraph  (volume)         │                  │
│        └──────────────────────────────────────┘                  │
└──────────────────────────────────────────────────────────────────┘
                ▲
                │ bolt+ssc://memgraph.railway.internal:7687
┌───────────────┴───────────────┐
│ Your services (same project)  │
└───────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Memgraph | `memgraph/memgraph-mage:3.14.0` | Graph database with MAGE. Private, plus a TCP proxy for Bolt with TLS and password |
| Memgraph Lab | `memgraph/lab:3.14.2` | Web IDE. Public HTTPS domain, asks for the Memgraph login |

## Environment Variables

### User-Configurable

Memgraph service:

| Variable | Default | Description |
|----------|---------|-------------|
| `MEMGRAPH_USER` | `memgraph` | User created on the **first start**. The first user gets all privileges |
| `MEMGRAPH_PASSWORD` | generated (32 letters and digits) | Its password. Applied on the **first start only**, see [Changing the password](#changing-the-password) |
| `MEMGRAPH_MEMORY_LIMIT` | `2048` | Memory limit in MiB. Memgraph keeps the whole graph in RAM; raise it with your data and give the service that much memory |
| `MEMGRAPH_LOG_LEVEL` | `WARNING` | `TRACE`, `DEBUG`, `INFO`, `WARNING`, `ERROR` or `CRITICAL` |
| `MEMGRAPH_TELEMETRY` | `true` | Anonymous usage data to Memgraph (upstream default). Set `false` to turn it off |
| `MEMGRAPH_EXTRA_FLAGS` | empty (optional) | Extra Memgraph flags, for example `--storage-mode=IN_MEMORY_ANALYTICAL` or `--query-execution-timeout-sec=600` |

### Auto-Configured (Do Not Change)

Memgraph service:

| Variable | Value | Why |
|----------|-------|-----|
| `DB_USER` | `${{MEMGRAPH_USER}}` | For other services: `${{Memgraph.DB_USER}}` |
| `DB_PASSWORD` | `${{MEMGRAPH_PASSWORD}}` | For other services: `${{Memgraph.DB_PASSWORD}}` |
| `BOLT_URL` | `bolt+ssc://${{RAILWAY_PRIVATE_DOMAIN}}:7687` | Driver URI for services in this project: `${{Memgraph.BOLT_URL}}` |
| `BOLT_PUBLIC_URL` | `bolt+ssc://${{RAILWAY_TCP_PROXY_DOMAIN}}:${{RAILWAY_TCP_PROXY_PORT}}` | Driver URI for clients outside Railway |
| `RAILWAY_RUN_UID` | `0` | The start command runs as root to create the certificate and give the volume to the `memgraph` user, then starts Memgraph as `memgraph` |
| `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` | `60` | Time to write the snapshot on exit during a redeploy |

The Memgraph service has a start command. On the first start it creates a self-signed certificate (`openssl`, RSA 2048, valid 10 years, named after the TCP proxy domain) in `/var/lib/memgraph/certificates`, then starts Memgraph with TLS on Bolt, listening on IPv6 (Railway's private network) and IPv4. It keeps the certificate on later starts, so redeploys don't change it.

Memgraph Lab service:

| Variable | Value | Why |
|----------|-------|-----|
| `QUICK_CONNECT_MG_HOST` | `${{Memgraph.RAILWAY_PRIVATE_DOMAIN}}` | Host filled into Lab's connection form |
| `QUICK_CONNECT_MG_PORT` | `7687` | Bolt port filled into the form |
| `QUICK_CONNECT_MG_IS_ENCRYPTED` | `true` | Ticks **Encrypted**. Memgraph refuses plaintext Bolt |
| `QUICK_CONNECT_IS_DISABLED` | `true` | Hides the one-click Quick connect panel, which can't pass a password and would only show "Memgraph not detected" |
| `PORT` | `3000` | Port of the public domain and the healthcheck |

## Connecting

### Memgraph Lab

1. Open the Memgraph Lab service's public domain.
2. Choose **Memgraph instance**. Host (`memgraph.railway.internal`), port `7687` and **Encrypted** are already filled in.
3. Under Authentication choose **Username/password**, enter `memgraph` and `MEMGRAPH_PASSWORD` from the Memgraph service's Variables, and click **Connect**.

Lab's server opens the Bolt connection, not your browser, so Memgraph doesn't need a public HTTP port. Lab keeps its session in your browser; without a login its API answers 401. The connection form accepts any host, so anyone who reaches the Lab domain can make Lab's server try a Bolt connection, but Lab shows nothing without valid credentials. Delete Lab's public domain (or the service) if you don't use it.

### From a service in the same Railway project

```
MEMGRAPH_URI=${{Memgraph.BOLT_URL}}
MEMGRAPH_USERNAME=${{Memgraph.DB_USER}}
MEMGRAPH_PASSWORD=${{Memgraph.DB_PASSWORD}}
```

Use the names your app expects. Memgraph speaks Bolt, so apps built for Neo4j usually work with `NEO4J_URI`, `NEO4J_USERNAME` and `NEO4J_PASSWORD` set to the same values, as long as they use `bolt+ssc://` and don't need Neo4j-only procedures.

### From outside Railway

Read `BOLT_PUBLIC_URL` and `MEMGRAPH_PASSWORD` from the Memgraph service's Variables.

```python
from neo4j import GraphDatabase

with GraphDatabase.driver("bolt+ssc://<proxy-domain>:<port>", auth=("memgraph", "<MEMGRAPH_PASSWORD>")) as driver:
    driver.execute_query("MERGE (a:City {name: 'Zagreb'})-[:ROAD]->(b:City {name: 'Split'})")
    records, _, _ = driver.execute_query("CALL pagerank.get() YIELD node, rank RETURN node.name AS name, rank")
    print(records)
```

[GQLAlchemy](https://memgraph.com/docs/client-libraries/python) and `mgconsole` work the same way with TLS turned on.

- Use `bolt+ssc://` (TLS with a self-signed certificate, not checked against public authorities).
- `neo4j://` and `neo4j+ssc://` don't work: they ask for routing information, which a single Memgraph server doesn't provide.
- Plain `bolt://` is refused, and `bolt+s://` fails certificate verification.
- To be sure you talk to your own server, compare the fingerprint in the Memgraph deploy log (`Bolt TLS: certificate sha256 Fingerprint=...`) with `openssl s_client -connect <proxy-domain>:<port> </dev/null | openssl x509 -noout -fingerprint -sha256`.
- To use your own certificate, replace `bolt.crt` and `bolt.key` in `/var/lib/memgraph/certificates` and redeploy.
- Delete the TCP proxy in the Memgraph service's Networking settings if you don't need outside access.

## Changing the password

`MEMGRAPH_USER` and `MEMGRAPH_PASSWORD` create the user only when the database has no users yet. Changing the variable later does not change the password. To rotate it:

1. In Lab, run `SET PASSWORD TO '<new>' REPLACE '<old>';` (or, as an admin, `SET PASSWORD FOR memgraph TO '<new>';`).
2. Set `MEMGRAPH_PASSWORD` on the Memgraph service to the new value, so services that reference `${{Memgraph.DB_PASSWORD}}` get it, and redeploy them.

## Backups

- **Railway volume backups**: enable them on the Memgraph volume for scheduled snapshots.
- **Snapshots**: Memgraph writes a snapshot every 5 minutes and on shutdown, and keeps the last 3. `CREATE SNAPSHOT;` writes one now.
- **Export**: Memgraph Lab has an Export page.

## Cost and plan

On Railway, Memgraph with MAGE idled at about 0.75 GB of RAM with an almost empty graph (MAGE loads its Python modules at start), and Lab at about 0.07 GB. Memgraph keeps all data in memory, so plan RAM for your graph plus query headroom, and raise `MEMGRAPH_MEMORY_LIMIT` with it.

## Licences

- Memgraph Community Edition: Business Source License 1.1 with an Additional Use Grant. You may use it in production for your own internal business purposes, but not to offer it to others as a database service or to build a competing product. See [memgraph.com/legal](https://memgraph.com/legal).
- Memgraph Lab: free under the Memgraph Lab User License Agreement, for your internal business use; the agreement describes Lab as provided for development, testing and evaluation.
- Some MAGE modules (the `*_online` algorithms and `cross_database`) need a Memgraph Enterprise licence. Memgraph skips them at start and logs a warning; everything else in MAGE works.

## Troubleshooting

- **Lab: "Connection was closed by server"**: **Encrypted** is not ticked. Memgraph only accepts TLS on Bolt.
- **Lab: "Wrong username or password"**: use `memgraph` and `MEMGRAPH_PASSWORD`. If you changed the variable after the first start, see [Changing the password](#changing-the-password).
- **`incomplete handshake response`**: the client uses plain `bolt://`. Switch to `bolt+ssc://`.
- **`Unable to retrieve routing information`**: the client uses `neo4j://` or `neo4j+ssc://`. Switch to `bolt+ssc://`.
- **`SSLCertVerificationError`**: the client uses `bolt+s://`. Use `bolt+ssc://`.
- **`ConfigurationError` about encryption settings**: the app passes its own `encrypted` / `trust` options together with a `+ssc` URI. Remove those options.
- **Queries fail with a memory limit error**: raise `MEMGRAPH_MEMORY_LIMIT` and the service memory.
- **Log line `getaddrinfo ... resolving :::7444`**: harmless. Memgraph then listens for Lab's log viewer on `[::]:7444`.
- **Warnings about modules that need an enterprise licence**: expected, see [Licences](#licences).

## Testing

Tested on 2026-11-09 on Railway: both services deployed; the certificate was created on the first start; through the TCP proxy the Python driver with `bolt+ssc://` wrote and read a node and ran MAGE `pagerank.get()`; a wrong password, plain `bolt://`, `bolt+s://` and `neo4j+ssc://` were refused; the fingerprint seen through the proxy matched the log; Lab over HTTPS refused its API without a login and a wrong password, logged in with the generated password over the private network, ran a query and streamed Memgraph logs; after a redeploy the data and the certificate fingerprint were unchanged.
