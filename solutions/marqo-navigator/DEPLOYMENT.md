# Creating the Railway Template

Step-by-step build of the four-service template in Railway's template composer.

**Order matters.** Cross-service variables like `${{Marqo.RAILWAY_PRIVATE_DOMAIN}}` only resolve once the referenced service exists, so create the services in the order below.

**Service names matter.** `Marqo` and `Navigator` are referenced by other services — type them exactly as written. The two Caddy services are referenced by nothing, so their names are cosmetic.

---

## Step 0 — Push the code first

Railway builds from GitHub, so the repository must contain this solution before you start.

```bash
cd /Users/nin/Own/source/nick0lay/railway-templates
git add solutions/marqo-navigator README.md
git commit -m "Add Marqo + Navigator Railway template"
git push origin main
```

Verify these paths exist on GitHub before continuing — Railway will fail the build if they don't:

- `solutions/marqo-navigator/marqo/Dockerfile`
- `solutions/marqo-navigator/marqo/railway-entrypoint.sh`
- `solutions/marqo-navigator/navigator/Dockerfile`

If the repository is private, connect the GitHub account to Railway first (**Account Settings → GitHub**) and grant access to `nick0lay/railway-templates`.

---

## Step 1 — Open the template composer

1. Go to your **Workspace → Templates** page
2. Click **New Template**

You now have an empty canvas. Add each service with **Add New** (top right) or **⌘K → + New Service**.

---

## Step 2 — Marqo service

Create this one first — two other services reference it.

| Setting | Value |
|---------|-------|
| **Service name** | `Marqo` |
| **Source** | GitHub repo → `https://github.com/nick0lay/railway-templates` |
| **Root Directory** | `solutions/marqo-navigator/marqo` |
| **Public Networking** | **None** — do not add a domain |

### Variables

| Variable | Value |
|----------|-------|
| `MARQO_IMAGE_TAG` | `latest` |
| `MARQO_MODELS_TO_PRELOAD` | `["hf/e5-base-v2"]` |
| `MARQO_ENABLE_THROTTLING` | `TRUE` |
| `LOG_LEVEL` | `WARN` |
| `PORT` | `8882` |

`PORT` is set explicitly because Marqo ignores Railway's injected value and binds 8882 unconditionally. Setting it keeps Railway's healthcheck pointed at the right port.

> See [Image Tags](./README.md#image-tags) before shipping. Marqo inverts the usual convention — `latest` is 2.16.1 from March 2025, not the newest build. Use `cloud-latest` for the current release.

### Volume

Right-click the service → **Attach Volume**:

| Setting | Value |
|---------|-------|
| **Mount path** | `/opt/vespa/var` |

This volume is **required**. Without it every redeploy starts from an empty index and re-downloads ~420 MB of model weights. Size it with room to spare — Vespa blocks all writes above 75% utilisation.

### Healthcheck

| Setting | Value |
|---------|-------|
| **Healthcheck Path** | `/health` |
| **Healthcheck Timeout** | `600` seconds |

The generous timeout covers first boot, where Vespa converges *and* the embedding model downloads before the service can serve. Too short a timeout produces a restart loop that looks like a crash.

---

## Step 3 — Navigator service

| Setting | Value |
|---------|-------|
| **Service name** | `Navigator` |
| **Source** | GitHub repo → `https://github.com/nick0lay/railway-templates` |
| **Root Directory** | `solutions/marqo-navigator/navigator` |
| **Public Networking** | **None** — do not add a domain |

### Variables

| Variable | Value |
|----------|-------|
| `MARQO_API_URL` | `http://${{Marqo.RAILWAY_PRIVATE_DOMAIN}}:8882` |
| `NAVIGATOR_IMAGE_TAG` | `v0.1.19` |
| `PORT` | `9882` |

The port in `MARQO_API_URL` is **not optional** — Navigator needs a full URL, and a bare hostname leaves every panel empty. Navigator also hardcodes 9882, hence the explicit `PORT`.

No volume. No healthcheck path needed — it serves static files and comes up immediately.

---

## Step 4 — Caddy-UI service

The public front door for the dashboard.

| Setting | Value |
|---------|-------|
| **Service name** | `Caddy-UI` |
| **Source** | GitHub repo → `https://github.com/iliab1/caddy-password-auth` |
| **Root Directory** | *(leave empty)* |
| **Public Networking** | **HTTP domain** |

### Variables

| Variable | Value |
|----------|-------|
| `ORIGIN` | `http://${{Navigator.RAILWAY_PRIVATE_DOMAIN}}:9882` |
| `BASIC_AUTH` | `admin:${{secret(32)}}` |
| `PORT` | `8080` |

When Railway asks for the domain's **target port**, enter `8080` to match.

Setting `PORT` explicitly is worth the extra field. Caddy's entrypoint substitutes it into its config as `:${PORT}`, so what you set is exactly what Caddy listens on. Left unset it falls back to Railway's injected value or `80`, and you would have to read the deploy logs to know which to enter as the target port.

---

## Step 5 — Caddy-API service

The public front door for the REST API and its Swagger page.

| Setting | Value |
|---------|-------|
| **Service name** | `Caddy-API` |
| **Source** | GitHub repo → `https://github.com/iliab1/caddy-password-auth` |
| **Root Directory** | *(leave empty)* |
| **Public Networking** | **HTTP domain** |

### Variables

| Variable | Value |
|----------|-------|
| `ORIGIN` | `http://${{Marqo.RAILWAY_PRIVATE_DOMAIN}}:8882` |
| `BASIC_AUTH` | `admin:${{secret(32)}}` |
| `PORT` | `8080` |

Target port `8080` again. These are separate containers, so both Caddy services using `8080` is fine.

**Use a separate `${{secret(32)}}` from Caddy-UI.** Each call generates a distinct value, so simply entering the function twice is enough. This credential grants `DELETE /indexes/{name}` and `DELETE /models` — giving someone dashboard access should not also grant them the ability to destroy every index.

---

## Public Networking Summary

Only the two Caddy services get public networking. This is a security boundary, not a preference — Marqo has no authentication of its own, and its API can delete every index.

| Service | Public Networking | Target Port | Why |
|---------|-------------------|-------------|-----|
| `Marqo` | **None** | — | No auth of its own. A domain here bypasses Caddy entirely |
| `Navigator` | **None** | — | No auth of its own, and exposes destructive index operations |
| `Caddy-UI` | **HTTP domain** | `8080` | Password-protected front door for the dashboard |
| `Caddy-API` | **HTTP domain** | `8080` | Password-protected front door for the API and Swagger |

To add a domain: select the service → **Settings → Networking → Public Networking → Generate Domain**, then enter `8080` as the target port.

Use **Generate Domain** (HTTP), never **TCP Proxy**. TCP Proxy is raw passthrough with no TLS, and HTTP basic auth is base64-encoded rather than encrypted — over a TCP proxy the passwords would cross the internet in the clear. HTTP domains get automatic HTTPS, which is what makes basic auth safe here. Everything this template serves is HTTP.

Both Caddy services can use `8080` because they are separate containers.

Private networking needs no configuration at all. Railway gives every service a `*.railway.internal` hostname automatically; the reference variables in Steps 3–5 resolve to those.

### One caveat on private networking

Railway's private DNS behaviour depends on when the **environment** was created:

- **Created after 16 October 2025** — resolves to both IPv4 and IPv6. Everything here works as documented.
- **Created before that** — resolves to **IPv6 only**.

That matters because Marqo binds `0.0.0.0:8882` (IPv4 only) and never opens an IPv6 listener — verified by inspecting its sockets. On a legacy IPv6-only environment, both `Caddy-API → Marqo` and `Navigator → Marqo` fail with 502 even though every variable is correct. Navigator itself binds `::` and is unaffected.

Deploying the template creates a fresh project and environment, so this does not affect normal use. It only bites when adding these services to a Railway project created before October 2025. If that is your situation, create a new environment rather than debugging the 502.

---

## Step 6 — Review the graph

Before publishing, confirm the topology:

```
Caddy-UI  (domain) ──> Navigator (no domain) ──┐
                                                ├──> Marqo (no domain, volume)
Caddy-API (domain) ─────────────────────────────┘
```

Checklist:

- [ ] Exactly **two** services have public domains: `Caddy-UI` and `Caddy-API`
- [ ] `Marqo` and `Navigator` have **no** domain
- [ ] `Marqo` has a volume at `/opt/vespa/var`
- [ ] Three reference variables resolve to service names, not literal text
- [ ] The two `BASIC_AUTH` values differ

If Marqo or Navigator has a public domain, the auth gateways are bypassable and the template is unsafe to publish — Marqo has no authentication of its own.

---

## Step 7 — Publish

1. Fill in template metadata — name, description, and README from [`TEMPLATE.md`](./TEMPLATE.md)
2. Suggested name: **Marqo + Navigator**
3. Click **Publish**

Railway gives you a deploy URL like `https://railway.com/deploy/<slug>` — for this template, `ukdruK`.

---

## Step 8 — Deploy it once and verify

Publishing does not prove it works. Deploy your own template before sharing it.

**First deploy is slow** — several minutes while Vespa converges and the model downloads. Watch Marqo's deploy logs; `[railway-entrypoint] empty volume — seeding Vespa directory skeleton` on first boot is expected.

Read both passwords from **Caddy-UI → Variables → `BASIC_AUTH`** and the same on **Caddy-API**.

```bash
UI_URL="https://your-caddy-ui.up.railway.app"
API_URL="https://your-caddy-api.up.railway.app"
API_PASS="<from Caddy-API BASIC_AUTH>"

# 1. Auth is enforced
curl -so /dev/null -w '%{http_code}\n' "$API_URL/health"          # expect 401
curl -so /dev/null -w '%{http_code}\n' "$UI_URL/"                 # expect 401

# 2. Marqo is healthy
curl -u "admin:$API_PASS" "$API_URL/health"                       # expect status green

# 3. Index and search end to end
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
# Top hit must be Down Winter Jacket — no shared keywords with the query
```

Then in a browser:

- Open `$UI_URL`, sign in with the **UI** password, confirm the dashboard lists the `products` index
- Open `$API_URL/docs`, sign in with the **API** password, confirm Swagger renders and **Try it out** works
- Confirm the UI password is **rejected** on `$API_URL` and vice versa

Finally, redeploy Marqo from the Railway dashboard and confirm the index survives and the model is not re-downloaded.

---

## Step 9 — Record the deploy link

**Done.** The template is published at:

```
https://railway.com/deploy/ukdruK?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic
```

The deploy button is in place in the repository root [`README.md`](../../README.md) Solutions table and under the heading in [`README.md`](./README.md).

If the template is ever republished under a new slug, update both locations.

---

## Troubleshooting Template Creation

### Build fails: Dockerfile not found

The **Root Directory** is wrong. It must be `solutions/marqo-navigator/marqo` — the directory holding the Dockerfile, not the solution folder and not the repository root.

### Reference variable shows as literal text

The referenced service does not exist yet or is named differently. `${{Marqo.RAILWAY_PRIVATE_DOMAIN}}` requires a service named exactly `Marqo`. Rename the service and re-enter the variable.

### 502 from a Caddy service

`ORIGIN` is missing its port. `http://marqo.railway.internal` fails; `http://marqo.railway.internal:8882` works.

### Marqo restart-loops on first deploy

The healthcheck timeout is too short for the initial model download. Raise it to 600s, or remove the healthcheck path entirely for the first deploy and add it back afterwards.

### Navigator crashes with "Missing parameter name at 1"

The service is running the upstream image rather than this repository's Dockerfile. Confirm **Root Directory** is `solutions/marqo-navigator/navigator`.

### UI loads but every panel is empty

`MARQO_API_URL` is wrong or Marqo is not healthy yet. Navigator proxies server-side, so check its deploy logs rather than the browser console.

---

## Note on `docker-compose.yml`

The compose file and `.env.example` are local development only — Railway ignores both. They exist so the stack can be exercised before touching the dashboard, and they build from the same Dockerfiles with the same volume layout. Run `docker compose up -d --build` from the solution directory to reproduce the deployed topology on your machine.
