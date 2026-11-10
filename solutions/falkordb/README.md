# FalkorDB 6.0.4

Deploy FalkorDB 6.0.4 on Railway with a persistent volume (AOF and snapshots), a generated password, the FalkorDB Browser over HTTPS behind its login, the private network for your Railway services, and a password-protected, TLS-encrypted TCP proxy for outside clients.

> Not yet published on the Railway marketplace.

## Overview

- **FalkorDB** from the official `falkordb/falkordb:6.0.4` image: Redis 8.10 with the FalkorDB graph module (6.0 is the new Rust engine) and the vector set module
- **FalkorDB Browser 2.7.3**, bundled in the same image, on the public HTTPS domain. It asks for the database password
- **Volume** at `/var/lib/falkordb/data`: AOF (fsync every second) plus Redis's default snapshots, and the TLS certificate
- **Password** generated at deploy (32 letters and digits) and required on every connection
- **TLS on the TCP proxy**: Railway's TCP proxy forwards raw TCP, so FalkorDB encrypts it itself with a self-signed certificate created on the first start. Plaintext is refused on the proxy port
- **Private network** on port 6379 (IPv4 and IPv6) for services in the same project

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                            Internet                              │
└───────────────┬───────────────────────────────────┬──────────────┘
                │ HTTPS (public domain)             │ TCP proxy
                │ Browser, login with password      │ rediss:// (TLS), password
                ▼                                   ▼
┌──────────────────────────────────────────────────────────────────┐
│ FalkorDB 6.0.4 (one container)                                   │
│                                                                  │
│   3000  FalkorDB Browser ──► localhost:6379                      │
│   6380  Redis protocol, TLS only (TCP proxy)                     │
│   6379  Redis protocol, plaintext (private network, Browser)     │
│                                                                  │
│        ┌──────────────────────────────────────┐                  │
│        │ /var/lib/falkordb/data (volume)      │                  │
│        │ AOF + RDB, tls/server.{crt,key}      │                  │
│        └──────────────────────────────────────┘                  │
└──────────────────────────────────────────────────────────────────┘
                ▲
                │ redis://default:<password>@falkordb.railway.internal:6379
┌───────────────┴───────────────┐
│ Your services (same project)  │
└───────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| FalkorDB | `falkordb/falkordb:6.0.4` | Graph database and FalkorDB Browser. Public HTTPS domain for the Browser (login), TLS TCP proxy, private network |

## Environment Variables

### User-Configurable

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_PASSWORD` | generated (32 letters and digits) | Password of the `default` user. Applied on every start, so edit it and redeploy to change it, then update your clients |
| `REDIS_ARGS` | see below | Redis server flags. Add flags here (for example `--maxmemory 512mb`), but keep `--requirepass`, the ports and the TLS files |
| `FALKORDB_ARGS` | image default (`MAX_QUEUED_QUERIES 25 TIMEOUT 1000 RESULTSET_SIZE 10000`) | Not set by the template. Add it to change FalkorDB module settings; setting it replaces the image defaults |

`REDIS_ARGS` defaults to:

```
--requirepass ${{DB_PASSWORD}} --bind 0.0.0.0 :: --port 6379 --tls-port 6380
--tls-cert-file /var/lib/falkordb/data/tls/server.crt --tls-key-file /var/lib/falkordb/data/tls/server.key
--tls-ca-cert-file /var/lib/falkordb/data/tls/server.crt --tls-auth-clients no
--appendonly yes --appendfsync everysec
```

### Auto-Configured (Do Not Change)

| Variable | Value | Why |
|----------|-------|-----|
| `DB_USER` | `default` | The Redis default user. Reference it as `${{FalkorDB.DB_USER}}` |
| `PRIVATE_URL` | `redis://default:${{DB_PASSWORD}}@${{RAILWAY_PRIVATE_DOMAIN}}:6379` | Connection URL for services in this project: `${{FalkorDB.PRIVATE_URL}}` |
| `PRIVATE_HOST` | `${{RAILWAY_PRIVATE_DOMAIN}}` | For clients that take host and port (6379) separately |
| `PUBLIC_URL` | `rediss://default:${{DB_PASSWORD}}@${{RAILWAY_TCP_PROXY_DOMAIN}}:${{RAILWAY_TCP_PROXY_PORT}}` | Connection URL for clients outside Railway (TLS) |
| `BROWSER_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | FalkorDB Browser |
| `FALKORDB_HOST`, `FALKORDB_PORT` | `localhost`, `6379` | Pre-fill the Browser login form with the database in the same container |
| `FALKORDB_AUTO_CONNECT` | `false` | The Browser shows its login form |
| `NEXTAUTH_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Browser login redirects |
| `AUTH_SECRET`, `ENCRYPTION_KEY` | generated (64 hex characters) | Browser session signing and credential encryption, fixed values instead of a random one per container. The Browser still asks you to log in again after a redeploy, because it keeps the database connection in memory |
| `PORT` | `3000` | Port of the public domain (Browser) and the healthcheck |
| `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` | `30` | Time for Redis to write its data on redeploy |

**Never add `FALKORDB_PASSWORD` or `FALKORDB_CONNECTION_URL` to this service.** The Browser reads them from its environment, and its "pre-configured connection" login then works without a password for anyone who opens the page.

The service has a start command. On the first start it creates a self-signed certificate (`openssl`, RSA 2048, valid 10 years, named after the TCP proxy domain, with the private domain and `localhost` as alternative names) in `/var/lib/falkordb/data/tls`, hands the data folder to the `falkordb` user, and then runs the image's normal entrypoint. Later starts keep the certificate, so redeploys don't change it. Every start prints `TLS: certificate sha256 Fingerprint=...` in the deploy log.

## Connecting

### FalkorDB Browser

Open `BROWSER_URL`. The login form shows host `localhost`, port `6379` and user `default`; enter `DB_PASSWORD`. Wrong or empty passwords are refused.

The login form also accepts other hosts: the Browser server then opens a Redis connection to that host and port. That is how the upstream Browser works. Those connections still need that server's own password.

### Services in the same project

```
FALKORDB_URL=${{FalkorDB.PRIVATE_URL}}
FALKORDB_HOST=${{FalkorDB.PRIVATE_HOST}}
FALKORDB_PORT=6379
FALKORDB_USERNAME=${{FalkorDB.DB_USER}}
FALKORDB_PASSWORD=${{FalkorDB.DB_PASSWORD}}
```

The private port is plaintext, like Railway's own Redis, and only reachable from inside the project. Port 6380 (TLS) also listens on the private network; that path is untested.

### Outside Railway (TCP proxy)

The proxy points at the TLS port, so use `rediss://` or `ssl=True`. The certificate is self-signed: turn off verification, or check it against the fingerprint from the deploy log (`openssl s_client -connect <proxy-domain>:<port> | openssl x509 -noout -fingerprint -sha256`).

```python
from falkordb import FalkorDB

db = FalkorDB(host="<proxy-domain>", port=<proxy-port>, password="<DB_PASSWORD>",
              ssl=True, ssl_cert_reqs="none")
g = db.select_graph("social")
g.query("CREATE (:Person {name:'Ada'})-[:KNOWS {since:1843}]->(:Person {name:'Charles'})")
print(g.query("MATCH (a)-[k:KNOWS]->(b) RETURN a.name, k.since, b.name").result_set)
```

```bash
redis-cli --tls --insecure -u "<PUBLIC_URL>" GRAPH.LIST
```

To use your own certificate, replace `server.crt` and `server.key` in `/var/lib/falkordb/data/tls` and redeploy.

## Persistence

AOF is on (`appendonly yes`, fsync every second) next to Redis's default RDB snapshots (`3600 1 300 100 60 10000`). Both live on the volume. On a redeploy Redis loads the AOF, so at most about a second of writes can be lost on a crash. FalkorDB keeps graphs in RAM, so the service's memory grows with your data; set `--maxmemory` in `REDIS_ARGS` if you want a hard limit.

## Resource usage

Measured on Railway on 2026-11-09: about 0.07 to 0.19 GB of RAM idle (Redis with FalkorDB and the Browser together) and close to zero CPU.

## Testing

Tested on Railway on 2026-11-09:

- Through the TCP proxy with redis-py, the `falkordb` Python client and redis-cli: no password and a wrong password refused, plaintext refused on the proxy port, graph created and queried over TLS
- From another service on the private network: no password refused, `PING` and a graph query with the password
- `CONFIG GET bind` returns `0.0.0.0 ::`; AOF enabled
- Redeploy: graph data loaded from the AOF, same certificate fingerprint
- Browser: login with the right password, refused with a wrong one, an empty one and the "pre-configured connection" login; Browser API routes return 401 without a session

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Connection reset` or `wrong version number` through the proxy | The proxy port is TLS only. Use `rediss://`, `ssl=True` or `redis-cli --tls` |
| `certificate verify failed` | The certificate is self-signed. Use `ssl_cert_reqs="none"` / `--insecure`, or trust `tls/server.crt` from the volume |
| `NOAUTH Authentication required` | Pass `DB_PASSWORD` (user `default`) |
| Browser login fails with the right password | Keep host `localhost` and port `6379` in the form (TLS unticked); the Browser runs in the same container |
| Browser shows "No active connection. Please sign in again" after a redeploy | Expected: the Browser keeps its database connection in memory. Log in again |
| Log says `WARNING Memory overcommit must be enabled` | The warning is harmless at normal sizes; AOF rewrites and loading after a redeploy worked in testing |
| Redis can't read the TLS files after you replaced them | The start command hands them to the `falkordb` user on the next start. Redeploy |

## Licence

FalkorDB is licensed under the Server Side Public License v1 (SSPL). Running it for your own applications in your own Railway account is fine. Offering FalkorDB itself as a service to third parties triggers the SSPL's source-disclosure conditions. The template only references FalkorDB's official image.
