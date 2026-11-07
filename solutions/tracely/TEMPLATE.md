# Deploy and Host Tracely on Railway

Tracely is open-source, trace-native CI/CD for AI agents. It collects your agents' production traces, scores them with evaluators, groups failures into clusters, freezes failing conversations into replayable regression tests, and blocks pull requests that make an agent worse.

## About Hosting Tracely

Tracely needs seven services: the API, a background worker, the web UI, Postgres with pgvector, ClickHouse for trace events, Redis as the job queue and MinIO for raw events. This template wires them together over Railway's private network. Only the web UI and the API are public: the UI asks for a login, and the API needs a login session or an ingest key. The first account you create owns the workspace, and later users join by invite. Database migrations run automatically when the API starts, and the worker waits for them to finish.

## Common Use Cases

- Grade production traces of LLM agents with LLM-as-a-judge and code evaluators
- Find recurring agent failures, grouped into clusters with explanations
- Turn failing conversations into regression tests and gate pull requests in CI
- Let a coding agent read traces and write evaluators through the built-in MCP endpoint

## Dependencies for Tracely Hosting

- Postgres with pgvector, ClickHouse, Redis and MinIO (all included)
- An OpenRouter API key for LLM-graded evaluators (optional; each workspace adds its own in Settings)

### Deployment Dependencies

- Tracely source: https://github.com/jwuthri-cloud/tracely-ai
- Python SDK: https://pypi.org/project/tracelyai-sdk/
- Documentation: https://doc.tracely-ai.com

### Implementation Details

After the deploy, open the **frontend** domain and create your account. Then create an ingest key under **Settings → API keys** and point the SDK at the **backend** domain:

```python
import tracely_sdk as tracely

tracely.init(endpoint="https://<backend-domain>", api_key="<ingest-key>", service_name="my-agent")
```

Any OTLP/HTTP exporter also works: send to `https://<backend-domain>/v1/traces` with `Authorization: Bearer <ingest-key>`.

How this template is set up:

- **Secure defaults.** Production mode, so the documented demo ingest key is never created. Email and password login, and sign-up closes after the first account.
- **Background jobs run.** The worker includes the scheduler, so monitors and the cleanup jobs run.
- **Pinned version.** Tracely publishes no images or releases, so the template builds a tested commit. To upgrade, change `TRACELY_REF` on the backend and redeploy.
- **Private data services.** Postgres, ClickHouse, Redis and MinIO have no public domain, and each keeps its data on a volume.

## Why Deploy Tracely on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Tracely on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
