# Marqo + Navigator Railway Template

## Template Overview

# Deploy and Host Marqo Ecommerce Search and Discovery on Railway

Marqo is an AI-native search platform aimed at online retail — product search and discovery for categories like fashion, beauty, electronics, and home goods. Shoppers rarely search the words you put in your product titles. They type "something to keep me warm in the snow" and expect the down jacket. Marqo embeds your catalogue and their query into the same vector space, so intent matches inventory without a single synonym list or keyword rule.

It is also a general-purpose vector search engine: embedding inference and vector storage with no separate model pipeline to operate. This template pairs it with Marqo Navigator, a web UI for managing indexes and previewing searches, and puts both behind Caddy password authentication.

## About Hosting Marqo + Navigator

This template deploys a seven-service stack:

- **Marqo**: Embedding inference and the search API
- **Vespa (×2)**: The vector store, split across two services so each stays within Railway's per-container thread limit
- **Marqo Navigator**: Web dashboard for index management, document upload, and search preview
- **Caddy × 2**: Separate authentication gateways for the UI and the raw API — Marqo ships with no authentication of its own, so neither service is ever exposed directly
- **Private Networking**: Marqo and Navigator run on Railway's internal network; only the Caddy gateways hold public domains
- **Persistent Storage**: Railway volumes for the cluster configuration, the vector index, and the cached embedding model weights

## Purpose-Built Ecommerce Models

Marqo publishes embedding models trained specifically on retail catalogues, and any of them can be loaded into this deployment by naming it at index creation — no code changes, no separate inference service.

| Model | Built for | Benchmark |
|-------|-----------|-----------|
| [Marqo-Ecommerce-B / L](https://huggingface.co/collections/Marqo/marqo-ecommerce-embeddings-66f611b9bb9d035a8d164fbb) | General product search | Marqo reports **+17.6% MRR** over the best open-source model (`ViT-SO400M-14-SigLIP`) and **+38.9% MRR** over Amazon-Titan-Multimodal on its `marqo-ecommerce-hard` benchmark |
| [Marqo-FashionSigLIP / FashionCLIP](https://huggingface.co/Marqo/marqo-fashionSigLIP) | Apparel and accessories | Marqo reports both outperforming FashionCLIP 2.0 and OpenFashionCLIP across text-to-image, category-to-product, and sub-category-to-product tasks |


Different indexes can use different models, so a fashion catalogue and a homeware catalogue can each run the model that suits it.

**A note on versions:** Vespa is pinned to `8.431.32`, the release Marqo's own
tooling targets. Newer Vespa releases change a status field Marqo reads, which
makes its health endpoint return 400 while search continues working. You can
raise `VESPA_IMAGE_TAG` and test a newer release, but **pin before you index**:
Vespa refuses to start on state written by a newer release, so a cluster that
ran `latest` and accumulated data cannot simply be pinned back — it needs both
Vespa volumes wiped and a full reindex.

**A note on the self-hosted project:** Marqo's open-source releases stopped at 2.16.1 in March 2025 and upstream has marked the OSS project deprecated. Current builds are published under `-cloud` tags, which self-host without a licence or credentials — this template runs either, selected with one variable. See the README for the trade-off.

## Search Product Photos, Not Just Descriptions

The ecommerce models are multimodal. Point Marqo at your product image URLs and it embeds the pixels — shoppers then find items by describing them, even where the listing text is thin, wrong, or missing entirely. This is the case keyword search cannot serve at all: an image has no keywords.

Titles, descriptions, and photography can live on the same document and are each embedded and searched. In practice text fields tend to out-score image fields on the same query, so photography earns its keep most where listing text is sparse or unreliable.

## Getting Started After Deployment

### Accessing the UI and Finding Your Credentials

Click the **Caddy-UI** service to find its URL — shown on the Deployments tab, or
under Settings → Networking. The **Caddy-API** service has its own URL for the
REST API and Swagger page.

Each gateway generates its own password on deploy: open the service, go to the
**Variables** tab and reveal `BASIC_AUTH`. The two are deliberately different —
the API credential grants index deletion, so it should not be handed out
alongside read access to the dashboard.

### First Boot Takes a Few Minutes

Marqo downloads roughly 420 MB of embedding model weights on its first deploy, and the Vespa backend needs time to converge. The service reports healthy only once it can actually index. Subsequent redeploys reuse the cached weights from the volume and start in well under a minute.

### Creating Your First Index

From the API:

```bash
curl -u "admin:$API_PASSWORD" -X POST \
  "https://your-api-url.railway.app/indexes/products" \
  -H 'Content-Type: application/json' \
  -d '{"type":"unstructured","model":"hf/e5-base-v2"}'
```

Or use the interactive Swagger page at `https://your-api-url.railway.app/docs`, which works through the gateway — sign in once and the **Try it out** buttons are live.

## Common Use Cases

### Ecommerce Search and Discovery
- Product search that understands intent — "warm jacket for hiking" finds the parka without keyword overlap
- Visual search over product photography, including catalogues with sparse or inconsistent listing text
- Fashion and apparel search using models trained on apparel specifically
- "More like this" recommendations and related-product carousels built on catalogue similarity
- Long-tail and zero-result recovery, where keyword search returns nothing but intent is clear
- Catalogue deduplication and near-duplicate detection across merged supplier feeds

### Beyond Retail
- Retrieval-augmented generation (RAG) backends supplying context to an LLM
- Documentation and knowledge base search that matches intent instead of exact wording
- Image and multimodal retrieval using CLIP-family models
- Semantic search over any text corpus where wording varies but meaning does not

## Dependencies for Marqo + Navigator Hosting

- Docker (all seven services run as containers)

### Deployment Dependencies

- [Marqo Docker Image](https://hub.docker.com/r/marqoai/marqo)
- [Marqo Navigator](https://github.com/ForgemasterAI/marqo-navigator)
- [Caddy Password Auth](https://github.com/iliab1/caddy-password-auth)

### Services

| Service | Role |
|---------|------|
| vespa-admin | Vespa config server, ZooKeeper, cluster controller (private) |
| vespa-node | Vespa query container + content node (private) |
| vespa-init | One-shot cluster bootstrap (private) |
| Marqo | Embedding inference + search API (private) |
| Navigator | Admin UI and search console (private) |
| Caddy-UI | Auth gateway for the UI (public) |
| Caddy-API | Auth gateway for the API and Swagger (public) |

### Environment Variables

Every service is pre-configured. The ones worth knowing: `MARQO_IMAGE_TAG` and
`VESPA_IMAGE_TAG` pin versions, `MARQO_MODELS_TO_PRELOAD` selects the embedding
model, and `BASIC_AUTH` on each Caddy service holds the generated password. Full
reference in the repository README.

### Volume

| Service | Mount Path | Purpose |
|---------|------------|---------|
| vespa-admin | `/opt/vespa/var` | Cluster configuration and ZooKeeper state |
| vespa-node | `/opt/vespa/var` | Documents, vectors, and the search index |
| Marqo | `/root/.cache/huggingface` | Cached embedding model weights |

## Key Features

### Search by Meaning, Not Keywords
Marqo embeds documents and queries into the same vector space, so "something to keep me warm in the snow" finds a down jacket without sharing a single word with it. No keyword tuning, no synonym lists, no zero-result pages for shoppers who described what they wanted instead of naming it.

### Retail-Trained Models, Swappable Per Index
Marqo's own ecommerce and fashion embedding models beat both the leading open-source and leading commercial multimodal models on retail benchmarks, and load into this deployment by name at index creation. Start on the general-purpose default, switch to a retail model when your catalogue justifies it.

### Web Dashboard
Marqo Navigator provides index management, document upload, live search preview, and index statistics from the browser, so you can inspect and query your data without writing API calls.

### Authentication on Both Surfaces
Marqo has no built-in authentication, and its API can delete every index. This template puts a Caddy gateway in front of both the dashboard and the API, each with its own password, and keeps Marqo itself off the public internet entirely.

### Interactive API Documentation
The bundled Swagger page works through the auth gateway. Sign in once and explore all endpoints interactively from the browser.

### Persistent Storage
Railway volumes hold the vector index, the cluster configuration, and the downloaded model weights, so redeployments preserve your data and skip the model download.

## Why Deploy Marqo + Navigator on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Marqo + Navigator on Railway, you get a semantic search engine with a web dashboard, password protection on both surfaces, private networking, and persistent storage — configured and ready to use. Host your servers, databases, AI agents, and more on Railway.
