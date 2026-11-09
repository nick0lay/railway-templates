# Deploy and Host Temporal 1.32 on Railway

Temporal is an open-source durable execution platform. You write workflows as ordinary code in Go, Java, TypeScript, Python, .NET, PHP or Ruby, and Temporal keeps their state, retries failed steps and resumes after crashes or deploys. Use it for background jobs, long-running processes, sagas, AI agents and scheduled tasks.

## About Hosting Temporal

A self-hosted Temporal cluster needs a database with two schemas (history and visibility), the schema created and upgraded with Temporal's own tool before the server starts, a default namespace, the server itself, and the Web UI. The official all-in-one `auto-setup` image stopped at Temporal 1.29, so newer versions need the schema step done separately. The Temporal UI has no login of its own except OIDC, so a public UI without a gateway lets anyone see and terminate your workflows.

This template runs Temporal 1.32 from official images on PostgreSQL, with no Elasticsearch. An Admin Tools service creates and upgrades the schema on every deploy and creates the default namespace. The server waits for it, then starts. The Temporal UI sits behind a login, and the server and database are private.

## Common Use Cases

- Durable background jobs and task queues that survive restarts and deploys
- Long-running business processes: orders, payments, onboarding, approvals
- AI agent and LLM pipelines with retries, timeouts and human-in-the-loop steps
- Cron-style schedules with history, pause and backfill
- Sagas and multi-service transactions with compensation steps
- A Temporal backend for apps that need one, such as Postiz or PostHog

## Dependencies for Temporal Hosting

- PostgreSQL 17 (history and visibility)
- Temporal Admin Tools 1.32 (schema setup, temporal CLI)
- Temporal UI 2.58
- Caddy 2.11 (login gateway)

### Deployment Dependencies

- Temporal server: https://github.com/temporalio/temporal
- Temporal UI: https://github.com/temporalio/ui
- Docs for self-hosted Temporal: https://docs.temporal.io/self-hosted-guide
- SDKs: https://docs.temporal.io/develop

### Implementation Details

**What you set:** nothing. Optionally `AUTH_USERNAME` (default `admin`) on the Gateway service.

**After deploy:**

1. Open the Gateway service's URL and log in with `AUTH_USERNAME` and the generated `AUTH_PASSWORD` (Gateway → Variables). The UI opens the `default` namespace.
2. Connect your workers and clients from services in the same Railway project to the frontend over the private network:

```
TEMPORAL_ADDRESS=${{Temporal.RAILWAY_PRIVATE_DOMAIN}}:7233
TEMPORAL_NAMESPACE=default
```

3. For the `temporal` CLI, open a shell on the Admin Tools service (`railway ssh`); `TEMPORAL_ADDRESS` is already set there:

```
temporal operator namespace list
temporal workflow list
```

**This template:**

- Runs Temporal 1.32 on official `temporalio/server` and `temporalio/admin-tools` images, not a custom image
- Creates and upgrades the history and visibility schemas automatically on every deploy, so a tag bump upgrades the database before the new server starts
- Creates the `default` namespace (72h retention, configurable)
- Uses PostgreSQL for visibility (workflow search), so no Elasticsearch is needed
- Protects the Temporal UI with a login (HTTP basic auth); the UI service itself is private
- Keeps the gRPC frontend and the database on the private network
- Pins every image version

**Notes:** the frontend has no authentication (no mTLS or JWT in this template), so keep it private. Only add a TCP proxy to the Temporal service on port 7233 if you need workers outside Railway, and know that anyone with the address can then use the cluster. Admin Tools must stay deployed: the server waits for it on startup. `NUM_HISTORY_SHARDS` (4) is fixed when the cluster is first created.

## Why Deploy Temporal on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Temporal on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
