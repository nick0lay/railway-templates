# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a collection of curated Railway templates for deploying self-hosted tools. Templates are pre-configured multi-service deployments with authentication and best practices for the Railway platform.

## Repository Structure

```
railway-templates/
└── solutions/
    └── <solution-name>/
        ├── README.md       # Technical docs: architecture, env vars, setup
        ├── TEMPLATE.md     # Railway marketplace description
        ├── img/            # Screenshots
        └── <service>/      # Custom service code (Dockerfiles, scripts)
```

## Template Architecture Patterns

### Pattern 1: External Auth Gateway
For apps without built-in auth. Caddy proxy is the only public service.
```
Internet → Caddy (auth, public) → App (private)
```
Example: `bentopdf-caddy`

### Pattern 2: Built-in Auth
For apps with native authentication. App is directly public.
```
Internet → App (public) → Backend services (private)
```
Example: `nocodb-minio`

### Sidecar Pattern
One-time initialization services that auto-disable after setup:
- Run initialization logic (create buckets, seed data, etc.)
- Track state in JSON file to survive restarts
- Auto-disable via `IS_ACTIVE` env var after N healthy cycles
- Use Python + Dockerfile pattern from `nocodb-minio/minio-init/`

## Adding New Templates

Each solution requires:
1. `README.md`: Include ASCII architecture diagram, services table, env vars (split user-configurable vs auto-configured), troubleshooting section
2. `TEMPLATE.md`: Marketing copy for Railway's template marketplace

## Documentation Conventions

**Environment Variables Tables:**
- Separate "User-Configurable" and "Auto-Configured (Do Not Change)" sections
- For auto-configured vars, explain what they connect to and why changing breaks things
- Use Railway variable references: `${{ServiceName.VAR_NAME}}`

**Architecture Diagrams:**
- Show public vs private services clearly
- Include port numbers
- Show data flow direction with arrows

**Services Table Format:**
| Service | Source | Role |
|---------|--------|------|
| App | `image:tag` or `path/Dockerfile` | Description (public/private) |

## Railway-Specific Notes

- Internal services use `.railway.internal` hostnames
- Railway volumes persist data across redeploys
- Use Railway plugins for PostgreSQL/Redis when possible
- Custom services need Dockerfiles with explicit build context
