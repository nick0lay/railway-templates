# Yente 5.5 + Elasticsearch

A self-hosted sanctions and PEP screening API. [Yente](https://github.com/opensanctions/yente) is the open-source API behind OpenSanctions: send it a person or a company and it scores them against sanctions lists, politically exposed persons (PEPs), wanted lists and more. This template runs Yente 5.5.1 with its Elasticsearch index, keeps both private, and puts a bearer-token proxy in front.

> **Data licence: read this before you deploy.** Yente's code is MIT, but the OpenSanctions **data** it downloads is free only for non-commercial use (CC BY-NC 4.0). Using it in a business, including screening your own customers, needs a data licence from OpenSanctions: https://www.opensanctions.org/licensing/. The template downloads the data from OpenSanctions' public, non-commercial source by default. Making sure your use is covered is your responsibility.

**Yente has no authentication of its own** (its API description says so). In this template Yente and Elasticsearch have no public domain. The only public service is a small Caddy proxy that requires `Authorization: Bearer <PROXY_TOKEN>` on every request. The token is generated at deploy.

## Architecture

```
Your app, script or workflow tool
   │  HTTPS, Authorization: Bearer <PROXY_TOKEN>
   ▼
┌──────────────────────────┐  private network  ┌──────────────────────────┐  private network  ┌──────────────────────────┐
│ Token Proxy (public)     │ ────────────────▶ │ Yente (private)          │ ────────────────▶ │ Elasticsearch (private)  │
│ caddy:2.11.9-alpine :8080│   http :8000      │ ghcr.io/opensanctions/   │  http :9200,      │ elastic/elasticsearch    │
│ 401 without the token    │                   │ yente:5.5.1              │  user + password  │ 9.5.6, volume            │
└──────────────────────────┘                   └────────────┬─────────────┘                   └──────────────────────────┘
                                                            │ HTTPS, every hour
                                                            ▼
                                                 data.opensanctions.org
                                                 (new data releases)
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Token Proxy | `caddy:2.11.9-alpine` | Public HTTPS. Checks the bearer token and forwards to Yente. `/healthz` is the only open path |
| Yente | `ghcr.io/opensanctions/yente:5.5.1` | Screening API (`/match`, `/search`, `/entities`, `/reconcile`). Downloads OpenSanctions data and indexes it into Elasticsearch. Private, no domain |
| Elasticsearch | `elastic/elasticsearch:9.5.6` | Search index on a volume. Security on (password), private, no domain or TCP proxy |

## First start: indexing

On the first start Yente downloads the OpenSanctions data and builds the index. The API answers at once, but `/search` and `/match` return results only after the first index is complete. Check `GET /readyz`: it returns 503 while indexing and 200 when the index is ready.

Measured on Railway (2026-11-11):

| Scope (`OPENSANCTIONS_SCOPE`) | Entities | Download | First index | Elasticsearch RAM idle | Elasticsearch RAM peak | Index on disk |
|------|---------:|---------:|------------:|------:|------:|------:|
| `default` (template default, `ES_HEAP_SIZE=2g`) | 3.9M | 2.6 GB | about 20 minutes | about 2.8 GB | 5.8 to 6.4 GB | about 3 GB (3.5 GB peak) |
| `sanctions` (`ES_HEAP_SIZE=1g`) | 310k | 0.4 GB | about 2 minutes | 2.5 GB | 2.5 GB | about 0.7 GB |

Yente itself uses about 0.5 to 0.6 GB, the proxy about 0.02 GB. Elasticsearch memory settles to the idle figure some minutes after indexing ends.

After the first index, Yente checks for new data every hour (at a random minute) and applies the changes in the background. OpenSanctions publishes new data several times a day. The current index keeps answering while the next one is built, and the switch is instant.

### Which scope?

- **`default`** (the template default) is the full OpenSanctions collection: sanctions, PEPs, crime, debarment, wanted lists and related entities. It is what OpenSanctions' own API screens against, and you need it for PEP screening.
- **`sanctions`** covers sanctions lists only. It indexes in 2 minutes, uses less memory and fits a small volume comfortably. Set `ES_HEAP_SIZE=1g` with it.
- **`peps`** is PEPs only (about 2M entities). Other collections are listed at https://www.opensanctions.org/datasets/.

Change `OPENSANCTIONS_SCOPE` on the Yente service and redeploy; Yente builds the new index next to the old one, then deletes the old one. The API paths contain the scope: `/match/<scope>`, `/search/<scope>`.

### Disk space

Railway volumes start at 5 GB (the Hobby limit). With `default`, the index takes about 3 GB. The hourly updates should fit: they copy the current index (cheaply, with hard links) and apply only the changes. A **full** rebuild of `default` (`POST /updatez`, or a future Yente version with a new index format) builds a second full index before deleting the first, so it needs roughly twice the index size, an estimated 6 to 7 GB. A scope change needs the old index plus the new one (for example about 3.7 GB from `default` to `sanctions`, more to `peps`). Elasticsearch stops allocating new indices above 85% disk and makes indices read-only at 95%. On Pro, grow the volume to 10 GB or more before a full rebuild; on Hobby, use the `sanctions` scope if you expect full rebuilds.

## After deploy

1. Open the **Token Proxy** service, Variables tab. Copy `PUBLIC_URL` and `PROXY_TOKEN`.
2. Wait until `/readyz` returns 200 (about 20 minutes with the default scope):

```bash
curl -H "Authorization: Bearer $PROXY_TOKEN" https://<domain>/readyz
```

3. Screen a person or a company with `/match` (this is the endpoint for compliance checks):

```bash
curl -X POST https://<domain>/match/default \
  -H "Authorization: Bearer $PROXY_TOKEN" -H "Content-Type: application/json" \
  -d '{"queries": {"q1": {"schema": "Person",
        "properties": {"name": ["Vladimir Putin"], "birthDate": ["1952-10-07"]}}}}'
```

Each result has a `score` (0 to 1), `match` (true above the threshold, 0.7 by default) and `properties.topics` such as `sanction`, `role.pep` or `crime`. Send up to 100 queries per request.

4. Search by text (for a search box in your app):

```bash
curl -H "Authorization: Bearer $PROXY_TOKEN" "https://<domain>/search/default?q=sberbank"
```

The API reference is at https://www.opensanctions.org/docs/api/ and in your deployment at `/openapi.json` (with the token). The matching guide: https://www.opensanctions.org/docs/api/matching/.

### From another service in this project

Services in the same project can call Yente over the private network without the token:

```
YENTE_URL=${{Yente.PRIVATE_URL}}
```

## Environment Variables

### Yente

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENSANCTIONS_SCOPE` | `default` | Collection to index (see above) |
| `YENTE_MANIFEST_YAML` | OpenSanctions catalog at `data.opensanctions.org`, scope `${{OPENSANCTIONS_SCOPE}}` | The manifest: which data Yente indexes. Written to `/tmp/manifest.yml` at every start. Add your own datasets here (https://www.opensanctions.org/docs/yente/datasets/) |
| `OPENSANCTIONS_DELIVERY_TOKEN` | empty | For licensed commercial users (see below) |
| `YENTE_AUTO_REINDEX` | `true` | Hourly check for new data |
| `YENTE_UPDATE_TOKEN` | generated | `POST /updatez?token=<value>` (with the proxy token) starts a full re-index now. Yente writes request URLs, including this token, to its log |
| `YENTE_MANIFEST` | `/tmp/manifest.yml` | Path or `https://` URL of the manifest |
| `YENTE_INDEX_URL`, `YENTE_INDEX_USERNAME`, `YENTE_INDEX_PASSWORD`, `YENTE_INDEX_TYPE` | Elasticsearch over the private network | Auto-configured |
| `YENTE_HOST`, `PORT` | `0.0.0.0`, `8000` | Auto-configured |
| `PRIVATE_URL` | `http://${{RAILWAY_PRIVATE_DOMAIN}}:8000` | For other services in the project |

Other Yente settings (`YENTE_MATCH_PAGE`, `YENTE_MAX_BATCH`, `YENTE_CRONTAB` and more) can be added as variables: https://www.opensanctions.org/docs/yente/settings/.

### Elasticsearch

| Variable | Default | Description |
|----------|---------|-------------|
| `ES_HEAP_SIZE` | `2g` | Java heap. `2g` for `default`, `1g` is enough for `sanctions` |
| `ELASTIC_PASSWORD` | generated | Password of the `elastic` user, used by Yente. Applied on the first start only |
| `ELASTICSEARCH_URL` | `http://${{RAILWAY_PRIVATE_DOMAIN}}:9200` | For other services in the project |
| `discovery.type`, `node.store.allow_mmap`, `network.host`, `xpack.security.*`, `RAILWAY_RUN_UID` | | Railway settings: single node, no mmap (Railway can't raise `vm.max_map_count`), IPv4 and IPv6, security on without TLS on the private network, root only to fix volume ownership |

### Token Proxy

| Variable | Default | Description |
|----------|---------|-------------|
| `PROXY_TOKEN` | generated (48 letters and digits) | The bearer token. Change it to rotate |
| `PUBLIC_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Base URL of the API |
| `SEARCH_URL` | `https://<domain>/search/<scope>` | Example URL |
| `UPSTREAM_URL`, `PORT`, `CADDYFILE` | | Auto-configured. Edit `CADDYFILE` to add CORS, rate limits or a second token |

## Commercial use with a data licence

After you buy an OpenSanctions licence, switch Yente to the licensed delivery service:

1. Copy your delivery token from https://www.opensanctions.org/account/bulk/ into `OPENSANCTIONS_DELIVERY_TOKEN` on the Yente service.
2. Change `YENTE_MANIFEST_YAML` to:

```yaml
catalogs:
  - url: "https://delivery.opensanctions.com/datasets/latest/index.json"
    auth_token: "$OPENSANCTIONS_DELIVERY_TOKEN"
    scope: "${{OPENSANCTIONS_SCOPE}}"
    resource_name: entities.ftm.json
datasets: []
```

3. Redeploy Yente.

## Security

- Yente and Elasticsearch have no public domain and no TCP proxy.
- Every request to the proxy needs the exact token; `/healthz` (Railway's healthcheck) is the only exception. The proxy removes the `Authorization` header before forwarding.
- Elasticsearch requires a password on every request, also on the private network.
- The browser API docs page at `/` needs the token too, so use the OpenSanctions docs or `/openapi.json` with the token.

## Persistence

The index, its version and Yente's lock live in Elasticsearch on the volume. Yente keeps no state. After a redeploy Yente finds the current index and answers at once, without re-indexing.

## Testing

Tested on Railway on 2026-11-11:

- Requests without the token, with a wrong token, with the token plus extra characters, with Basic auth and with the token in the query string: all 401. `/`, `/openapi.json`, `/readyz` and `/catalog` refused without the token. `/healthz` open
- With the token: `/readyz` 200 after indexing, `/catalog` lists the scope as current, `/search` finds Vladimir Putin, `/match` scores Vladimir Putin (with birth date) 1.0 with the `sanction` and `role.pep` topics and finds Sberbank as a company
- Both the `default` and the `sanctions` scopes, and a clean deploy with the template's default settings
- Redeploy of Elasticsearch and Yente: Yente logged "No update needed", `/readyz` 200 right away, all checks passed again
- Yente and Elasticsearch have no public domain or TCP proxy; Elasticsearch security on

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `401 Unauthorized` | Send `Authorization: Bearer <PROXY_TOKEN>` from the Token Proxy service |
| `/readyz` returns 503, `/match` returns no results | The first index is still being built. Watch the Yente deploy log (`Index: N entities...`) |
| `404` on `/match/default` | The path has to use your `OPENSANCTIONS_SCOPE`, e.g. `/match/sanctions` |
| Yente log: `cluster_block_exception` or `read-only` | The volume is full (Elasticsearch blocks writes at 95%). Grow the volume, or switch to a smaller scope |
| Elasticsearch restarts while indexing | Out of memory: raise `ES_HEAP_SIZE` only together with the service's memory limit, or use the `sanctions` scope |
| `403` on `/updatez` | Pass `?token=<YENTE_UPDATE_TOKEN>` (and the proxy token in the header) |

## Licence

- Yente: MIT. Copyright OpenSanctions Datenbanken GmbH.
- Elasticsearch: used under the AGPL-3.0 option of Elastic's licence. The template only references Elastic's official image.
- **OpenSanctions data: CC BY-NC 4.0, free for non-commercial use only.** Business use needs a licence from OpenSanctions (https://www.opensanctions.org/licensing/). You are responsible for using the data within its licence.
