# Sentry (self-hosted, errors-only)

Self-hosted [Sentry](https://github.com/getsentry/self-hosted) 26.10 on Railway: open-source error tracking with stack traces, issue grouping, releases and alerts, for every Sentry SDK. The official self-hosted release in its errors-only mode, grouped into 9 Railway services. The admin account is created on first start and public sign-up is off. Relay creates and registers its own credentials, so nothing has to be copied by hand. Only the gateway is public. Versions are pinned and tested.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/06r7Nf?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
     You (browser)                         Your apps (Sentry SDKs, DSN)
          │ HTTPS                                   │ HTTPS
          ▼                                         ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Railway project                                                      │
│                                                                      │
│   Gateway :8080 (nginx, the only public service)                     │
│     /api/<project>/store|envelope ──► Relay :3000                    │
│     everything else ─────────────────► Sentry :9000                  │
│                                          │                           │
│   Relay ── events ──► Kafka :9092 ◄──────┤ consumers, task workers   │
│     │  registers with Sentry             │                           │
│     ▼                                    ▼                           │
│   Sentry :9000  web UI + API, ingest consumers, post-processing,     │
│     │           task worker + scheduler, daily cleanup               │
│     │           volume /data (uploaded files)                        │
│     ├──► Postgres :5432  users, projects, issues, event payloads     │
│     ├──► Redis :6379     caches, buffers, rate limits                │
│     ├──► Taskbroker :50051  task queue (reads Kafka)                 │
│     └──► Snuba :1218  query API + consumers ──► ClickHouse :8123     │
│                         (errors, outcomes,      events, outcomes     │
│                          replacer, alerts)      volume               │
└──────────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Gateway | `nginx:1.31.8-alpine` | Public entry point: SDK event uploads go to Relay, everything else to Sentry (public) |
| Sentry | `ghcr.io/getsentry/sentry:26.10.1` | Web UI and API, event ingest consumers, post-processing, task worker and scheduler, daily cleanup; files on a volume (private) |
| Relay | `relay/Dockerfile` (`ghcr.io/getsentry/relay:26.10.1` plus busybox) | Receives events from SDKs, checks DSNs and rate limits, writes to Kafka (private, reached through the gateway) |
| Snuba | `ghcr.io/getsentry/snuba:26.10.1` | Sentry's query API and the consumers that write errors and outcomes into ClickHouse (private) |
| Taskbroker | `ghcr.io/getsentry/taskbroker:26.10.1` | Task queue between Kafka and Sentry's task workers; SQLite on a volume (private) |
| ClickHouse | `clickhouse/clickhouse-server:26.8` | Event search and stats storage, on a volume (private, password) |
| Kafka | `apache/kafka:4.4.0` | Event pipeline between Relay, Sentry and Snuba; one KRaft node on a volume (private) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:17` | Users, projects, issues and event payloads (private) |
| Redis | `redis:8.10` | Caches, buffers, quotas, digests (private, password) |

## What this template does differently

- **No one can claim your instance.** On a fresh install the first visitor can create the admin. This template creates the admin from `SENTRY_ADMIN_EMAIL` and a generated `SENTRY_ADMIN_PASSWORD` on first start, and turns off public sign-up. Teammates join by invitation.
- **No keys to copy.** Upstream asks you to generate a Relay keypair and register it with Sentry. Here Relay generates fresh credentials on every start, and Sentry trusts Relays that connect over Railway's private network. The public gateway returns 404 for Relay's registration endpoints, so nobody outside can register one.
- **9 services instead of about 20.** Sentry's web app, consumers and workers run in one service (they share the volume for uploaded files), and the Snuba API and its consumers run in another. If any process in these services stops, the service restarts as a whole.
- **No bind mounts or setup wizard.** Upstream's config files live in variables (`SENTRY_CONF_PY`, `RELAY_CONFIG_YML`, `TASKBROKER_CONFIG_YML`, `NGINX_CONF`) and are written at start. The public URL, admin email and secret key are set, so Sentry skips its setup page.
- **Upgrades migrate themselves.** Sentry runs `sentry upgrade` (Postgres migrations, Kafka topics) and Snuba runs `snuba bootstrap` (ClickHouse migrations) on every start.
- **Real client addresses.** The gateway passes the client IP from Railway's proxy, so Sentry's rate limits and audit log see real addresses.
- **Pinned versions** of every service; Sentry, Snuba, Relay and Taskbroker move together.

## After deploy

1. Wait for the first start: about 5 to 10 minutes while Sentry migrates Postgres and Snuba migrates ClickHouse. The Gateway shows 502 until Sentry is up.
2. Open the Gateway URL and log in with `SENTRY_ADMIN_EMAIL` and `SENTRY_ADMIN_PASSWORD` (Sentry service → Variables). Change the password in your account settings.
3. Create a project, pick your platform and copy the DSN into your app's Sentry SDK. The DSN points at the Gateway domain.
4. To invite teammates or get alert emails, set the `SENTRY_MAIL_*` variables (see below) and redeploy the Sentry service.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Sentry | `SENTRY_ADMIN_EMAIL` | `admin@example.com` | Email of the admin created on first start. You log in with it. Change it to your own before deploying |
| Sentry | `SENTRY_ADMIN_PASSWORD` | generated | Read it after deploy. Used only to create the admin; change the password in Sentry afterwards |
| Sentry | `SENTRY_URL_PREFIX` | `https://${{Gateway.RAILWAY_PUBLIC_DOMAIN}}` | Public URL used in DSNs, links and emails. Change it when you add a custom domain to the Gateway |
| Sentry | `SENTRY_EVENT_RETENTION_DAYS` | `90` | Events older than this are deleted daily. Set the same value on Snuba |
| Sentry | `SENTRY_MAIL_HOST`, `SENTRY_MAIL_PORT`, `SENTRY_MAIL_USERNAME`, `SENTRY_MAIL_PASSWORD`, `SENTRY_MAIL_FROM` | empty, `587` | SMTP for invitations and alerts. Empty host: email is off |
| Sentry | `SENTRY_TASKWORKER_CONCURRENCY` | `2` | Parallel background task processes. More is faster but uses more memory |
| Sentry | `SENTRY_WEB_WORKERS` | `2` | Web server processes |
| Kafka | `KAFKA_LOG_RETENTION_HOURS` | `24` | How long Kafka keeps messages; consumers read them within seconds |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Sentry | `SENTRY_SYSTEM_SECRET_KEY` | generated | Signs sessions and tokens. Changing it logs everyone out and breaks stored tokens |
| Sentry | `SENTRY_CONF_PY` | settings file | Sentry's `sentry.conf.py`, reading addresses and secrets from the variables |
| Sentry | `SENTRY_RUN_SH` | script | Waits for its dependencies, migrates, creates the admin, starts all Sentry processes |
| Sentry | `PG*`, `REDIS_*`, `KAFKA_BROKERS`, `SNUBA`, `TASKBROKER_HOST` | `${{Postgres...}}`, `${{Redis...}}`, ... | Private-network connections |
| Sentry | `SENTRY_INTERNAL_IPS` | `fc00::/7` | Relays from Railway's private network (IPv6) are trusted |
| Sentry, Kafka | `RAILWAY_RUN_UID` | `0` | Run as root so the service can write to its volume |
| Relay | `RELAY_UPSTREAM_URL`, `RELAY_KAFKA_BROKER_URL`, `RELAY_REDIS_URL` | private addresses | Where Relay registers and sends events |
| Relay | `RELAY_CONFIG_YML`, `RELAY_RUN_SH` | config, script | Writes the config, generates credentials, waits for Redis, Kafka and Sentry |
| Snuba | `CLICKHOUSE_*`, `DEFAULT_BROKERS`, `REDIS_*` | private addresses | ClickHouse, Kafka and Redis connections |
| Snuba | `SNUBA_RUN_PY` | script | Python start script (the Snuba image has no shell): migrations, API and consumers |
| Taskbroker | `TASKBROKER_CONFIG_YML`, `TASKBROKER_RUN_SH`, `TASKBROKER_*` | config, script | Topics and Kafka address; retries until Sentry has created the topics |
| ClickHouse | `CLICKHOUSE_USER`, `CLICKHOUSE_PASSWORD`, `CLICKHOUSE_DB` | `default`, generated, `default` | Snuba connects as `default` |
| ClickHouse | `RAILWAY_CH_SYSTEM_LOGS_XML` | config | Turns off noisy system log tables, adds Sentry's MergeTree settings, caps memory at 50% of RAM |
| Kafka | `KAFKA_RUN_SH` | script | One KRaft node, private plaintext listener, 50 MB messages |
| Gateway | `NGINX_CONF`, `NGINX_RUN_SH`, `SENTRY_HOST`, `RELAY_HOST` | config, script | Routing; hosts are resolved through Railway's private DNS on each request |

## Size and cost

Sentry is one of the heaviest self-hosted apps. The 9 services use about 5 GB of RAM right after start and settle at about 8 GB once warmed up (Sentry 3.5 GB, Snuba 2.8 GB, ClickHouse 1 GB, Kafka 0.6 GB, the rest under 0.2 GB each), at little CPU. Expect roughly $80 to $100 a month on Railway before you send much data. Postgres (event payloads) and ClickHouse grow with the events you keep; lower `SENTRY_EVENT_RETENTION_DAYS` to keep them small, and watch the volume sizes.

## Errors-only mode

Upstream's errors-only profile is the base of this template: error and crash events, issues, releases, alerts, user feedback on errors, and the stats page. Performance tracing, session replay, profiling, uptime and cron monitoring, logs and metrics need about 25 more containers (the `feature-complete` profile) and are not included. Source maps and debug files can be uploaded, but native symbolication (Symbolicator) is not included.

## Upgrading

Change the image tag of Sentry, Snuba and Taskbroker, and the `FROM` line in `relay/Dockerfile`, to the same new [self-hosted release](https://github.com/getsentry/self-hosted/releases) and redeploy. Sentry and Snuba run their migrations on start. Read the release notes first: self-hosted releases sometimes require a stop at a specific version.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Gateway returns 502 right after deploy | Sentry is still migrating (5 to 10 minutes on first start). Check the Sentry logs for `sentry-setup:` lines |
| SDK events don't show up | Check that the DSN uses the Gateway domain. Relay logs show rejected events; Sentry logs show the ingest consumers (`[events]`) |
| Events arrive but issues list is empty or search fails | Snuba writes them to ClickHouse; check the Snuba logs for `[errors]` consumer errors |
| Login says cookies are required | Open Sentry through the Gateway's HTTPS URL; the session cookie is HTTPS-only |
| Links and DSNs show the old domain after adding a custom domain | Set `SENTRY_URL_PREFIX` to the new URL and redeploy the Sentry service |
| A service keeps restarting | The Sentry and Snuba services restart when any of their processes stops; the logs show which one (`[name]` prefix) and why |

## License

Sentry, Snuba, Relay and Taskbroker are under the [Functional Source License](https://github.com/getsentry/sentry/blob/master/LICENSE.md) (FSL), which allows self-hosting for your own use; self-hosted's scripts are under the same terms. ClickHouse and Kafka are Apache-2.0, Postgres under the PostgreSQL license, Redis under its own licenses, nginx BSD-2-Clause.

## Testing

Tested on 2026-11-13 with Sentry, Snuba, Relay and Taskbroker 26.10.1, ClickHouse 26.8 and Kafka 4.4.0 in a throwaway Railway project. All 9 services deployed cleanly and Sentry answered about 5 minutes after the deploy started. Checked through the public gateway: anonymous API calls, a wrong password and Relay registration were refused, sign-up was closed, and the generated admin logged in as superuser. A new project's DSN pointed at the gateway domain; an event sent to the store endpoint and one sent as an envelope (what current SDKs use) were both accepted by Relay, became issues found through Snuba search, and the event payload and the stats page loaded. An unknown DSN key was rejected. After redeploying all 9 services, the admin still logged in (and was not recreated), and earlier projects and issues were still there; new events kept flowing. Idle memory is listed under Size and cost. Not tested: the browser UI (only its API), email, alerts, source map processing, and upgrades.

During that test Relay was built from a public repository with the same busybox wrapper as `relay/Dockerfile`; this repository's `relay/Dockerfile` was built and run locally.
