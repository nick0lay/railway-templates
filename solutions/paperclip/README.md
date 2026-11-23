# Paperclip

Self-hosted [Paperclip](https://github.com/paperclipai/paperclip) on Railway: an open-source app for running AI agents as a company, with an org chart, goals, tasks, budgets and approvals. This template runs the official image at a pinned version with PostgreSQL 18, creates your owner account at deploy, keeps sign-ups closed and turns off the first-visitor "claim this instance" page.

## Architecture

```
                      You (browser) / Paperclip CLI
                               │ HTTPS
                               ▼
┌──────────────────────────────────────────────────────────┐
│ Railway project                                          │
│                                                          │
│  Paperclip :3100 (public)                                │
│    board UI + API, login required, /api/health           │
│    runs agents (Claude Code, Codex, OpenCode, ...)       │
│    volume /paperclip: agent workspaces, instance files   │
│        │                                                 │
│        ▼                                                 │
│  Postgres :5432 (private, volume)                        │
│    companies, agents, tasks, runs, users                 │
└──────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Paperclip | `ghcr.io/paperclipai/paperclip:2026.1117.0` | Board UI, API and agent runtime (public). Migrates the database on start, healthcheck `/api/health`, volume `/paperclip` |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | All Paperclip data (private, volume, no TCP proxy) |

## What this template does differently

- **Owner account created at deploy.** Paperclip has no setting for a first admin. In private mode, the first person who signs up and opens the setup page claims the instance, and many Railway deployments run that mode on a public domain. This template creates the owner (instance admin) on first start from `OWNER_EMAIL` and a generated `OWNER_PASSWORD`. The setup step runs next to the server on every start and does nothing once an instance admin exists.
- **Public mode, no claim page.** `PAPERCLIP_DEPLOYMENT_MODE=authenticated` with `PAPERCLIP_DEPLOYMENT_EXPOSURE=public`: login everywhere, an explicit public URL, rate-limited login, and no browser claim of the instance.
- **Sign-ups closed.** `PAPERCLIP_AUTH_DISABLE_SIGN_UP=true`. Open them briefly when you invite a teammate (see "After deploy").
- **Generated secrets.** `BETTER_AUTH_SECRET` signs sessions; `PAPERCLIP_SECRETS_MASTER_KEY` encrypts the provider keys and other secrets you store in Paperclip. Both are fixed in variables, so they survive a lost volume.
- **Pinned version.** Paperclip 2026.1117.0 and PostgreSQL 18 instead of `latest`. Paperclip migrates the database on start (`PAPERCLIP_MIGRATION_AUTO_APPLY=true`), so you upgrade when you choose.
- **State on volumes.** Agent workspaces and instance files live on the `/paperclip` volume (the image's entrypoint fixes its ownership), the database on the Postgres volume. Postgres is private.
- **Healthcheck and restart policy.** Railway waits for `/api/health` before it switches traffic, and restarts a crashed service.
- **Privacy default.** Paperclip's anonymous usage telemetry is off (`PAPERCLIP_TELEMETRY_DISABLED=1`).

## After deploy

1. Open the `Paperclip` URL and sign in with `OWNER_EMAIL` and the `OWNER_PASSWORD` variable from the `Paperclip` service.
2. Create your company and its goal, then hire your first agent (for example a CEO agent on Claude Code).
3. Give the agent a provider key: set `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` on the service, or add a key in the agent's settings. Assign it a task and watch the run.
4. To add a teammate: set `PAPERCLIP_AUTH_DISABLE_SIGN_UP=false` (the service redeploys), invite them from the company settings, and set it back to `true` after they have signed up.

## Variables

### User-configurable

| Variable | Default | Notes |
|---|---|---|
| `OWNER_EMAIL` | `admin@example.com` | Email of the owner (instance admin) created on first start. Set your own before deploying |
| `OWNER_PASSWORD` | generated | Read it after deploy. Used only when the owner is created; later changes have no effect |
| `OWNER_NAME` | `Owner` | Display name of the owner |
| `PAPERCLIP_AUTH_DISABLE_SIGN_UP` | `true` | `false` lets anyone with the URL create an account. Open it only while inviting someone |
| `ANTHROPIC_API_KEY` | empty | Optional. Default key for Claude Code agents |
| `OPENAI_API_KEY` | empty | Optional. Default key for Codex agents |
| `PAPERCLIP_TELEMETRY_DISABLED` | `1` | Set `0` to send Paperclip's anonymous usage telemetry |
| `PAPERCLIP_PUBLIC_URL`, `PAPERCLIP_ALLOWED_HOSTNAMES` | Railway domain | Change both when you add a custom domain |

Paperclip has more options (S3 storage, database backups, heartbeat scheduler); see the upstream [docs](https://github.com/paperclipai/paperclip/tree/master/doc).

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `BETTER_AUTH_SECRET` | generated | Signs login sessions. Changing it signs everyone out |
| `PAPERCLIP_SECRETS_MASTER_KEY` | generated | Encrypts stored secrets. **Never change it after the first deploy**, or they become unreadable |
| `PAPERCLIP_DEPLOYMENT_MODE`, `PAPERCLIP_DEPLOYMENT_EXPOSURE` | `authenticated`, `public` | Login required, no first-visitor claim |
| `PAPERCLIP_MIGRATION_AUTO_APPLY` | `true` | Applies migrations on start, also after upgrades |
| `PAPERCLIP_START_SH`, `PAPERCLIP_OWNER_SETUP_MJS` | scripts | The start command runs the server and the owner setup. Later starts log `owner-setup: skipped: an instance admin already exists` |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Private network |
| `PORT`, `HOST` | `3100`, `0.0.0.0` | |

## Custom domain

Add the domain to the `Paperclip` service, then set `PAPERCLIP_PUBLIC_URL=https://your-domain` and `PAPERCLIP_ALLOWED_HOSTNAMES=your-domain`.

## Upgrading

Change the image tag of `Paperclip` to a newer release (see [releases](https://github.com/paperclipai/paperclip/releases); image tags have no `v`, for example `2026.1117.0`). Paperclip migrates the database on start. Back up Postgres first; a migrated database can't go back to an older version.

## Limits of public mode

Paperclip's public mode turns off local stdio MCP servers and logging in to a provider account from inside the container. Use provider API keys and remote (HTTP) MCP servers. Agents run inside the Paperclip container, so scale its memory with the number of agents you run at once.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Sign-in fails with the generated password | The owner is created on the first start only. If you changed `OWNER_EMAIL` or `OWNER_PASSWORD` later, use the old values. Check the `Paperclip` logs for `owner-setup:` |
| A teammate can't sign up | Sign-ups are closed. Set `PAPERCLIP_AUTH_DISABLE_SIGN_UP=false` while they join |
| Login works but actions fail with an origin error | `PAPERCLIP_PUBLIC_URL` doesn't match the address in your browser (custom domain) |
| Agent runs fail at once | No provider key. Add one on the service or in the agent's settings |
| Stored secrets can't be decrypted | `PAPERCLIP_SECRETS_MASTER_KEY` was changed. Restore the old value |

## License

Paperclip is licensed under the [MIT License](https://github.com/paperclipai/paperclip/blob/master/LICENSE). You are responsible for what your agents do, the code and data they touch, and the provider costs they create.

## Testing

Tested on 2026-11-23 with Paperclip 2026.1117.0, deployed from the template draft into a throwaway Railway project: both services healthy, the database migrated on first start, and Postgres had no public domain or TCP proxy.

The owner was created as instance admin on first start (`owner-setup: created owner (instance admin)`), and health reported `bootstrapStatus: ready` in authenticated/public mode. Anonymous API requests were refused, the first-admin claim route returned 404, a sign-up request was rejected (`EMAIL_PASSWORD_SIGN_UP_DISABLED`) and that email could not sign in, and a wrong password was refused. The owner signed in with the generated password and created a company, an issue and an agent through the API, and all three were listed back. Idle memory was about 0.4 GB for Paperclip and 0.16 GB for Postgres.

After redeploying Paperclip and Postgres, the setup step skipped itself, the owner signed in with the same password, and the company, issue and agent were still there.

Not tested: real agent runs with a provider key, invitations, custom domains.
