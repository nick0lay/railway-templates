# Deploy and Host Elasticsearch + Kibana on Railway

Elasticsearch is a distributed search and analytics engine for full-text search, logs, metrics and vector search. Kibana is its web UI: explore data in Discover, build dashboards, manage indices and send queries from the Dev Tools console. This template runs Elasticsearch 9 and Kibana 9 with security on.

## About Hosting Elasticsearch + Kibana

Elasticsearch needs a persistent volume, a sized Java heap and, normally, a raised `vm.max_map_count` kernel setting, which Railway can't change. With security on, Kibana also needs the built-in `kibana_system` user and its own password, which you usually set by hand after the first start. Many quick setups skip all this by turning security off and exposing Elasticsearch publicly, leaving the data open to anyone.

This template keeps Elasticsearch private and password-protected, makes Kibana the only public service with its login page, and sets up the Kibana connection automatically.

## Common Use Cases

- Full-text and vector search backend for your apps
- Log and event analytics with Kibana dashboards
- Exploring and visualizing JSON or CSV data
- Prototyping search relevance and queries in the Dev Tools console
- A private search cluster for other services in your Railway project

## Dependencies for Elasticsearch + Kibana Hosting

- Elasticsearch 9.5 (single node, volume)
- Kibana 9.5

### Deployment Dependencies

- Elasticsearch: https://github.com/elastic/elasticsearch
- Kibana: https://github.com/elastic/kibana
- Documentation: https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-with-docker
- Images: https://hub.docker.com/r/elastic/elasticsearch, https://hub.docker.com/r/elastic/kibana

### Implementation Details

**What you set:** nothing required. Optionally `ES_HEAP_SIZE` (default `1g`).

**After deploy:**

1. Open the Kibana URL (the first start takes about two minutes).
2. Log in as `elastic` with the generated `ELASTIC_PASSWORD` (also shown on the Kibana service as `LOGIN_PASSWORD`).
3. Create users, roles and API keys for your apps under Stack Management → Security.

Other services in the project connect with `${{Elasticsearch.ELASTICSEARCH_URL}}` and a username and password or an API key.

**This template:**

- Turns on Elasticsearch security with a generated `elastic` password
- Keeps Elasticsearch private: no public domain, no TCP proxy
- Sets the `kibana_system` password automatically on every start, so Kibana connects with no manual step
- Runs without `vm.max_map_count` (`node.store.allow_mmap=false`, single node)
- Sizes the Java heap from one variable, `ES_HEAP_SIZE`
- Fixes volume ownership, then runs Elasticsearch as a non-root user
- Generates Kibana's encryption keys, turns off telemetry and checks health on `/api/status`
- Pins Elasticsearch and Kibana 9.5.6

**Notes:** the stack needs a few GB of RAM, so use a paid plan. Hobby volumes are 5 GB; Elasticsearch makes indices read-only when the disk is 95% full. Upgrade by changing both image tags to the same version, Elasticsearch first. To reach Elasticsearch from outside Railway, generate a domain for port 9200 (HTTPS, password still required). Elastic's images are under the Elastic License 2.0.

## Why Deploy Elasticsearch + Kibana on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Elasticsearch + Kibana on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
