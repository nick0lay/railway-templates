# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a collection of curated Railway templates for deploying self-hosted tools. Templates are pre-configured multi-service deployments with authentication and best practices for the Railway platform.

## Repository Structure

```
railway-templates/
└── solutions/           # Multi-service deployment solutions
    └── <solution-name>/
        ├── README.md    # User-facing documentation with architecture, setup, and usage
        ├── TEMPLATE.md  # Railway template marketplace description
        └── img/         # Screenshots for documentation
```

## Template Architecture Pattern

Templates follow a consistent pattern:
- **Internal service**: The main application (e.g., BentoPDF) runs on Railway's private network, not exposed to the internet
- **Auth gateway**: Caddy reverse proxy handles authentication and is the only public-facing service
- **Service isolation**: Traffic flows: Internet → Caddy (auth) → Internal service

## Adding New Templates

Each solution requires:
1. `README.md`: Technical documentation including architecture diagram, environment variables, and setup instructions
2. `TEMPLATE.md`: Marketing-friendly description for Railway's template marketplace

## Conventions

- Environment variables that are auto-configured should be clearly marked "Do Not Change" in documentation
- Include ASCII architecture diagrams showing service relationships and ports
- Document both user-configurable and auto-configured environment variables separately
- Screenshots go in `img/` subdirectory within each solution
