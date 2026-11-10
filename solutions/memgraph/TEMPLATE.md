# Deploy and Host Memgraph 3.14 + Lab on Railway

Memgraph is an in-memory graph database that speaks Cypher and the Bolt protocol, so Neo4j drivers and tools work with it. This template runs Memgraph 3.14 with MAGE, a library of graph algorithms such as PageRank, community detection and shortest paths, plus Memgraph Lab, the web IDE for writing queries and seeing the graph.

## About Hosting Memgraph 3.14 + Lab

Memgraph keeps the whole graph in RAM and writes snapshots and a write-ahead log to disk, so it needs a persistent volume, a memory limit and a password. The Docker image runs as a non-root user, which can't write to a fresh Railway volume without help, and Railway's TCP proxy forwards raw TCP with no encryption. Most Memgraph templates skip some of this.

This template runs `memgraph/memgraph-mage:3.14.0` with a volume, a generated user and password, and a memory limit you can change. On the first start it creates a self-signed certificate and turns on Bolt TLS, so drivers connect with `bolt+ssc://` over Railway's private network or from outside through the TCP proxy. Memgraph Lab is on a public HTTPS domain. It asks for the Memgraph user and password before it shows anything, and it connects to Memgraph over the private network.

## Common Use Cases

- Real-time graph analytics with MAGE: PageRank, community detection, centrality, shortest paths and link prediction
- Knowledge graphs and GraphRAG backends for LightRAG, LangChain and LlamaIndex, with Memgraph's vector search
- Fraud detection, recommendations, network and IT dependency maps, and streaming graphs from Kafka
- A fast, Neo4j-compatible Cypher database for development and staging next to your app on Railway

## Dependencies for Memgraph 3.14 + Lab Hosting

- Memgraph 3.14.0 with MAGE (`memgraph/memgraph-mage` image)
- Memgraph Lab 3.14.2 (`memgraph/lab` image)

### Deployment Dependencies

- Memgraph: https://memgraph.com/
- Memgraph documentation: https://memgraph.com/docs
- MAGE algorithms: https://memgraph.com/docs/advanced-algorithms/available-algorithms
- Memgraph Lab: https://memgraph.com/docs/memgraph-lab
- Licences: https://memgraph.com/legal

### Implementation Details

**What you set:** nothing. The user is `memgraph` and the password is generated.

**After deploy:**

1. Open the Memgraph Lab domain and choose **Memgraph instance**. Host, port and **Encrypted** are already filled in. Under Authentication choose **Username/password** and log in as `memgraph` with `MEMGRAPH_PASSWORD` from the Memgraph service's Variables.
2. From another service in this project, set:

```
MEMGRAPH_URI=${{Memgraph.BOLT_URL}}
MEMGRAPH_USERNAME=${{Memgraph.DB_USER}}
MEMGRAPH_PASSWORD=${{Memgraph.DB_PASSWORD}}
```

3. From outside Railway, use `BOLT_PUBLIC_URL` with any Neo4j driver:

```python
from neo4j import GraphDatabase
driver = GraphDatabase.driver("bolt+ssc://<proxy-domain>:<port>", auth=("memgraph", "<MEMGRAPH_PASSWORD>"))
driver.execute_query("CALL pagerank.get() YIELD node, rank RETURN node, rank LIMIT 5")
```

**This template:**

- Pins Memgraph 3.14.0 with MAGE and Lab 3.14.2
- Generates a 32-character password, so the database is never open
- Keeps snapshots and the write-ahead log on a volume, so your graph survives redeploys
- Sets a memory limit (2048 MiB by default), so a large query fails cleanly instead of the service running out of memory
- Encrypts Bolt with TLS on the private network and through the TCP proxy. The self-signed certificate is created on the first start and kept on the volume
- Puts Lab on HTTPS behind the Memgraph login, connected to Memgraph over the private network
- Listens on IPv6, so services on Railway's private network reach Bolt
- Offers ready-made variables (`BOLT_URL`, `DB_USER`, `DB_PASSWORD`) for your apps

**Notes:** use `bolt+ssc://`. Plain `bolt://` is refused, and `neo4j://` routing schemes don't work on a single Memgraph server. The user and password are set on the first start; change the password later with `SET PASSWORD` in Cypher, then update `MEMGRAPH_PASSWORD`. Memgraph Community is under the Business Source License 1.1 with a grant for your own internal business use, not for offering it as a database service. Memgraph Lab is free under its own user licence agreement, meant for development, testing and evaluation. Remove the TCP proxy if you don't need outside access.

## Why Deploy Memgraph 3.14 + Lab on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Memgraph 3.14 + Lab on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
