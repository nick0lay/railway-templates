# Deploy and Host Yente 5.5 + Elasticsearch on Railway

Yente is the open-source screening API from OpenSanctions. Send it a person or a company and it scores them against global sanctions lists, politically exposed persons (PEPs), wanted lists and other risk data. This template runs Yente 5.5.1 with its Elasticsearch index, both private, behind a bearer-token proxy.

**Data licence:** Yente's code is MIT, but the OpenSanctions data is free only for non-commercial use (CC BY-NC 4.0). Business use, including screening your own customers, needs a data licence from OpenSanctions. Making sure your use is covered is your responsibility.

## About Hosting Yente 5.5 + Elasticsearch

Yente needs an Elasticsearch index, a manifest that tells it which data to load, and a schedule that keeps the data current. On the first start it downloads the OpenSanctions data and indexes it; after that it applies new releases every hour without downtime. Yente has no authentication of its own, so it must not be public.

In this template Yente and Elasticsearch have no public domain. A Caddy proxy is the only public service and requires a generated bearer token on every request. Elasticsearch runs with security on, a password, a volume, and the settings Railway needs (single node, no mmap, IPv6). The index survives redeploys, so Yente answers right away after a restart.

## Common Use Cases

- KYC and onboarding checks: screen new customers, suppliers or merchants against sanctions and PEP lists
- Payment and payout screening in a fintech, marketplace or crypto app
- Batch screening of an existing customer base (up to 100 queries per request)
- Name search for compliance and investigations tools
- A screening step in workflow tools such as n8n, or in fraud and AML engines

## Dependencies for Yente 5.5 + Elasticsearch Hosting

- Yente 5.5.1 (`ghcr.io/opensanctions/yente`)
- Elasticsearch 9.5.6 (`elastic/elasticsearch`)
- Caddy 2.11.9 as the token proxy
- OpenSanctions data, downloaded at runtime from data.opensanctions.org

### Deployment Dependencies

- Yente on GitHub: https://github.com/opensanctions/yente
- Yente docs: https://www.opensanctions.org/docs/yente/
- API reference: https://www.opensanctions.org/docs/api/
- Matching guide: https://www.opensanctions.org/docs/api/matching/
- Datasets and scopes: https://www.opensanctions.org/datasets/
- Data licensing: https://www.opensanctions.org/licensing/

### Implementation Details

**What you set:** nothing. Tokens and passwords are generated. Optionally choose a smaller dataset with `OPENSANCTIONS_SCOPE`.

**After deploy:**

1. Copy `PUBLIC_URL` and `PROXY_TOKEN` from the Token Proxy service's Variables.
2. Wait for the first index. `GET /readyz` returns 503 while Yente indexes and 200 when it is done: about 20 minutes for the full `default` collection (3.9M entities), about 2 minutes for `sanctions`.
3. Screen a person:

```bash
curl -X POST https://<domain>/match/default \
  -H "Authorization: Bearer <PROXY_TOKEN>" -H "Content-Type: application/json" \
  -d '{"queries": {"q1": {"schema": "Person",
        "properties": {"name": ["Vladimir Putin"], "birthDate": ["1952-10-07"]}}}}'
```

Each result has a `score`, a `match` flag and topics such as `sanction` or `role.pep`. Text search: `GET /search/default?q=<name>`. Services in the same project can use `${{Yente.PRIVATE_URL}}` without the token.

**Choosing the dataset (`OPENSANCTIONS_SCOPE`):**

- `default` (template default): the full collection with sanctions, PEPs, crime and debarment lists. Measured on Railway: about 20 minutes to index, Elasticsearch about 3.3 to 4.1 GB RAM idle with a 2 GB heap (5.8 GB peak while indexing), about 3 GB on disk.
- `sanctions`: sanctions lists only, 310k entities. About 2 minutes to index, about 2.5 GB RAM with `ES_HEAP_SIZE=1g`, 0.7 GB on disk.

The API paths use the scope: `/match/<scope>`, `/search/<scope>`.

**Disk:** the full index fits the default 5 GB volume, and so do the hourly updates. A full re-index (scope change, forced update, or a future Yente version with a new index format) briefly needs about 6.5 GB, so grow the volume on Pro first, or use `sanctions`.

**Commercial use:** with an OpenSanctions licence, put your delivery token in `OPENSANCTIONS_DELIVERY_TOKEN` and point the manifest (`YENTE_MANIFEST_YAML`) at `https://delivery.opensanctions.com/datasets/latest/index.json` with `auth_token: "$OPENSANCTIONS_DELIVERY_TOKEN"`. The README has the exact YAML.

**This template:**

- Pins Yente 5.5.1 and Elasticsearch 9.5.6
- Keeps Yente and Elasticsearch private; one public proxy with a generated 48-character bearer token
- Turns on Elasticsearch security with a generated password
- Writes Yente's manifest from a variable, since Railway can't mount files
- Waits for Elasticsearch before starting Yente, and uses Yente's `/healthz` for the healthcheck, so the long first index never fails a deploy
- Keeps the index on a volume: no re-index after a redeploy
- Updates the data every hour in the background
- Generates the `/updatez` token for forced re-indexes

**Notes:** Yente itself idles at about 0.6 GB RAM, the proxy at 0.02 GB. The browser docs page at `/` needs the token too; use the OpenSanctions docs or `/openapi.json`. Licences: Yente MIT, Elasticsearch AGPL-3.0 option, OpenSanctions data CC BY-NC 4.0 (non-commercial; business use needs a licence).

## Why Deploy Yente 5.5 + Elasticsearch on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Yente 5.5 + Elasticsearch on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
