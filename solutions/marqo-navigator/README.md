# Marqo + Navigator (Protected)

Deploy Marqo vector search with the Navigator admin UI, both behind Caddy password authentication.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/ukdruK?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Overview

Marqo is an AI-native search platform aimed at online retail — product search and discovery for fashion, beauty, electronics, and home goods — and equally usable as a general-purpose vector search engine. It ships purpose-built [ecommerce and fashion embedding models](#embedding-models) that load into this deployment by name.

This template deploys a four-service stack:

- **Marqo**: Vector search engine — generates embeddings and stores them in an embedded Vespa index. You send plain text or image URLs; it matches on meaning rather than keywords.
- **Marqo Navigator**: Web UI for index management, document upload, and search preview.
- **Caddy × 2**: Two authentication gateways, one for the UI and one for the raw API. Marqo has no authentication of its own, so nothing reaches it without going through Caddy.

Marqo exposes a FastAPI service with an interactive Swagger page at `/docs`. Both the UI and that API are published, each behind its own password.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                            Internet                              │
└─────────────┬───────────────────────────────────┬───────────────┘
              │                                   │
              ▼                                   ▼
┌─────────────────────────┐         ┌─────────────────────────────┐
│   Caddy-UI (Public)     │         │    Caddy-API (Public)       │
│   Basic Auth            │         │    Basic Auth               │
│   UI_USERNAME/PASSWORD  │         │    API_USERNAME/PASSWORD    │
└─────────────┬───────────┘         └─────────────┬───────────────┘
              │                                   │
              ▼                                   │
┌─────────────────────────┐                       │
│  Navigator (Private)    │                       │
│  Port 9882              │                       │
│  Dashboard + Search UI  │                       │
└─────────────┬───────────┘                       │
              │ http://marqo.railway.internal:8882│
              └─────────────────┬─────────────────┘
                                ▼
              ┌─────────────────────────────────────┐
              │        Marqo (Private)               │
              │        Port 8882                     │
              │        REST API + Swagger at /docs   │
              │                                      │
              │   ┌──────────────────────────────┐   │
              │   │  /opt/vespa/var Volume        │   │
              │   │  ├── db, vespa, zookeeper …   │   │
              │   │  │   indexes, documents,      │   │
              │   │  │   vectors                  │   │
              │   │  └── hf-cache/                │   │
              │   │      embedding model weights  │   │
              │   └──────────────────────────────┘   │
              └─────────────────────────────────────┘
```

Navigator reaches Marqo directly over Railway's private network, so browsing the UI never requires the API credential.

## Quick Start

1. Deploy the four services (see [Railway Service Configuration](#railway-service-configuration))
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
| Marqo | `marqo/Dockerfile` | Vector search engine (private) |
| Navigator | `navigator/Dockerfile` | Admin UI and search console (private) |
| Caddy-UI | [iliab1/caddy-password-auth](https://github.com/iliab1/caddy-password-auth) | Auth gateway for the UI (public) |
| Caddy-API | [iliab1/caddy-password-auth](https://github.com/iliab1/caddy-password-auth) | Auth gateway for the API and Swagger (public) |

## Environment Variables

### Marqo — User-Configurable

| Variable | Default | Description |
|----------|---------|-------------|
| `MARQO_IMAGE_TAG` | `latest` | Marqo image tag (see [Image Tags](#image-tags)) |
| `MARQO_MODELS_TO_PRELOAD` | `["hf/e5-base-v2"]` | Models loaded during startup. Preloading is what makes the healthcheck meaningful — `/health` only goes green once the service can actually index. Must include the model you create indexes with |
| `MARQO_ENABLE_THROTTLING` | `TRUE` | Caps concurrent search and indexing operations |
| `MARQO_MAX_CPU_MODEL_MEMORY` | Image default | Memory ceiling in GB for loaded models. Raise if you preload several |
| `LOG_LEVEL` | `WARN` | Set to `INFO` to see per-request logging |

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

## Volume

| Service | Mount Path | Purpose |
|---------|------------|---------|
| Marqo | `/opt/vespa/var` | Vespa state (indexes, documents, vectors) **and** embedding model weights under `hf-cache/` |

Railway allows one volume per service, and Marqo needs two paths to survive a redeploy. The usual trick — mount elsewhere and symlink both in — does not work here: the upstream image declares `VOLUME /opt/vespa/var`, so that path is always a live mountpoint and cannot be replaced with a symlink. Instead the volume mounts at Vespa's own directory and `railway-entrypoint.sh` nests the HuggingFace cache inside it.

Without the model cache on the volume, every redeploy re-downloads ~420 MB before the healthcheck can pass, which risks a restart loop.

**The volume is required.** Deployed without it, every redeploy starts from an empty index.

Verified from an empty volume on both a `latest` and a `-cloud` image: the entrypoint seeds the skeleton, Marqo reaches healthy, and after a container recreate the indexes and the cached weights are both still there with no re-download.

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

Summary of the four services. For a step-by-step walkthrough of building the template in Railway's composer — including creation order, healthcheck timeouts, and post-deploy verification — see [DEPLOYMENT.md](./DEPLOYMENT.md).

### Marqo

| Setting | Value |
|---------|-------|
| Source | This repository, root directory `solutions/marqo-navigator/marqo` |
| Variable | `MARQO_IMAGE_TAG` = `latest` |
| Variable | `MARQO_MODELS_TO_PRELOAD` = `["hf/e5-base-v2"]` |
| Variable | `MARQO_ENABLE_THROTTLING` = `TRUE` |
| Variable | `PORT` = `8882` (Marqo binds this unconditionally and ignores Railway's injected value) |
| Volume | Mount path `/opt/vespa/var` |
| Healthcheck | Path `/health`, timeout `600` seconds |
| Networking | No public domain — private only |

### Navigator

| Setting | Value |
|---------|-------|
| Source | This repository, root directory `solutions/marqo-navigator/navigator` |
| Variable | `MARQO_API_URL` = `http://${{Marqo.RAILWAY_PRIVATE_DOMAIN}}:8882` |
| Variable | `NAVIGATOR_IMAGE_TAG` = `v0.1.19` |
| Variable | `PORT` = `9882` (hardcoded in the proxy) |
| Networking | No public domain — private only |

### Caddy-UI

| Setting | Value |
|---------|-------|
| Source | [iliab1/caddy-password-auth](https://github.com/iliab1/caddy-password-auth) |
| Variable | `ORIGIN` = `http://${{Navigator.RAILWAY_PRIVATE_DOMAIN}}:9882` |
| Variable | `BASIC_AUTH` = `admin:${{secret(32)}}` |
| Variable | `PORT` = `8080` |
| Networking | HTTP domain, target port `8080` |

### Caddy-API

| Setting | Value |
|---------|-------|
| Source | [iliab1/caddy-password-auth](https://github.com/iliab1/caddy-password-auth) |
| Variable | `ORIGIN` = `http://${{Marqo.RAILWAY_PRIVATE_DOMAIN}}:8882` |
| Variable | `BASIC_AUTH` = `admin:${{secret(32)}}` |
| Variable | `PORT` = `8080` |
| Networking | HTTP domain, target port `8080` |

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
