# Deploy and Host PuppyGraph 1.18 + Postgres on Railway

PuppyGraph is a graph query engine that runs openCypher and Gremlin queries directly on your existing SQL tables, with no ETL and no separate graph database. This template runs the free PuppyGraph Developer edition next to a Postgres 18 database that already holds a demo graph, so your first graph query works right after deploy.

## About Hosting PuppyGraph 1.18 + Postgres

PuppyGraph needs a data source, a graph schema that maps tables to nodes and edges, a login, and a place to keep schemas and users. Out of the box the image uses a public default password, and its Gremlin and Bolt endpoints accept queries without any login. Its query engine also refuses to start when its storage has less than 5 GB free, more than a 5 GB Railway volume ever has.

This template sets all of that up. Postgres starts with the demo tables (people, software, who knows whom, who created what). PuppyGraph uploads a matching schema on its first start, signs in with a generated password, and requires that login on the web UI, the REST API, Gremlin and Bolt. PuppyGraph's own storage stays on the container disk; the template saves your graph schema, with its data source connections, to a volume every 30 seconds and loads it back on every start.

## Common Use Cases

- Query relational data in Postgres as a graph with openCypher or Gremlin, without copying it into a graph database
- Fraud rings, identity resolution, supply chain and network dependency analysis over existing tables
- Graph exploration and visualization in the PuppyGraph web UI
- Evaluating graph queries or GraphRAG retrieval over SQL data before choosing a graph stack

## Dependencies for PuppyGraph 1.18 + Postgres Hosting

- PuppyGraph 1.18.1 Developer edition (`puppygraph/puppygraph` image)
- PostgreSQL 18 with pgvector 0.8.7 (`pgvector/pgvector:0.8.7-pg18` image)

### Deployment Dependencies

- PuppyGraph: https://www.puppygraph.com/
- PuppyGraph docs: https://docs.puppygraph.com/
- Docker image: https://hub.docker.com/r/puppygraph/puppygraph
- PuppyGraph EULA: https://puppygraph.com/eula

### Implementation Details

**Licence:** the Developer edition is free under the PuppyQuery EULA for evaluation, internal demonstration, testing and other non-production use. It runs as a single instance with up to 2 data sources. Deploying this template means you accept the EULA. For production, contact PuppyGraph about a commercial edition.

**What you set:** nothing. The password and secrets are generated.

**After deploy:**

1. Open `PUPPYGRAPH_URL` from the PuppyGraph service's Variables and sign in with `PUPPYGRAPH_USERNAME` (`puppygraph`) and `PUPPYGRAPH_PASSWORD`.
2. The demo schema is already loaded. In **Query**, run:

```
MATCH path = (p:person)-[:knows]->()-[:created]->()
WHERE p.name = 'marko'
RETURN path
```

It returns two paths: marko knows josh, who created lop and ripple.

3. From code, use the REST API with basic auth, or connect a Neo4j driver or Gremlin client from another service in the project:

```
curl -u puppygraph:<password> -X POST https://<domain>/submitCypher \
  -H 'Content-Type: application/json' \
  -d '{"query":"MATCH (p:person) RETURN p.name"}'
```

```
PUPPYGRAPH_BOLT=${{PuppyGraph.BOLT_URL}}
PUPPYGRAPH_GREMLIN=${{PuppyGraph.GREMLIN_URL}}
```

4. To graph your own data, create tables in the Postgres service (or connect another source) and build or upload a schema in **Schema**. It is saved to the volume within 30 seconds and survives redeploys. The demo schema is used only on the very first start.

**This template:**

- Pins PuppyGraph 1.18.1 and pgvector Postgres 18
- Generates the login password, the token signing key and the internal cluster key (the image defaults are public)
- Requires the login on Gremlin and Bolt too, which the image leaves open by default
- Keeps Postgres, Gremlin and Bolt private. Only the web UI and REST API are public, and they need the login
- Preloads demo tables and a schema so the first query works without setup
- Keeps your schema and data source connections on a volume, restored on every redeploy (extra users and roles made in the UI are not kept)

**Resources:** PuppyGraph's vendor minimum is 8 GB RAM for dev and test. Measured on Railway: PuppyGraph idles at 2.9 to 3.4 GB and Postgres at about 0.1 GB, within the 8 GB a Railway service gets on Hobby.

## Why Deploy PuppyGraph 1.18 + Postgres on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying PuppyGraph 1.18 + Postgres on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
