# Deploy and Host Dgraph 25.5 on Railway

Dgraph is an open-source, distributed graph database with a native GraphQL API and its own query language, DQL. You store data as nodes and edges, and query it with GraphQL or DQL. Use it for knowledge graphs, AI agent memory, recommendations, social and identity graphs, and GraphQL backends. This template runs Dgraph 25.5 as a production-style single node: Zero, Alpha and the Ratel UI, with a login on everything.

## About Hosting Dgraph 25.5

A Dgraph cluster has two parts. Zero coordinates the cluster, and Alpha stores the data and serves the APIs. Both need their own persistent volume. Alpha's HTTP port answers queries, mutations and schema changes, and by default it does so for anyone who can reach it. It also serves debug and metrics pages without any login. Most Dgraph templates either run the all-in-one development image or expose Alpha with no authentication.

Since version 25, Dgraph's access control (ACL) is open source. This template turns it on, with `--security anonymous=none`. Every query, mutation and admin call then needs a login token. The admin user `groot` gets a generated password on the first start. Dgraph's default password is never reachable from the internet, because Alpha listens on localhost only until the password is replaced. A Caddy gateway is the only public service. It passes the Dgraph API through to Alpha and keeps Alpha's debug pages private. It also serves the Ratel UI behind a second, browser login.

## Common Use Cases

- GraphQL backend: upload a GraphQL schema and get queries, mutations and search without writing resolvers
- Knowledge graphs, GraphRAG backends and long-term memory for AI agents
- Recommendations, social graphs, fraud and identity graphs, and dependency maps
- Learning DQL and GraphQL with Ratel, or a Dgraph development and staging database next to your app

## Dependencies for Dgraph 25.5 Hosting

- Dgraph v25.5.1 (official `dgraph/dgraph` image), Zero and Alpha
- Ratel v25.3.0 (official `dgraph/ratel` image)
- Caddy 2.11.9 (official `caddy` image) as the gateway

### Deployment Dependencies

- Dgraph: https://dgraph.io/
- Dgraph on GitHub: https://github.com/dgraph-io/dgraph
- Dgraph docs: https://docs.dgraph.io/
- Access control (ACL): https://docs.dgraph.io/admin/admin-tasks/user-management-access-control/
- Ratel: https://github.com/dgraph-io/ratel

### Implementation Details

**What you set:** nothing. Passwords and the token signing key are generated.

**After deploy:**

1. Open `RATEL_URL` from the Gateway service's Variables. Log in with `AUTH_USERNAME` / `AUTH_PASSWORD` (Gateway). In Ratel's connection dialog, open "ACL Account" and log in as `groot` with `DGRAPH_PASSWORD` (Alpha service).
2. From code, log in first, then send the token with every request:

```bash
TOKEN=$(curl -s https://<gateway-domain>/login \
  -d '{"userid":"groot","password":"<DGRAPH_PASSWORD>"}' | jq -r .data.accessJWT)

curl https://<gateway-domain>/query -H "X-Dgraph-AccessToken: $TOKEN" \
  -H "Content-Type: application/dql" -d '{ q(func: has(name)) { name } }'
```

GraphQL works the same way at `GRAPHQL_URL` with the `X-Dgraph-AccessToken` header. Tokens last 6 hours (`ACL_ACCESS_TTL`); refresh them with the refresh token from `/login`.

3. From another service in this project, use `${{Alpha.HTTP_URL}}` (HTTP) or `${{Alpha.GRPC_ADDR}}` (gRPC for dgo, pydgraph and dgraph-js) with `${{Alpha.DGRAPH_USER}}` and `${{Alpha.DGRAPH_PASSWORD}}`.

**This template:**

- Runs Zero and Alpha as two services, each with its own volume, so your graph survives redeploys
- Turns on Dgraph ACL with `anonymous=none`: calls without a token are refused, including GraphQL and schema changes
- Generates the `groot` password and the token signing key; the default password never faces the internet
- Puts a Caddy gateway in front: only the Dgraph API is forwarded, so `/debug/pprof`, `/debug/vars` and `/metrics` stay private
- Serves Ratel at `/ratel/` behind a browser login, already pointed at your Dgraph
- Pins every image: Dgraph v25.5.1, Ratel v25.3.0, Caddy 2.11.9
- Sets Alpha's cache to 512 MB (Dgraph's default is 4 GB) so it fits the Hobby plan
- Turns off Dgraph's anonymous telemetry, and Zero's unauthenticated admin pages

**Notes:** the `groot` password is set on the first start. To change it later, run the `updateUser` mutation on `/admin` as groot, then update `DGRAPH_PASSWORD`. gRPC (port 9080) is private only: Railway's TCP proxy adds no TLS, so it would send your password in plain text. Use HTTPS from outside Railway. The stack idles at about 0.6 GB of RAM (Alpha 0.4, Zero 0.13, Ratel and Caddy under 0.05 each). This is one Zero and one Alpha; for high availability Dgraph needs three of each.

## Why Deploy Dgraph 25.5 on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Dgraph 25.5 on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
