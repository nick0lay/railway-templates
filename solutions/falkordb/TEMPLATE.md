# Deploy and Host FalkorDB 6.0.4 on Railway

FalkorDB is a fast graph database built as a Redis module. You store data as nodes and relationships and query it with Cypher. It is popular as the knowledge graph behind GraphRAG and AI agent memory (Graphiti, the FalkorDB GraphRAG SDK, LangChain, LlamaIndex), and it also does vector search. This template runs FalkorDB 6.0.4 (the new Rust engine) with the FalkorDB Browser behind a login and a TLS-encrypted, password-protected port for your clients.

## About Hosting FalkorDB 6.0.4

FalkorDB speaks the Redis protocol, so it needs a password, a persistent volume, and a port your clients can reach. Railway's TCP proxy forwards raw TCP without encryption, so a plain Redis port on the proxy sends the password and your data across the internet in cleartext. Other FalkorDB templates run the unpinned `latest` tag, which jumped from the 4.x C engine to the 6.0 Rust engine in September 2026, and keep data only in Redis's default snapshots.

This template runs the official `falkordb/falkordb:6.0.4` image with a generated password, a volume, and append-only persistence (AOF, synced every second, plus snapshots). On the first start it creates a self-signed certificate on the volume, so the TCP proxy accepts TLS (`rediss://`) only. Services in the same project use the private network. The FalkorDB Browser, bundled in the image, is on the public HTTPS domain and asks for the database password.

## Common Use Cases

- Knowledge graph for GraphRAG: Graphiti, FalkorDB GraphRAG SDK, LangChain, LlamaIndex, Cognee
- Long-term memory for AI agents, and MCP servers that store a graph
- Graph plus vector search in one database, with low latency for real-time apps
- Learning Cypher, or a FalkorDB development and staging database next to your app on Railway

## Dependencies for FalkorDB 6.0.4 Hosting

- FalkorDB 6.0.4 (official `falkordb/falkordb` image, Redis 8 with the FalkorDB module)
- FalkorDB Browser 2.7.3 (bundled in the same image)

### Deployment Dependencies

- FalkorDB: https://www.falkordb.com/
- FalkorDB on GitHub: https://github.com/FalkorDB/FalkorDB
- Docker image: https://hub.docker.com/r/falkordb/falkordb
- FalkorDB Browser: https://github.com/FalkorDB/falkordb-browser
- Docs: https://docs.falkordb.com/

### Implementation Details

**What you set:** nothing. The password and the Browser secrets are generated.

**After deploy:**

1. Open `BROWSER_URL` from the FalkorDB service's Variables. The login form is filled in with host `localhost`, port `6379` and user `default`. Enter `DB_PASSWORD`.
2. From another service in this project, use the private network:

```
FALKORDB_URL=${{FalkorDB.PRIVATE_URL}}
FALKORDB_HOST=${{FalkorDB.PRIVATE_HOST}}
FALKORDB_PORT=6379
FALKORDB_PASSWORD=${{FalkorDB.DB_PASSWORD}}
```

3. From outside Railway, use `PUBLIC_URL` (`rediss://default:<password>@<proxy-domain>:<port>`). It is TLS only, with a self-signed certificate, so turn off certificate verification or compare the fingerprint printed in the deploy log:

```python
from falkordb import FalkorDB
db = FalkorDB(host="<proxy-domain>", port=<port>, password="<DB_PASSWORD>",
              ssl=True, ssl_cert_reqs="none")
g = db.select_graph("social")
g.query("CREATE (:Person {name:'Ada'})-[:KNOWS]->(:Person {name:'Charles'})")
```

With redis-cli: `redis-cli --tls --insecure -u "<PUBLIC_URL>" GRAPH.LIST`.

**This template:**

- Uses the official FalkorDB 6.0.4 image, pinned
- Generates a 32-character password. Every connection needs it, including the Browser
- Keeps data on a volume with AOF and snapshots, so your graphs survive redeploys
- Encrypts the TCP proxy with TLS. The self-signed certificate is created on the first start and kept on the volume, and plaintext is refused on the proxy
- Serves the FalkorDB Browser over HTTPS behind its login, with generated session secrets
- Listens on IPv6 and IPv4, so services on Railway's private network reach it
- Offers ready-made variables (`PRIVATE_URL`, `PUBLIC_URL`, `DB_PASSWORD`) for your apps

**Notes:** the private network port (6379) is plaintext, like Railway's own Redis; it is reachable only from your project. To change the password, edit `DB_PASSWORD` and redeploy. Remove the TCP proxy if you don't need outside access. FalkorDB idles at about 0.1 to 0.2 GB of RAM including the Browser; memory grows with your graphs, because FalkorDB keeps them in RAM. FalkorDB is licensed under the Server Side Public License (SSPL v1): running it for your own applications is fine; offering FalkorDB itself as a service to others has conditions.

## Why Deploy FalkorDB 6.0.4 on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying FalkorDB 6.0.4 on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
