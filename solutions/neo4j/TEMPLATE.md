# Deploy and Host Neo4j 2026.10 Community on Railway

Neo4j is the most widely used graph database. You store data as nodes and relationships and query it with Cypher. It is used for knowledge graphs, GraphRAG and AI agent memory, recommendations, fraud detection and network analysis. This template runs Neo4j Community 2026.10 with APOC, Neo4j Browser over HTTPS, and Bolt for your drivers.

## About Hosting Neo4j 2026.10 Community

A Neo4j server needs a persistent volume, a password, and memory limits. Without explicit limits, the JVM sizes its heap and page cache from the container limit, not from your data. Drivers need a Bolt port they can reach, and Neo4j Browser needs a connection that works over HTTPS. Many Neo4j templates still run with `NEO4J_AUTH=none`, use the `latest` tag, or expose Browser with no working connection.

This template runs the official `neo4j:2026.10.1-community` image with a volume at `/data`, a generated password, the APOC core plugin, and a heap and page cache sized for the Hobby plan. Neo4j Browser and the HTTP Query API are on the public HTTPS domain, and both ask for the password. Drivers connect over Railway's private network, or from outside through a password-protected TCP proxy. Railway's TCP proxy forwards raw TCP without encryption, so the template creates a self-signed certificate on the first start and requires TLS on Bolt.

## Common Use Cases

- Knowledge graphs and GraphRAG backends for LightRAG, Graphiti, LangChain, LlamaIndex and neo4j-graphrag
- Long-term memory for AI agents, and MCP servers such as mcp-neo4j-cypher
- Recommendation engines, fraud and identity graphs, and network or IT dependency maps
- Learning Cypher, or a Neo4j development and staging database next to your app on Railway

## Dependencies for Neo4j 2026.10 Community Hosting

- Neo4j 2026.10.1 Community Edition (official `neo4j` image)
- APOC core 2026.10.1 (bundled in the image)

### Deployment Dependencies

- Neo4j: https://neo4j.com/
- Neo4j Docker image: https://hub.docker.com/_/neo4j
- Neo4j Operations Manual (Docker): https://neo4j.com/docs/operations-manual/current/docker/
- APOC: https://neo4j.com/docs/apoc/current/

### Implementation Details

**What you set:** nothing. The password is generated.

**After deploy:**

1. Open `BROWSER_URL` from the Neo4j service's Variables. It opens Neo4j Browser with the connection form filled in (protocol `https://`, port 443). Log in as `neo4j` with `DB_PASSWORD`.
2. From another service in this project, set:

```
NEO4J_URI=${{Neo4j.BOLT_URL}}
NEO4J_USERNAME=${{Neo4j.DB_USER}}
NEO4J_PASSWORD=${{Neo4j.DB_PASSWORD}}
```

3. From outside Railway, use `BOLT_PUBLIC_URL` (for example `bolt+ssc://<proxy-domain>:<port>`) with user `neo4j` and `DB_PASSWORD`. Use `bolt+ssc://` or `neo4j+ssc://` (TLS with a self-signed certificate); plain `bolt://` is refused:

```python
from neo4j import GraphDatabase
driver = GraphDatabase.driver("bolt+ssc://<proxy-domain>:<port>", auth=("neo4j", "<DB_PASSWORD>"))
```

**This template:**

- Uses the official Neo4j 2026.10.1 Community image, pinned
- Generates a 32-character password, so the database is never open
- Keeps databases on a volume, so your graph survives redeploys
- Loads APOC from the image itself, with no download at start
- Sets heap (512 MB) and page cache (256 MB) explicitly, adjustable with variables
- Serves Neo4j Browser over HTTPS, connected through the HTTP Query API, so no extra port is needed
- Encrypts Bolt with TLS, on the private network and through the TCP proxy. The self-signed certificate is created on the first start and kept on the volume
- Listens on IPv6, so services on Railway's private network reach Bolt
- Offers ready-made variables (`BOLT_URL`, `DB_USER`, `DB_PASSWORD`, `HTTP_URL`) for your apps

**Notes:** the password is set on the first start. To change it later, run `ALTER CURRENT USER SET PASSWORD FROM '<old>' TO '<new>'` in Browser, then update `DB_PASSWORD`. Set `NEO4J_server_bolt_tls__level=OPTIONAL` if a client can't use TLS. Remove the TCP proxy if you don't need outside access. Neo4j idles at about 1.3 to 1.7 GB of RAM with these settings. Community Edition is a single server (no clustering, no role-based access control).

## Why Deploy Neo4j 2026.10 Community on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Neo4j 2026.10 Community on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
