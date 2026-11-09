# Temporal

Self-hosted [Temporal](https://github.com/temporalio/temporal) 1.32 on Railway, from official images, on PostgreSQL. Temporal's all-in-one `auto-setup` image stopped at 1.29, so this template does the schema setup in a separate Admin Tools service. It creates and upgrades the database schema on every deploy, then creates the default namespace. The server waits for it before starting. The Temporal UI sits behind a login, and the gRPC frontend and database stay private. Every version is pinned and tested.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/temporal-132?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
          Browser                         Your workers and apps
             │ HTTPS, login required      (services in the same Railway project)
             ▼                                   │ gRPC :7233, private network
┌────────────────────────────────────────────────┼──────────────────┐
│ Railway project                                ▼                  │
│                                                                   │
│  Gateway :8080 (public, Caddy, basic auth)                        │
│        │                                                          │
│        ▼                                                          │
│  UI :8080 (private) ──gRPC──▶ Temporal :7233 gRPC, :7243 HTTP     │
│                                (private; frontend, history,       │
│                                 matching, worker in one process)  │
│                                     │            ▲                │
│                                     │            │ waits for      │
│                                     ▼            │ schema ready   │
│  Admin Tools (private) ──schema──▶ Postgres :5432 (private, vol.) │
│    temporal-sql-tool, temporal CLI  temporal, temporal_visibility │
└───────────────────────────────────────────────────────────────────┘
```

Only the Gateway has a public domain. Everything else is reachable only over Railway's private network.

## Services

| Service | Source | Role |
|---------|--------|------|
| Temporal | `temporalio/server:1.32.2` | Temporal server, all four roles in one process; gRPC frontend on 7233 (private) |
| Admin Tools | `temporalio/admin-tools:1.32.2` | Creates and upgrades the schema, creates the default namespace, then stays up as a shell with the `temporal` CLI (private) |
| UI | `temporalio/ui:2.58.1` | Temporal Web UI (private) |
| Gateway | `caddy:2.11.9-alpine` | Public entry point: login (HTTP basic auth) in front of the UI |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:17` | History (`temporal`) and visibility (`temporal_visibility`) databases (private, volume) |

## What this template does differently

- **Temporal 1.32 on official images.** No custom or third-party Temporal image, and no `auto-setup` (its last release is 1.29).
- **Automatic schema setup and upgrades.** On every start, Admin Tools creates both databases if needed and runs `temporal-sql-tool update-schema` for history and visibility. The server waits until that has finished, so upgrading means bumping the image tags and redeploying.
- **Default namespace** created on first start (`default`, 72h retention).
- **No Elasticsearch.** Visibility (workflow search and filters in the UI) uses PostgreSQL. This keeps the stack small: about 0.2 GB of RAM at idle for all five services.
- **Login on the UI.** The Temporal UI has no built-in login except OIDC. Here a Caddy gateway asks for a user name and password, and the UI service has no public domain.
- **Private gRPC frontend.** The frontend has no authentication in this setup, so it is not exposed to the internet by default.
- **IPv6 private network.** The server listens on all addresses, which Railway's private network needs.

## After deploy

1. Open the Gateway service's URL. Your browser asks for a login: the user is `AUTH_USERNAME` (`admin` by default) and the password is the generated `AUTH_PASSWORD` (Gateway → Variables).
2. The UI opens the `default` namespace. It is empty until a worker runs workflows.
3. Point your workers and clients at the frontend. In another service in the same project, set:

   ```
   TEMPORAL_ADDRESS=${{Temporal.RAILWAY_PRIVATE_DOMAIN}}:7233
   TEMPORAL_NAMESPACE=default
   ```

   For example, in Go: `client.Dial(client.Options{HostPort: os.Getenv("TEMPORAL_ADDRESS"), Namespace: "default"})`. In TypeScript: `NativeConnection.connect({ address: process.env.TEMPORAL_ADDRESS })`. In Python: `await Client.connect(os.environ["TEMPORAL_ADDRESS"], namespace="default")`.

4. For the `temporal` CLI, open a shell on Admin Tools with `railway ssh` (select the Admin Tools service). `TEMPORAL_ADDRESS` is already set:

   ```
   temporal operator namespace list
   temporal operator namespace create -n my-app --retention 168h
   temporal workflow list -n default
   ```

### Workers outside Railway

The frontend is private by default. To reach it from outside Railway, add a TCP proxy to the Temporal service for port 7233 (Temporal → Settings → Networking → TCP Proxy) and connect to the `host:port` Railway shows. **Anyone who has that address can then start, read and terminate workflows**, because the frontend has no authentication in this template. Only do this with mTLS configured (see Temporal's [security docs](https://docs.temporal.io/self-hosted-guide/security) and the `TEMPORAL_TLS_*` variables of the server image), or for short tests. Remove the TCP proxy when you no longer need it.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Gateway | `AUTH_USERNAME` | `admin` | Login user name for the UI |
| Gateway | `AUTH_PASSWORD` | generated | Login password. Change it and redeploy the Gateway to revoke access. The Gateway refuses to start if it is empty |
| Temporal | `LOG_LEVEL` | `warn` | `debug`, `info`, `warn`, `error` |
| Temporal | `DYNAMIC_CONFIG_YAML` | `limit.maxIDLength: 255` | Temporal [dynamic config](https://docs.temporal.io/references/dynamic-config) as YAML. Edit and redeploy Temporal |
| Admin Tools | `DEFAULT_NAMESPACE` | `default` | Namespace created on first start |
| Admin Tools | `DEFAULT_NAMESPACE_RETENTION` | `72h` | Retention of closed workflows in that namespace; applies when it is created. Change later with `temporal operator namespace update -n default --retention 168h` |
| UI | `TEMPORAL_CORS_ORIGINS` | `https://` + Gateway domain | Set to the URL you open the UI on; update it when you add a custom domain |
| UI | `TEMPORAL_DEFAULT_NAMESPACE` | `default` | Namespace the UI opens first |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Temporal | `DB`, `POSTGRES_SEEDS`, `DB_PORT`, `POSTGRES_USER`, `POSTGRES_PWD` | Postgres on the private network | Persistence |
| Temporal | `DBNAME`, `VISIBILITY_DBNAME` | `temporal`, `temporal_visibility` | Database names; Admin Tools reads them from Temporal |
| Temporal | `ENABLE_ES` | `false` | Visibility on Postgres |
| Temporal | `NUM_HISTORY_SHARDS` | `4` | **Fixed when the cluster is first created.** Changing it later breaks the cluster |
| Temporal | `BIND_ON_IP`, `TEMPORAL_BROADCAST_ADDRESS` | `::`, `127.0.0.1` | Listen on IPv4 and IPv6; single-node cluster |
| Temporal | `PORT` | `7243` | Frontend HTTP API; the healthcheck calls `/api/v1/system-info` |
| Temporal | `SCHEMA_READY_HOST`, `SCHEMA_READY_PORT` | Admin Tools, `7299` | The server starts after Admin Tools opens this port |
| Temporal | `TEMPORAL_RUN_SH` | script | Start script: waits for the schema, writes the dynamic config, starts the server |
| Admin Tools | `SQL_*` | Postgres on the private network | Schema tool connection |
| Admin Tools | `TEMPORAL_DBNAME`, `VISIBILITY_DBNAME` | from Temporal | Same databases as the server |
| Admin Tools | `TEMPORAL_ADDRESS` | Temporal private host `:7233` | Used by the `temporal` CLI |
| Admin Tools | `READY_PORT` | `7299` | Must match `SCHEMA_READY_PORT` |
| Admin Tools | `ADMIN_RUN_SH` | script | Start script: schema, namespace, then idle |
| UI | `TEMPORAL_ADDRESS`, `TEMPORAL_UI_PORT`, `PORT` | Temporal `:7233`, `8080`, `8080` | UI connection and port |
| Gateway | `PORT`, `UI_UPSTREAM`, `GATEWAY_RUN_SH` | `8080`, UI private host, script | Caddy with basic auth in front of the UI |
| Postgres | `POSTGRES_PASSWORD` | generated | Database password |

## Upgrading

Temporal server, admin tools and UI are released together often. To upgrade:

1. Back up Postgres (see below).
2. Set the same new tag on **Admin Tools** and **Temporal** (for example `1.32.3`), and optionally a new UI tag. Read the [release notes](https://github.com/temporalio/temporal/releases) first; Temporal supports upgrading one minor version at a time (1.32 → 1.33, not 1.32 → 1.34).
3. Deploy Admin Tools first and wait for `setup: done` in its logs (the schema is then upgraded), then deploy Temporal and the UI.

Admin Tools must stay deployed: the server waits for it every time it starts. It uses almost no memory while idle.

## Backups

All state is in the Postgres service: workflow histories in `temporal` and search data in `temporal_visibility`. Enable Railway volume backups on the Postgres service, or dump both databases with `pg_dump` over the private network (or a temporary TCP proxy). Restore both databases together.

## Cost and plan

At idle the five services use about 0.2 GB of RAM together (Temporal and Postgres about 0.1 GB each). The Hobby plan is enough for development and small workloads. Memory and Postgres load grow with the number of running workflows, timers and workers.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| The browser keeps asking for the login | Wrong user or password. Read `AUTH_USERNAME` and `AUTH_PASSWORD` on the Gateway |
| Temporal logs `waiting for Admin Tools to finish the schema setup` and never starts | Admin Tools isn't running or failed. Check its logs; it needs Postgres. It must stay deployed |
| A few `Not enough hosts to serve the request` errors right after start | Normal while the server's internal services join each other; they stop within seconds |
| `Not using any authorizer` warning | Expected: this template has no gRPC authorizer. Keep the frontend private |
| Workers can't connect | Use `${{Temporal.RAILWAY_PRIVATE_DOMAIN}}:7233` from a service in the same project and environment, plain gRPC (no TLS) |
| UI actions (Terminate, Cancel, Signal) fail after adding a custom domain | Set `TEMPORAL_CORS_ORIGINS` on the UI to the new URL and redeploy the UI |
| `Namespace default is not found` in a worker | Admin Tools creates it after the server is healthy; wait a minute, or create it with the CLI |
| 502 from the Gateway right after deploy | The UI is still starting. Wait a moment |

## License

Temporal server, admin tools and UI are MIT. Caddy is Apache 2.0. PostgreSQL uses the PostgreSQL License.

## Testing

Tested on 2026-11-09 in throwaway Railway projects deployed from the template: all five services were up about 30 seconds after deploy. Admin Tools created both schemas (history to 1.19, visibility to 1.14) and the `default` namespace, and `temporal operator namespace list` against the private frontend listed it. Through the Gateway: 401 without a login and with a wrong password; with the login the UI pages loaded, the API listed the `default` namespace, and a workflow was started and terminated through the UI's API (both write calls succeeded). After redeploying all five services at once, the schema was found current, the namespace still existed, and everything was up again. Not tested: real SDK workers, a TCP proxy from outside Railway, mTLS, custom domains and upgrades between Temporal versions.
