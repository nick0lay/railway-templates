# Creating the Railway Template

Seven services. Follow the order below — Railway reference variables like
`${{vespa-admin.RAILWAY_PRIVATE_DOMAIN}}` only resolve once the service they
name exists.

**Service names are load-bearing.** `vespa-admin`, `vespa-node`, `Marqo` and
`Navigator` are referenced by other services; type them exactly. The two Caddy
services are referenced by nothing, so their names are cosmetic.

```
Internet ─> caddy-ui  (domain) ─> navigator ─┐
Internet ─> caddy-api (domain) ─> marqo    <─┘
                                     │  external vector store
                        ┌────────────┴────────────┐
                   vespa-admin               vespa-node
              config server, ZooKeeper,   query container +
              log server, cluster ctrl    content node (proton)
```

## Why seven services

Railway caps each container at **1000 threads (PIDs)**. Marqo bundles a full
Vespa cluster, and that combination peaks at ~1010 threads — it cannot start,
and no amount of configuration fixes it. Splitting Vespa's admin role from its
query/content role gives each side its own budget:

| Service | Threads (measured) |
|---------|--------------------|
| `vespa-admin` | ~600 / 1000 |
| `vespa-node` | ~570 / 1000 |
| `marqo` | ~34 / 1000 |

`docker-compose.yml` reproduces these caps locally, so anything that runs there
should deploy here.

**Verified on Railway.** The topology below has been deployed and exercised end
to end: cluster converged, index created, documents embedded, semantic search
returning correct results through the authenticated gateway, and data surviving
a redeploy.

**Thread budget.** Vespa sizes its jdisc thread pools from the host's core
count, and Railway hosts report 48. Untuned that put `vespa-admin` at 996/1000
and `vespa-node` at 957/1000 — a few threads from the ceiling, at which point a
container cannot fork and the config server stops answering.

Two settings fix it, and both are in this guide:

| | untuned | tuned |
|---|---|---|
| `vespa-admin` | 996 | **497** |
| `vespa-node` | 957 | **430** |

**Both are automatic — there is nothing to configure.** The Vespa image
defaults `VESPA_CONFIGSERVER_JVMARGS` and `VESPA_CONFIGPROXY_JVMARGS`, and
`vespa-init` puts the matching cap in `<container><nodes><jvm>`, which is the
one element Marqo's bootstrap preserves. `vespa-init` also *repairs* a cluster
deployed before this existed: it clones the active application, patches
`services.xml` and reactivates, keeping Marqo's bundle and schemas intact.
Override `VESPA_JVM_PROCESSOR_COUNT` (default 4) to tune.

**One manual step, and only on the repair path:** restart `vespa-node` after
`vespa-init` logs `repaired`. Vespa accepts the new JVM options but does not
recycle a running container JVM to apply them, so the count stays high until it
restarts (measured 924 before, 432 after). Fresh deployments never hit this —
the JVM starts with the cap already set.

Note the local harness reproduces Railway's PID cap but not its core count, so
compose under-measures: treat it as a smoke test, not proof of headroom.

**Concurrency is limited by Marqo, not by Vespa's threads.** Marqo's own default
is 8 concurrent requests per type, so it returns 429 from roughly 10 concurrent
callers while Vespa's pools sit idle. This template sets both limits to 32:

| Load test (200 requests, concurrency 10) | limit 8 | limit 32 |
|---|---|---|
| Succeeded | 160 | **200** |
| 429s | 40 | **0** |
| Vespa-node threads | 432 | **432** (unchanged) |

Raising Vespa's thread budget would not have helped — it was never the
constraint. Note that more concurrency buys fewer rejections, not more
throughput: measured throughput stayed at 14–15 req/s across both settings while
p50 latency rose from 0.47s to 0.90s, because the real limit is CPU for
embedding inference. When p99 climbs without throughput rising, the answer is a
larger Marqo service rather than higher limits.

These variables need a **redeploy** to take effect, not just a variable change —
Marqo keeps reporting the old limit until it restarts.

---

## Step 0 — Push the code

Railway builds from GitHub, so these paths must exist on `main` first:

- `solutions/marqo-navigator/vespa/Dockerfile`
- `solutions/marqo-navigator/vespa-init/` (Dockerfile, `deploy-app.sh`, `app/`)
- `solutions/marqo-navigator/marqo/Dockerfile`
- `solutions/marqo-navigator/navigator/Dockerfile`

## Step 1 — Open the template composer

**Workspace → Templates → New Template**, then add services with **Add New**.

### Two settings that silently break the deploy

**Every service is a GitHub repo source, not a Docker image.** That includes the
Caddy services — `iliab1/caddy-password-auth` is a *repository*; no image by
that name exists. Choosing "Docker Image" produces a service that fails before
the build starts, with no build logs to explain why.

**Root Directory is mandatory** on every service built from this repo. Without
it Railway analyses the repository root, finds no Dockerfile, and fails with
"Railpack could not determine how to build the app."

---

## Step 2 — `vespa-admin`

Create this first: four other services reference it.

| Setting | Value |
|---------|-------|
| Service name | `vespa-admin` |
| Source | GitHub repo → `https://github.com/nick0lay/railway-templates` |
| Root Directory | `solutions/marqo-navigator/vespa` |
| Custom Start Command | **leave empty** |
| Public Networking | **None** |

### Variables

| Variable | Value |
|----------|-------|
| `VESPA_ROLE` | `configserver,services` |
| `VESPA_CONFIGSERVERS` | `${{vespa-admin.RAILWAY_PRIVATE_DOMAIN}}` |
| `VESPA_HOSTNAME` | `${{vespa-admin.RAILWAY_PRIVATE_DOMAIN}}` |
| `VESPA_IMAGE_TAG` | `8.431.32` |
| `PORT` | `19071` |

`VESPA_HOSTNAME` is what makes this work on Railway at all. Vespa matches each
node against the hostname it reports for itself, and Railway does not let you
set container hostnames — so we tell Vespa what to call itself, and `vespa-init`
writes the same value into `hosts.xml`. Get these two out of sync and the
cluster never converges.

`PORT` is informational here — Vespa binds its own ports regardless, and this
service has no healthcheck and no domain.

**Do not set a Custom Start Command.** The Vespa image takes its role as an
argument to its entrypoint, and Railway's start command *replaces* the
entrypoint rather than passing arguments to it — set it to `services` and the
container dies with "The executable `services` could not be found". The role is
therefore a variable, `VESPA_ROLE`, read by this template's entrypoint wrapper.
Note there is no space after the comma in `configserver,services`; the upstream
script accepts exactly one argument.

### Volume

| Mount path | `/opt/vespa/var` |
|---|---|

Holds cluster configuration and ZooKeeper state. **Required** — without it every
redeploy loses the deployed application and the cluster bootstraps from nothing.

### Healthcheck

**Leave the healthcheck path empty.** Railway's healthcheck could not reach
Vespa's config server on 19071 within its retry window and failed the deploy
outright — `1/1 replicas never became healthy`. Vespa logs to a file rather than
stdout, so this presents as a container that produced no output at all. The
service is fine without one; `vespa-init` waits for real convergence before
Marqo starts, which is the ordering that actually matters.

Also turn **off** "Sleep when idle" (`serverless`). Vespa is a stateful cluster;
suspending it when idle is not something it recovers from cleanly.

---

## Step 3 — `vespa-node`

| Setting | Value |
|---------|-------|
| Service name | `vespa-node` |
| Source | GitHub repo → `https://github.com/nick0lay/railway-templates` |
| Root Directory | `solutions/marqo-navigator/vespa` (same as vespa-admin) |
| Custom Start Command | **leave empty** |
| Public Networking | **None** |

### Variables

| Variable | Value |
|----------|-------|
| `VESPA_ROLE` | `services` |
| `VESPA_CONFIGSERVERS` | `${{vespa-admin.RAILWAY_PRIVATE_DOMAIN}}` |
| `VESPA_HOSTNAME` | `${{vespa-node.RAILWAY_PRIVATE_DOMAIN}}` |
| `VESPA_IMAGE_TAG` | `8.431.32` |
| `PORT` | `8080` |

Note the asymmetry: `VESPA_CONFIGSERVERS` points at **admin** on both services,
while `VESPA_HOSTNAME` is each service's *own* domain.

### Volume

| Mount path | `/opt/vespa/var` |
|---|---|

This is where documents and vectors live. **Required, and easy to miss.**

Without it `/opt/vespa/var` lands on the container's ephemeral overlay and every
redeploy silently loses your data — the index still exists (its definition lives
in the config server on `vespa-admin`), but `/indexes/<name>/stats` reports
0 documents. Nothing errors. Confirm with
`railway ssh --service vespa-node "df -h /opt/vespa/var"`: a real volume shows a
`/dev/...` device, ephemeral storage shows `overlay`.

### Healthcheck

Leave empty, and turn off "Sleep when idle" — same reasons as `vespa-admin`.

---

## Step 4 — `vespa-init`

One-shot bootstrap that deploys the cluster topology.

| Setting | Value |
|---------|-------|
| Service name | `vespa-init` |
| Source | GitHub repo → `https://github.com/nick0lay/railway-templates` |
| Root Directory | `solutions/marqo-navigator/vespa-init` |
| Public Networking | **None** |
| Volume | none |

### Variables

| Variable | Value |
|----------|-------|
| `VESPA_CONFIG_URL` | `http://${{vespa-admin.RAILWAY_PRIVATE_DOMAIN}}:19071` |
| `VESPA_QUERY_URL` | `http://${{vespa-node.RAILWAY_PRIVATE_DOMAIN}}:8080` |
| `VESPA_ADMIN_HOST` | `${{vespa-admin.RAILWAY_PRIVATE_DOMAIN}}` |
| `VESPA_NODE_HOST` | `${{vespa-node.RAILWAY_PRIVATE_DOMAIN}}` |

`VESPA_ADMIN_HOST` and `VESPA_NODE_HOST` must be **identical** to the
`VESPA_HOSTNAME` values on the two Vespa services — they are substituted into
`hosts.xml`, which Vespa matches against what each node reports.

**This service exits when it finishes, and Railway will restart it.** That is
expected and harmless: `deploy-app.sh` checks whether an application is already
deployed and exits immediately if so. It must behave this way — once Marqo
starts it rewrites the application package (adding its `marqo-custom-searchers`
bundle), and redeploying the base package over that fails.

---

## Step 5 — `Marqo`

| Setting | Value |
|---------|-------|
| Service name | `Marqo` |
| Source | GitHub repo → `https://github.com/nick0lay/railway-templates` |
| Root Directory | `solutions/marqo-navigator/marqo` |
| Public Networking | **None** |

### Variables

| Variable | Value |
|----------|-------|
| `VESPA_CONFIG_URL` | `http://${{vespa-admin.RAILWAY_PRIVATE_DOMAIN}}:19071` |
| `VESPA_QUERY_URL` | `http://${{vespa-node.RAILWAY_PRIVATE_DOMAIN}}:8080` |
| `VESPA_DOCUMENT_URL` | `http://${{vespa-node.RAILWAY_PRIVATE_DOMAIN}}:8080` |
| `ZOOKEEPER_HOSTS` | `${{vespa-admin.RAILWAY_PRIVATE_DOMAIN}}:2181` |
| `MARQO_MODELS_TO_PRELOAD` | `["hf/e5-base-v2"]` |
| `MARQO_ENABLE_THROTTLING` | `TRUE` |
| `MARQO_MAX_CONCURRENT_SEARCH` | `32` |
| `MARQO_MAX_CONCURRENT_INDEX` | `32` |
| `MARQO_IMAGE_TAG` | `latest` |
| `PORT` | `8882` |

All four Vespa/ZooKeeper variables must be set together — Marqo treats a partial
external configuration as a fatal error. With all four present it skips starting
its own Vespa, which is the whole point.

> See [Image Tags](./README.md#image-tags) before shipping. Marqo inverts the
> usual convention: `latest` is 2.16.1 from March 2025, not the newest build.

### Volume

| Mount path | `/root/.cache/huggingface` |
|---|---|

Embedding model weights (~420 MB). Not baked into the image — without this
volume they re-download on every deploy, delaying startup.

### Healthcheck

Leave the healthcheck path **empty**. Marqo cannot start until the Vespa cluster
is serving, and Railway has no service ordering, so it will crash-loop on a cold
deploy until `vespa-init` finishes. That is self-healing; a healthcheck just
turns it into a red deployment.

---

## Step 6 — `Navigator`

| Setting | Value |
|---------|-------|
| Service name | `Navigator` |
| Source | GitHub repo → `https://github.com/nick0lay/railway-templates` |
| Root Directory | `solutions/marqo-navigator/navigator` |
| Public Networking | **None** |

### Variables

| Variable | Value |
|----------|-------|
| `MARQO_API_URL` | `http://${{Marqo.RAILWAY_PRIVATE_DOMAIN}}:8882` |
| `NAVIGATOR_IMAGE_TAG` | `v0.1.19` |
| `PORT` | `9882` |

The port in `MARQO_API_URL` is **not optional** — a bare hostname leaves every
panel in the UI empty.

---

## Step 7 — `Caddy-UI`

| Setting | Value |
|---------|-------|
| Service name | `Caddy-UI` |
| Source | GitHub repo → `https://github.com/iliab1/caddy-password-auth` |
| Root Directory | *(empty)* |
| Public Networking | **HTTP domain, target port `8080`** |

| Variable | Value |
|----------|-------|
| `ORIGIN` | `http://${{Navigator.RAILWAY_PRIVATE_DOMAIN}}:9882` |
| `BASIC_AUTH` | `admin:${{secret(32)}}` |
| `PORT` | `8080` |

---

## Step 8 — `Caddy-API`

| Setting | Value |
|---------|-------|
| Service name | `Caddy-API` |
| Source | GitHub repo → `https://github.com/iliab1/caddy-password-auth` |
| Root Directory | *(empty)* |
| Public Networking | **HTTP domain, target port `8080`** |

| Variable | Value |
|----------|-------|
| `ORIGIN` | `http://${{Marqo.RAILWAY_PRIVATE_DOMAIN}}:8882` |
| `BASIC_AUTH` | `admin:${{secret(32)}}` |
| `PORT` | `8080` |

**Use a separate `${{secret(32)}}` from Caddy-UI** — entering the function twice
generates two different values. This credential grants `DELETE /indexes/{name}`
and `DELETE /models`; dashboard access should not also grant destruction rights.

Use **Generate Domain** (HTTP), never **TCP Proxy**: basic auth is base64-encoded
rather than encrypted, so it needs the automatic HTTPS an HTTP domain provides.

---

## Step 9 — Review before publishing

- [ ] Exactly **two** services have public domains: `Caddy-UI` and `Caddy-API`
- [ ] `vespa-admin`, `vespa-node`, `Marqo`, `Navigator`, `vespa-init` have **none**
- [ ] Three volumes: `vespa-admin` and `vespa-node` at `/opt/vespa/var`, `Marqo` at `/root/.cache/huggingface`
- [ ] `VESPA_HOSTNAME` on each Vespa service is its **own** private domain
- [ ] `VESPA_ADMIN_HOST` / `VESPA_NODE_HOST` on `vespa-init` match those exactly
- [ ] `VESPA_CONFIGSERVERS` points at **vespa-admin** on both Vespa services
- [ ] The two `BASIC_AUTH` values differ

If `Marqo` or `Navigator` has a public domain, the auth gateways are bypassable
and the template is unsafe to publish — Marqo has no authentication of its own.

## Step 10 — First deploy

Expect a messy first few minutes. Railway starts everything at once, so:

1. `vespa-admin` comes up (~1 min)
2. `vespa-node` retries until the config server answers
3. `vespa-init` deploys the topology, waits for convergence, exits
4. `Marqo` crash-loops until the cluster serves, then downloads ~420 MB of model weights

Watch `vespa-init` logs for `[vespa-init] cluster ready`. Marqo settling after
that is normal.

## Step 11 — Verify

```bash
API_URL="https://your-caddy-api.up.railway.app"
API_PASS="<from Caddy-API BASIC_AUTH>"

curl -so /dev/null -w '%{http_code}\n' "$API_URL/health"          # 401
curl -u "admin:$API_PASS" "$API_URL/health"                       # status green

curl -u "admin:$API_PASS" -X POST "$API_URL/indexes/products" \
  -H 'Content-Type: application/json' \
  -d '{"type":"unstructured","model":"hf/e5-base-v2"}'

curl -u "admin:$API_PASS" -X POST "$API_URL/indexes/products/documents" \
  -H 'Content-Type: application/json' \
  -d '{"documents":[
        {"_id":"1","title":"Down Winter Jacket","description":"800 fill goose down parka rated to minus 20 celsius"},
        {"_id":"2","title":"Espresso Machine","description":"15-bar pump coffee maker with milk frother"}
      ],"tensorFields":["title","description"]}'

curl -u "admin:$API_PASS" -X POST "$API_URL/indexes/products/search" \
  -H 'Content-Type: application/json' \
  -d '{"q":"something to keep me warm in the snow"}'
# Top hit must be Down Winter Jacket
```

Then in a browser: the UI URL with the **UI** password, `$API_URL/docs` with the
**API** password, and confirm each password is rejected by the other gateway.

Finally redeploy `Marqo` and confirm the index survives.

---

## Troubleshooting

### Cluster never converges / `vespa-init` times out

`VESPA_HOSTNAME` does not match what `vespa-init` wrote into `hosts.xml`. Check
all four values (`VESPA_HOSTNAME` × 2, `VESPA_ADMIN_HOST`, `VESPA_NODE_HOST`)
are the two private domains and nothing else.

### `vespa-init` keeps restarting

Expected. It exits after finishing and Railway restarts it; the guard makes each
restart a no-op. Confirm the logs say `application already deployed`.

### `vespa-init` fails after the cluster has been running

It is trying to redeploy the base package over the one Marqo rewrote. The guard
should prevent this — if it does not, the config server was unreachable when the
guard ran.

### Marqo: `VespaNotConvergedError` / `did not converge within 120 seconds`

Marqo started before the cluster was ready. Self-heals on restart. If it
persists, the cluster genuinely is not converging — see the first entry.

### Marqo starts its own Vespa (thread exhaustion returns)

One of the four external-store variables is missing. Marqo needs
`VESPA_CONFIG_URL`, `VESPA_QUERY_URL`, `VESPA_DOCUMENT_URL` **and**
`ZOOKEEPER_HOSTS`; with a partial set it errors, with none it starts its own.

### 502 from a Caddy service

`ORIGIN` is missing its port. `http://marqo.railway.internal` fails;
`http://marqo.railway.internal:8882` works.

### `1/1 replicas never became healthy` on a Vespa service

A healthcheck path is set. Remove it — Railway cannot reach Vespa's config
server on 19071 inside the retry window, and the deploy fails even though the
container is running correctly. Verified: `vespa-node` without a healthcheck
deployed successfully while `vespa-admin` with one failed on identical config.

### "The executable `services` could not be found"

A Custom Start Command is set on a Vespa service. Clear it and set `VESPA_ROLE`
instead — Railway's start command replaces the image entrypoint, so Vespa's role
argument has to arrive as a variable. A variant of this, "The executable
`configserver,` could not be found", means the value was typed with a space
after the comma.

### Index creation returns 500, but search still works

Marqo fails in `_get_convergence_status` with `httpx.ReadTimeout`. Searches keep
working because they go to `vespa-node`, while index creation needs the config
server on `vespa-admin` — so it looks like a partial outage rather than a
resource limit.

`vespa-admin` has hit the 1000-PID ceiling. A container at the ceiling cannot
fork at all: `railway ssh` fails with
`crun: fork: Resource temporarily unavailable`. Redeploy it, and if it recurs,
lower `VESPA_CPU_LIMIT` or move to a plan with a higher PID cap.

### Index exists but reports 0 documents

`vespa-node` is missing its volume — see Step 3.

### `pthread_create failed (EAGAIN)` anywhere

A container hit Railway's 1000-PID ceiling. Check the service is running the
role it should be — most likely `vespa-node` has `VESPA_ROLE=configserver,services`
instead of `services`, so it is running both roles in one container.

---

## Note on `docker-compose.yml`

Local development only; Railway ignores it. It builds from the same Dockerfiles,
uses the same application package, and sets `pids_limit: 1000` on every
container to reproduce Railway's ceiling. Run `docker compose up -d --build`
from the solution directory to exercise the deployed topology locally.
