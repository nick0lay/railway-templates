# Marqo + Navigator (Protected)

Deploy Marqo vector search with the Navigator admin UI, both behind Caddy password authentication.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/ukdruK?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Overview

Marqo is an AI-native search platform aimed at online retail — product search and discovery for fashion, beauty, electronics, and home goods — and equally usable as a general-purpose vector search engine. It ships purpose-built [ecommerce and fashion embedding models](#embedding-models) that load into this deployment by name.

This template deploys a seven-service stack:

- **Vespa (×2)**: the vector store, split into an admin role (config server, ZooKeeper, log server, cluster controller) and a node role (query container + content node). See [Why Vespa is split](#why-vespa-is-split).
- **vespa-init**: one-shot job that deploys the cluster topology, then gets out of the way.
- **Marqo**: embedding inference and the search API, running against the external Vespa above.
- **Marqo Navigator**: web UI for index management, document upload, and search preview.
- **Caddy × 2**: authentication gateways for the UI and the raw API. Marqo has no authentication of its own, so nothing reaches it without going through Caddy.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                            Internet                              │
└─────────────┬───────────────────────────────────┬───────────────┘
              ▼                                   ▼
┌─────────────────────────┐         ┌─────────────────────────────┐
│   Caddy-UI (Public)     │         │    Caddy-API (Public)       │
│   UI_USERNAME/PASSWORD  │         │    API_USERNAME/PASSWORD    │
└─────────────┬───────────┘         └─────────────┬───────────────┘
              ▼                                   │
┌─────────────────────────┐                       │
│  Navigator (Private)    │                       │
│  Port 9882              │                       │
└─────────────┬───────────┘                       │
              │  http://marqo.railway.internal:8882
              └─────────────────┬─────────────────┘
                                ▼
              ┌─────────────────────────────────────┐
              │        Marqo (Private) :8882         │
              │        API + embedding inference     │
              │   volume: /root/.cache/huggingface   │
              └──────────────┬──────────────────────┘
                             │ external vector store
              ┌──────────────┴──────────────┐
              ▼                             ▼
   ┌────────────────────┐       ┌────────────────────────┐
   │ vespa-admin :19071 │◄──────│  vespa-node :8080      │
   │ config server, ZK  │       │  query container +     │
   │ logs, cluster ctrl │       │  content node (proton) │
   │ vol /opt/vespa/var │       │  vol /opt/vespa/var    │
   └────────────────────┘       └────────────────────────┘
              ▲
              │ deploys topology once, then exits
        ┌─────────────┐
        │ vespa-init  │
        └─────────────┘
```

## Why Vespa is split

Railway caps every container at **1000 threads (PIDs)**. Marqo bundles a full
Vespa cluster in one image, and that combination peaks at **~1010 threads** — it
cannot start, and no configuration fixes it. Measured on the stock image:

| Configuration | Peak threads | Fits in 1000? |
|---------------|--------------|---------------|
| Marqo + Vespa in one container | ~1010 | no |
| Vespa alone in one container | ~1010 | no |
| **vespa-admin** (this template, tuned) | **497 on Railway** | yes |
| **vespa-node** (this template, tuned) | **430 on Railway** | yes |
| **Marqo**, external vector store | **~34** | yes |

Two further details make the split hold:

- Marqo's `bootstrap_vespa()` rewrites `services.xml` on first start and
  **wipes anything under `<container>`** — its own source says so. Tuning placed
  under `<content>` or at the services root survives, which is where this
  template's `<searchnode><requestthreads>` tuning lives (proton: 166 → 90
  threads).
- Vespa matches nodes by the hostname each reports for itself. Railway does not
  let you set container hostnames, so both Vespa services set `VESPA_HOSTNAME`
  and `vespa-init` substitutes the same values into `hosts.xml`.

## Quick Start

1. Deploy the seven services (see [DEPLOYMENT.md](./DEPLOYMENT.md) for the step-by-step walkthrough)
2. Set `UI_PASSWORD` and `API_PASSWORD` — use different values
3. Wait for Marqo to go healthy. **First boot takes several minutes**: Vespa converges and ~420 MB of embedding weights download
4. Open the **Caddy-UI** public URL and sign in
5. Create your first index from the UI, or via the API:

```bash
curl -u "admin:$API_PASSWORD" -X POST \
  "https://your-api-url.railway.app/indexes/products" \
  -H 'Content-Type: application/json' \
  -d '{"type":"unstructured","model":"hf/e5-base-v2"}'
```

## Services

| Service | Source | Role |
|---------|--------|------|
| vespa-admin | This repo, `solutions/marqo-navigator/vespa` | Config server, ZooKeeper, log server, cluster controller (private) |
| vespa-node | This repo, `solutions/marqo-navigator/vespa` | Query container + content node (private) |
| vespa-init | This repo, `solutions/marqo-navigator/vespa-init` | One-shot topology bootstrap (private) |
| Marqo | This repo, `solutions/marqo-navigator/marqo` | Embedding inference + search API (private) |
| Navigator | This repo, `solutions/marqo-navigator/navigator` | Admin UI and search console (private) |
| Caddy-UI | GitHub repo [iliab1/caddy-password-auth](https://github.com/iliab1/caddy-password-auth) | Auth gateway for the UI (public) |
| Caddy-API | GitHub repo [iliab1/caddy-password-auth](https://github.com/iliab1/caddy-password-auth) | Auth gateway for the API and Swagger (public) |

All seven services build from source. **None of them is a Docker image reference** — `iliab1/caddy-password-auth` is a GitHub repository, and no image by that name exists on Docker Hub. Selecting "Docker Image" as the source for the Caddy services produces a deploy that fails before the build starts.

## Environment Variables

### Marqo — User-Configurable

| Variable | Default | Description |
|----------|---------|-------------|
| `MARQO_IMAGE_TAG` | `latest` | Marqo image tag (see [Image Tags](#image-tags)) |
| `MARQO_MODELS_TO_PRELOAD` | `["hf/e5-base-v2"]` | Models loaded during startup. Preloading is what makes the healthcheck meaningful — `/health` only goes green once the service can actually index. Must include the model you create indexes with |
| `MARQO_ENABLE_THROTTLING` | `TRUE` | Caps concurrent search and indexing operations |
| `MARQO_MAX_CONCURRENT_SEARCH` | `32` | Concurrent searches before Marqo returns 429. Marqo's own default is 8, which rejects from ~10 concurrent callers while Vespa sits idle. Costs ~120 threads on the Marqo service under load, none on Vespa |
| `MARQO_MAX_CONCURRENT_INDEX` | `32` | Same, for indexing |
| `MARQO_MAX_CPU_MODEL_MEMORY` | Image default | Memory ceiling in GB for loaded models. Raise if you preload several |
| `LOG_LEVEL` | `WARN` | Set to `INFO` to see per-request logging |

### vespa-admin / vespa-node — User-Configurable

| Variable | Default | Description |
|----------|---------|-------------|
| `VESPA_IMAGE_TAG` | `8.431.32` | Vespa image tag. Marqo's tooling pins this version; changing it is untested here |
| `VESPA_ROLE` | `services` | Which Vespa role the container runs: `configserver,services` on the admin service, `services` on the node. Passed as a variable rather than a Railway start command, because a start command replaces the image entrypoint instead of passing arguments to it |

### Navigator — User-Configurable

| Variable | Default | Description |
|----------|---------|-------------|
| `NAVIGATOR_IMAGE_TAG` | `v0.1.19` | Navigator image tag |

### Caddy-UI / Caddy-API — User-Configurable

| Variable | Default | Description |
|----------|---------|-------------|
| `UI_USERNAME` / `API_USERNAME` | `admin` | Login username |
| `UI_PASSWORD` / `API_PASSWORD` | `${{secret(32)}}` | Login password (auto-generated) |

### Auto-Configured (Do Not Change)

| Variable | Service | Value | Description |
|----------|---------|-------|-------------|
| `MARQO_API_URL` | Navigator | `http://${{Marqo.RAILWAY_PRIVATE_DOMAIN}}:8882` | Where Navigator's server-side proxy reaches Marqo. Changing this breaks every panel in the UI |
| `ORIGIN` | Caddy-UI | `http://${{Navigator.RAILWAY_PRIVATE_DOMAIN}}:9882` | Upstream for the UI gateway. Wrong value gives 502 |
| `ORIGIN` | Caddy-API | `http://${{Marqo.RAILWAY_PRIVATE_DOMAIN}}:8882` | Upstream for the API gateway. Wrong value gives 502 |
| `BASIC_AUTH` | Both Caddy | `${{USERNAME}}:${{PASSWORD}}` | Caddy hashes this at container start. Must stay in `user:pass` form |
| `VESPA_HOSTNAME` | Each Vespa service | its **own** `RAILWAY_PRIVATE_DOMAIN` | What the node reports itself as. Must match `hosts.xml`, which `vespa-init` writes from `VESPA_ADMIN_HOST`/`VESPA_NODE_HOST`. Mismatch means the cluster never converges |
| `VESPA_CONFIGSERVERS` | Both Vespa services | `${{vespa-admin.RAILWAY_PRIVATE_DOMAIN}}` | Where every node finds configuration. Points at **admin** on both |
| `VESPA_CONFIG_URL` / `VESPA_QUERY_URL` / `VESPA_DOCUMENT_URL` / `ZOOKEEPER_HOSTS` | Marqo | admin `:19071`, node `:8080`, admin `:2181` | Switch Marqo to external-vector-store mode. Must all four be set — a partial set is a fatal error, none at all makes Marqo start its own Vespa and exhaust the PID cap |

## Volumes

Three volumes, one per stateful service.

| Service | Mount Path | Purpose |
|---------|------------|---------|
| vespa-admin | `/opt/vespa/var` | Cluster configuration and ZooKeeper state |
| vespa-node | `/opt/vespa/var` | Documents, vectors, and the search index |
| Marqo | `/root/.cache/huggingface` | Embedding model weights (~420 MB) |

All three are **required**. Without the Vespa volumes every redeploy loses the
deployed application and your data. Without Marqo's, the model re-downloads on
every deploy and delays startup by minutes.

Vespa **blocks all writes** once disk passes 75% of a volume — searches keep
working, indexing returns HTTP 400. Size `vespa-node` with headroom; this is a
correctness constraint, not a capacity preference.

## Image Tags

The `MARQO_IMAGE_TAG` variable controls the Marqo version.

> **Read this before pinning.** Unlike most projects, Marqo's `latest` is **not** the newest build. Upstream [declared the open-source project deprecated](https://github.com/marqo-ai/marqo) after 2.16.1 and now ships current releases only under `-cloud` tags.

| Tag | Version | Description |
|-----|---------|-------------|
| `latest` | 2.16.1 (Mar 2025) | Last open-source release. Frozen — no further updates or security patches. 1.5 GB |
| `cloud-latest` | rolling | Newest build. Actively maintained, 21 API endpoints vs 15. 3.7 GB |
| `2.24.15-cloud` | Feb 2026 | Pinned current release |
| `2.16.1` | Mar 2025 | Pinned last OSS release |

The `-cloud` images are published publicly and require no credentials or licence. Both tag families are verified against this template: each boots from an empty volume through `railway-entrypoint.sh`, creates indexes, embeds documents, and returns semantic results, with nothing phoning home. The `-cloud` images are, however, built for Marqo's hosted product and carry no public support commitment.

**One caveat if you pin an OSS tag:** the current `py-marqo` Python client requires Marqo 2.23.1 or newer and logs a version warning against 2.16.1. The REST API works regardless; only the official client is affected.

Changing the tag triggers a rebuild. Bumping across versions against an existing volume is untested here — Vespa's upgrade path may clear directories it does not recognise, which would cost a one-time re-download of the model cache but not your indexes.

## Embedding Models

The model is chosen per index, not per deployment, so different catalogues can use different models in the same instance.

| Model | Use for | Notes |
|-------|---------|-------|
| `hf/e5-base-v2` | Text search (default) | Strongest pure text-to-text ranking. 768 dimensions, ~420 MB |
| [`Marqo/marqo-ecommerce-embeddings-B`](https://huggingface.co/Marqo/marqo-ecommerce-embeddings-B) | Product search, text **and** images | Trained on retail catalogues. 768 dimensions, 203M params |
| [`Marqo/marqo-ecommerce-embeddings-L`](https://huggingface.co/Marqo/marqo-ecommerce-embeddings-L) | Product search, higher accuracy | 1024 dimensions, 652M params — slower and heavier |
| [`Marqo/marqo-fashionSigLIP`](https://huggingface.co/Marqo/marqo-fashionSigLIP) | Apparel and accessories | Fashion-specific, outperforms FashionCLIP 2.0 |

Marqo reports its ecommerce models beating `ViT-SO400M-14-SigLIP` by 17.6% MRR and Amazon-Titan-Multimodal by 38.9% MRR on the `marqo-ecommerce-hard` benchmark.

Load one by naming it at index creation:

```bash
curl -u "admin:$API_PASSWORD" -X POST "$API/indexes/catalogue" \
  -H 'Content-Type: application/json' \
  -d '{"type":"unstructured",
       "model":"marqo-ecommerce-B",
       "modelProperties":{"name":"hf-hub:Marqo/marqo-ecommerce-embeddings-B",
                          "type":"open_clip","dimensions":768},
       "treatUrlsAndPointersAsImages":true}'
```

With `treatUrlsAndPointersAsImages` set, any field holding an image URL is fetched and embedded as pixels. Index a product photo with no description and shoppers can still find it by describing what it looks like.

A single document can carry text and image tensor fields together — `tensorFields: ["title","description","image"]` produces three vectors per document, and search results report which field matched under `_highlights`. Verified on this stack, as is loading `Marqo/marqo-fashionSigLIP` through the same `hf-hub:` / `open_clip` path shown above.

**Choose deliberately.** The ecommerce and fashion models are CLIP-family and image-first. Measured on this stack, they rank text-to-image correctly but are *weaker than `hf/e5-base-v2` on text-only queries* — a text-only search for "comfortable grey trainers" put a cast iron skillet above wool runners. Use them when images are part of your index; stay on `e5-base-v2` for pure text.

Cross-modal scores also sit lower in absolute terms than text-to-text ones (roughly 0.5 vs 0.8 here). Two consequences: don't mix text-only and image-only documents in one index if you rank on a score threshold, and on documents carrying both, expect the text fields to win `_highlights` most of the time. Image fields pull their weight where listing text is sparse or missing, not as a general uplift on well-described products.

Any model not in `MARQO_MODELS_TO_PRELOAD` downloads on first use, which makes that first index-creation call slow but not stuck.

## Testing the Deployment

### Health

```bash
curl -u "admin:$API_PASSWORD" "https://your-api-url.railway.app/health"
# {"status":"green","inference":{"status":"green"},"backend":{"status":"green",...}}
```

`status` is `yellow` while Vespa is still converging and `green` when ready.

### Index and search

```bash
API="https://your-api-url.railway.app"
AUTH="admin:$API_PASSWORD"

curl -u "$AUTH" -X POST "$API/indexes/products" \
  -H 'Content-Type: application/json' \
  -d '{"type":"unstructured","model":"hf/e5-base-v2"}'

curl -u "$AUTH" -X POST "$API/indexes/products/documents" \
  -H 'Content-Type: application/json' \
  -d '{"documents":[
        {"_id":"1","title":"Down Winter Jacket","description":"800 fill goose down parka rated to minus 20 celsius"},
        {"_id":"2","title":"Espresso Machine","description":"15-bar pump coffee maker with milk frother"}
      ],"tensorFields":["title","description"]}'

curl -u "$AUTH" -X POST "$API/indexes/products/search" \
  -H 'Content-Type: application/json' \
  -d '{"q":"something to keep me warm in the snow"}'
# Top hit: Down Winter Jacket — no shared keywords with the query
```

### Swagger

Open `https://your-api-url.railway.app/docs` and sign in. The **Try it out** buttons should work without a second prompt: the spec declares no `servers` entry, so the page issues root-relative requests to the same origin and the browser reattaches your credentials.

### Python client

`py-marqo`'s `api_key` parameter sends an `x-api-key` header, which is a Marqo Cloud mechanism and not basic auth. Pass credentials in the URL instead — verified working through the gateway:

```python
import marqo
mq = marqo.Client(url="https://admin:YOUR_API_PASSWORD@your-api-url.railway.app")
mq.index("products").search("warm clothes for camping")
```

Without credentials the same call raises `MarqoWebError` on the gateway's 401.

## Local Development

`docker-compose.yml` mirrors the Railway topology — same Dockerfiles, same single-volume layout, only the two Caddy services publish ports:

```bash
cp .env.example .env
docker compose up -d --build
open http://localhost:8080        # UI
open http://localhost:8081/docs   # API + Swagger
```

## Railway Service Configuration

Seven services, three volumes, two public domains, and a set of cross-service
references that must line up exactly. The full per-service walkthrough —
sources, root directories, start commands, every variable, volumes, healthchecks
and the order to create them in — is in **[DEPLOYMENT.md](./DEPLOYMENT.md)**.

Summary of what is public and what is not:

| Service | Root directory | Public domain | Volume |
|---------|----------------|---------------|--------|
| vespa-admin | `solutions/marqo-navigator/vespa` (`VESPA_ROLE=configserver,services`) | no | `/opt/vespa/var` |
| vespa-node | `solutions/marqo-navigator/vespa` (`VESPA_ROLE=services`) | no | `/opt/vespa/var` |
| vespa-init | `solutions/marqo-navigator/vespa-init` | no | — |
| Marqo | `solutions/marqo-navigator/marqo` | no | `/root/.cache/huggingface` |
| Navigator | `solutions/marqo-navigator/navigator` | no | — |
| Caddy-UI | *(external repo)* | **yes**, port 8080 | — |
| Caddy-API | *(external repo)* | **yes**, port 8080 | — |

## Troubleshooting

### First deploy never goes healthy

Marqo's first boot downloads embedding weights before `/health` returns 200. Give it several minutes. If Railway restart-loops the service before it settles, raise the healthcheck timeout in **Settings → Deploy**.

### "Marqo vector store is out of memory or disk space"

Vespa **blocks all writes** once disk usage passes 75% of the volume — searches keep working, indexing returns HTTP 400. This is a hard limit, not a warning, so volume sizing is a correctness constraint here rather than a capacity preference. Grow the volume in **Settings → Volumes**; Vespa re-samples and unblocks within a minute or two.

Check current usage:

```bash
curl -u "admin:$API_PASSWORD" "https://your-api-url.railway.app/indexes/products/stats"
```

`storageUsedPercentage` is reported relative to that 75% limit, not to raw disk — 87% there means roughly 65% of the volume.

### 502 Bad Gateway from either Caddy

`ORIGIN` is wrong or the upstream is not running. It must be the full URL including port: `http://marqo.railway.internal:8882`, not just the hostname.

If `ORIGIN` is correct and Marqo is healthy, check when the Railway **environment** was created. Environments predating 16 October 2025 resolve private DNS to IPv6 only, and Marqo binds `0.0.0.0:8882` without an IPv6 listener — so nothing can reach it internally. Newer environments are dual-stack and unaffected. Deploying this template creates a fresh environment, so this only arises when adding the services to an older project.

### UI loads but every panel is empty

`MARQO_API_URL` on the Navigator service is wrong, or Marqo is not healthy yet. Navigator proxies server-side, so check its deploy logs rather than the browser console.

### Navigator crashes on boot with "Missing parameter name at 1"

The custom Dockerfile is not being used. The upstream published image ships Express 5, which rejects the wildcard route the proxy registers; `navigator/Dockerfile` pins Express 4 to fix it. Confirm the service's root directory is `solutions/marqo-navigator/navigator`.

### Navigator dashboard shows "Memory Usage 139%"

A cosmetic bug in Navigator's gauge scaling. Trust `/indexes/{name}/stats` instead.

### Index creation hangs

The first index using an unpreloaded model downloads it on demand. Either wait, or add the model to `MARQO_MODELS_TO_PRELOAD` and redeploy.

## Limitations

- **Single node.** One Marqo instance with an embedded Vespa backend. Scale vertically; there is no HA or horizontal scaling in this template.
- **No per-user auth.** Basic auth is a shared password per gateway, not user accounts. Anyone with the API credential can delete every index (`DELETE /indexes/{name}`) — which is why the two gateways use separate passwords.
- **Memory hungry.** Roughly 4.7 GB resident after one model loads. Preloading more models raises that proportionally.
- **CPU inference only.** Marqo supports CUDA, but Railway does not expose GPUs.
- **Upstream is deprecated.** The open-source project receives no further updates. See [Image Tags](#image-tags).

## Resources

- [Marqo GitHub](https://github.com/marqo-ai/marqo)
- [Marqo Documentation](https://docs.marqo.ai)
- [py-marqo Python client](https://github.com/marqo-ai/py-marqo)
- [Marqo Navigator](https://github.com/ForgemasterAI/marqo-navigator)
- [Caddy Password Auth](https://github.com/iliab1/caddy-password-auth)
- [Vespa feed block documentation](https://docs.vespa.ai/en/operations/feed-block.html)
