# Dgraph 25.5

Deploy Dgraph 25.5 on Railway as a production-style single node: Dgraph Zero and Alpha with their own volumes, Dgraph ACL so every query, mutation and admin call needs a login, a Caddy gateway as the only public service, and the Ratel UI behind a login.

Not yet published on Railway.

## Overview

- **Zero** (`dgraph/dgraph:v25.5.1`): cluster coordinator, private, volume at `/dgraph`
- **Alpha** (`dgraph/dgraph:v25.5.1`): data and APIs (DQL, GraphQL, admin), private, volume at `/dgraph`, ACL on with `--security anonymous=none`
- **Ratel** (`dgraph/ratel:v25.3.0`): Dgraph's web UI, private, served by the gateway at `/ratel/`
- **Gateway** (`caddy:2.11.9-alpine`): the only public domain. Forwards Dgraph API paths to Alpha, serves Ratel behind HTTP basic auth, and returns 404 for everything else (Alpha's `/debug/pprof`, `/debug/vars` and `/metrics` have no auth)

Why two Dgraph services and not `dgraph/standalone`: the standalone image runs Zero and Alpha in one container and upstream positions it for development and testing. Separate services give each its own volume and restart, and match Dgraph's production layout.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                               Internet                               │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │ HTTPS (public domain)
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Gateway (Caddy, :8080)                                               │
│   /query /mutate /commit /alter /login /graphql /admin /health ...   │
│        -> Alpha (Dgraph ACL token required)                          │
│   /ratel/  -> Ratel (basic auth: AUTH_USERNAME / AUTH_PASSWORD)      │
│   /        -> redirect to /ratel/      anything else -> 404          │
└───────────────┬───────────────────────────────────┬──────────────────┘
                │ alpha.railway.internal:8080       │ ratel.railway.internal:8000
                ▼                                   ▼
┌───────────────────────────────────┐   ┌──────────────────────────────┐
│ Alpha (private)                   │   │ Ratel (private, static UI)   │
│   8080 HTTP   9080 gRPC           │   └──────────────────────────────┘
│   7080 internal (Zero <-> Alpha)  │
│   /dgraph (volume)                │
└───────────────┬───────────────────┘
                │ zero.railway.internal:5080
                ▼
┌───────────────────────────────────┐
│ Zero (private)                    │
│   5080 gRPC   6080 /health only   │
│   /dgraph (volume)                │
└───────────────────────────────────┘
                ▲
                │ Alpha.HTTP_URL / Alpha.GRPC_ADDR (token or groot login)
┌───────────────┴───────────────┐
│ Your services (same project)  │
└───────────────────────────────┘
```

Ratel runs in your browser and calls the gateway's public domain directly (Alpha allows any origin), so the Dgraph login inside Ratel is checked by Alpha like any other client.

## Services

| Service | Source | Role |
|---------|--------|------|
| Gateway | `caddy:2.11.9-alpine` | Public HTTPS entry: Dgraph API pass-through, Ratel behind a login |
| Alpha | `dgraph/dgraph:v25.5.1` | Graph data, DQL and GraphQL APIs, ACL (private, volume) |
| Zero | `dgraph/dgraph:v25.5.1` | Cluster coordinator: timestamps, UIDs, membership (private, volume) |
| Ratel | `dgraph/ratel:v25.3.0` | Web UI for queries, schema, ACL users and cluster state (private) |

## Security

- **Dgraph ACL.** Open source since Dgraph v25.0 (the enterprise licence was removed). Alpha runs with `--acl secret-file=...` (the HMAC key comes from `ACL_SECRET`) and `--security anonymous=none`: a caller without a valid token can only log in and read `/health`. Queries, mutations, GraphQL, schema changes and `drop_all` are refused.
- **groot password.** Dgraph creates `groot` with the password `password`. On the first start Alpha's start script runs Alpha with `--bindall=false` (localhost only), logs in with the default password, sets `DGRAPH_PASSWORD` with `updateUser`, writes a marker file on the volume, and restarts Alpha on all interfaces. Railway's healthcheck only passes after that, and the default password is never reachable from outside. If the marker is missing but `DGRAPH_PASSWORD` already works (for example after a crash at the wrong moment), the script just writes the marker.
- **Gateway allowlist.** Only these paths reach Alpha: `/query`, `/mutate`, `/commit`, `/alter`, `/login`, `/graphql`, `/admin`, `/health`, `/state`, `/ui/keywords`, `/probe/graphql`. Alpha's pprof, expvar, Prometheus metrics, jemalloc and trace pages return 404.
- **Ratel login.** Ratel is a static app, but it still sits behind HTTP basic auth (`AUTH_USERNAME` / `AUTH_PASSWORD`, generated). Inside Ratel you then log in to Dgraph as groot.
- **Zero.** No public domain, and `--limit disable-admin-http=true` turns off its unauthenticated admin pages (only `/health` stays, for Railway's healthcheck).
- **gRPC.** Port 9080 stays on the private network. Railway's TCP proxy forwards raw TCP without TLS, so a gRPC proxy would send the password in plain text.
- **Whitelist.** `--security whitelist=0.0.0.0/0,::/0` allows admin operations from any address, because the gateway and Railway's network sit in front. ACL and `anonymous=none` do the authentication; the whitelist is only a network check.
- Telemetry is off (`--telemetry reports=false`).

## Environment Variables

### User-Configurable

| Service | Variable | Default | Description |
|---------|----------|---------|-------------|
| Alpha | `DGRAPH_PASSWORD` | generated (32) | groot password. Set on the first start only; change it with `updateUser`, then update this value |
| Alpha | `CACHE_SIZE_MB` | `512` | Alpha's cache limit (Dgraph's default is 4096). Raise it on a bigger plan |
| Alpha | `ACL_ACCESS_TTL` | `6h` | Lifetime of access tokens |
| Alpha | `ACL_REFRESH_TTL` | `30d` | Lifetime of refresh tokens |
| Gateway | `AUTH_USERNAME` | `admin` | Ratel login user |
| Gateway | `AUTH_PASSWORD` | generated (24) | Ratel login password |

### Auto-Configured (Do Not Change)

| Service | Variable | Value | Why |
|---------|----------|-------|-----|
| Alpha | `ACL_SECRET` | generated (48) | Signs login tokens. Changing it logs everyone out |
| Alpha | `DGRAPH_USER` | `groot` | ACL superuser, for references |
| Alpha | `ZERO_ADDR` | `${{Zero.RAILWAY_PRIVATE_DOMAIN}}:5080` | Where Alpha finds Zero |
| Alpha | `HTTP_URL` | `http://${{RAILWAY_PRIVATE_DOMAIN}}:8080` | HTTP API for services in the project |
| Alpha | `GRPC_ADDR` | `${{RAILWAY_PRIVATE_DOMAIN}}:9080` | gRPC for client libraries in the project |
| Alpha | `ALPHA_RUN_SH` | script | Start script (ACL flags, first-start password) |
| Alpha, Zero | `PORT` | `8080` / `6080` | Healthcheck port |
| Gateway | `ALPHA_UPSTREAM`, `RATEL_UPSTREAM` | private domains | Gateway targets |
| Gateway | `DGRAPH_URL`, `GRAPHQL_URL`, `RATEL_URL` | public domain | Ready-made URLs |
| Gateway | `GATEWAY_RUN_SH` | script | Caddyfile and start |
| Ratel | `DGRAPH_URL` | `${{Gateway.DGRAPH_URL}}` | Server address pre-filled in Ratel |

The `*_RUN_SH` start scripts live in variables so the template needs no custom image: each service's start command writes the variable to a file and runs it.

## Usage

Log in, then send the access token in `X-Dgraph-AccessToken`:

```bash
URL=https://<gateway-domain>
TOKEN=$(curl -s $URL/login -d '{"userid":"groot","password":"<DGRAPH_PASSWORD>"}' | jq -r .data.accessJWT)

# DQL schema, mutation, query
curl -s $URL/alter -H "X-Dgraph-AccessToken: $TOKEN" -d 'name: string @index(exact) .'
curl -s "$URL/mutate?commitNow=true" -H "X-Dgraph-AccessToken: $TOKEN" -H "Content-Type: application/rdf" \
  -d $'{\n set {\n  _:a <name> "Alice" .\n }\n}'
curl -s $URL/query -H "X-Dgraph-AccessToken: $TOKEN" -H "Content-Type: application/dql" \
  -d '{ q(func: eq(name, "Alice")) { uid name } }'

# GraphQL schema, then the generated API
curl -s $URL/admin -H "X-Dgraph-AccessToken: $TOKEN" -H "Content-Type: application/json" \
  -d '{"query":"mutation { updateGQLSchema(input:{set:{schema:\"type Person { id: ID! name: String! @search(by:[exact]) }\"}}) { gqlSchema { id } } }"}'
curl -s $URL/graphql -H "X-Dgraph-AccessToken: $TOKEN" -H "Content-Type: application/json" \
  -d '{"query":"{ queryPerson { name } }"}'
```

Refresh an expired access token with `curl $URL/login -d '{"refresh_token":"<refreshJWT>"}'`.

Change the groot password (then update `DGRAPH_PASSWORD` on Alpha):

```bash
curl -s $URL/admin -H "X-Dgraph-AccessToken: $TOKEN" -H "Content-Type: application/json" \
  -d '{"query":"mutation { updateUser(input:{filter:{name:{eq:\"groot\"}},set:{password:\"<new password>\"}}) { user { name } } }"}'
```

Create more users and groups with per-predicate permissions in Ratel's ACL tab or with `addUser` / `addGroup` on `/admin`.

## Resources

Idle on Railway (2026-11-09, fresh deploy with a small test graph): Alpha 0.40 GB, Zero 0.13 GB, Ratel 0.04 GB, Gateway 0.02 GB, about 0.6 GB in total. Alpha's memory grows with the cache (`CACHE_SIZE_MB`) and the data you query.

## Tested

2026-11-09 on a Railway test deploy of this config:

- Without a token: DQL query, mutation, `drop_all` and GraphQL query refused. Default and wrong groot passwords rejected. `/debug/pprof/`, `/debug/vars`, `/metrics`, `/debug/prometheus_metrics`, `/debug/jemalloc`, `/debug/z` return 404. Ratel returns 401 without the login and with a wrong password.
- With a groot token: DQL schema, mutation and query (Alice knows Bob); GraphQL schema update, mutation and query.
- Ratel in a browser: basic auth, then the ACL login, then a DQL query returning the graph.
- Data and login kept after redeploying Alpha, and after redeploying Zero (new writes worked afterwards too).

## Troubleshooting

- **"query requires an identified caller"**: the request has no valid token. Log in at `/login` and send `X-Dgraph-AccessToken`. Tokens expire after `ACL_ACCESS_TTL`.
- **"invalid username or password" with `DGRAPH_PASSWORD`**: the password was changed in Dgraph after the first start. The variable is only read on the first start.
- **Alpha deploy waits on the first start**: the healthcheck passes only after the groot password is set (usually 10 to 20 seconds). Look for `alpha: groot password set from DGRAPH_PASSWORD` in Alpha's log.
- **"Unable to connect with ... railway.internal" right after deploy**: private DNS for new services takes a few seconds. Dgraph retries on its own.
- **Ratel says "Dgraph Alpha seems to restrict access"**: you are not logged in to Dgraph yet. Click the server name, open "ACL Account" and log in as groot.
- **Reset everything**: delete both volumes (Zero and Alpha together; they must match) and redeploy.
