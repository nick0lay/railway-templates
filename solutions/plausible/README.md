# Plausible Analytics

Self-hosted [Plausible Community Edition](https://github.com/plausible/community-edition) on Railway: lightweight, cookieless, privacy-friendly web analytics, an open-source alternative to Google Analytics. This template runs the official Plausible image with PostgreSQL and ClickHouse. The owner account is created at deploy, so nobody can claim your instance, both databases are reachable only over the private network, and every version is pinned and tested.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/plausible-1?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
          You (dashboard)              Your websites (tracking script)
                 │ HTTPS                          │ HTTPS  /js/script.js, /api/event
                 ▼                                ▼
┌──────────────────────────────────────────────────────────────┐
│ Railway project                                              │
│                                                              │
│  Plausible :8000 (public, login required for the dashboard)  │
│    volume /var/lib/plausible (geolocation data, temp files)  │
│        │                               │                     │
│        ▼                               ▼                     │
│  Postgres :5432 (private)        ClickHouse :8123 (private)  │
│    users, sites, settings          pageviews and events      │
│    volume                          volume                    │
└──────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Plausible | `ghcr.io/plausible/community-edition:v3.2.1` | Dashboard, tracking script and event API (public, login required) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:17` | Users, sites, goals and settings (private) |
| ClickHouse | `clickhouse/clickhouse-server:24.12.6.70-alpine` | Pageviews and events (private) |

## What this template does differently

- **No one can claim your instance.** On a fresh Plausible, the first person to open the sign-up page becomes the owner. This template creates the owner from `ADMIN_EMAIL` and a generated `ADMIN_PASSWORD` before Plausible starts, and sign-up is limited to people you invite (`DISABLE_REGISTRATION=invite_only`).
- **Private databases.** Postgres and ClickHouse have no public domain or TCP proxy.
- **Pinned versions.** Plausible v3.2.1 and the ClickHouse version Plausible's own compose file uses, instead of moving tags such as `v2` or `latest`.
- **ClickHouse tuned for a small service.** Plausible's low-memory settings, and ClickHouse's high-volume internal log tables are turned off or kept for 7 days, so they don't fill the volume.
- **Volume for Plausible.** Geolocation data and temporary files live on a volume.
- **Databases created and migrated on every start**, so upgrades need no manual step. The healthcheck (`/api/system/health/ready`) also reports whether Postgres and ClickHouse are reachable.

## After deploy

1. Open the Plausible URL and log in with `ADMIN_EMAIL` and the `ADMIN_PASSWORD` variable (Plausible service → Variables).
2. Click **Add a website**, enter your site's domain, and copy the script tag Plausible shows into your site's `<head>`.
3. Visit your site; the visit appears on the dashboard within seconds.
4. Change your password and turn on two-factor sign-in under **Settings**.
5. To add teammates, invite them under **Settings → Team**. Invitations are sent by email, so add email settings first (below).

## Email (optional)

Plausible sends invitations, password resets and weekly reports by email. Add these variables to the Plausible service and redeploy:

| Variable | Example |
|---|---|
| `MAILER_EMAIL` | `plausible@yourdomain.com` |
| `SMTP_HOST_ADDR` | `smtp.resend.com` |
| `SMTP_HOST_PORT` | `587` |
| `SMTP_USER_NAME` | provider user |
| `SMTP_USER_PWD` | provider password or API key |
| `SMTP_HOST_SSL_ENABLED` | `false` for STARTTLS on 587, `true` for 465 |

See [Plausible's configuration docs](https://github.com/plausible/community-edition/wiki/configuration#email) for Postmark, Mailgun and other providers.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Plausible | `ADMIN_EMAIL` | (required) | Email of the owner account. You log in with it |
| Plausible | `ADMIN_PASSWORD` | generated | Read it after deploy. Applied only when the owner is created on the first start |
| Plausible | `ADMIN_NAME` | `Admin` | Display name of the owner |
| Plausible | `BASE_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL. Change it when you add a custom domain |
| Plausible | `DISABLE_REGISTRATION` | `invite_only` | `invite_only`: only invited people can sign up. `true`: nobody. `false`: anyone |
| Plausible | `ENABLE_EMAIL_VERIFICATION` | `false` | Set to `true` after adding email settings |

Optional extras such as Google Search Console (`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`) and MaxMind city-level geolocation (`MAXMIND_LICENSE_KEY`, `MAXMIND_EDITION`) are described in [Plausible's configuration docs](https://github.com/plausible/community-edition/wiki/configuration). Without MaxMind, Plausible uses the free country-level database included in the image.

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Plausible | `SECRET_KEY_BASE` | generated | Signs sessions. Changing it logs everyone out |
| Plausible | `TOTP_VAULT_KEY` | generated | Encrypts two-factor secrets. Changing it breaks two-factor sign-in |
| Plausible | `DATABASE_URL` | from the Postgres service | Private network |
| Plausible | `CLICKHOUSE_DATABASE_URL` | from the ClickHouse service | Private network |
| Plausible | `PG_HOST`, `CH_HOST` | private hosts | The start script waits for both databases |
| Plausible | `ECTO_IPV6`, `ECTO_CH_IPV6`, `ENABLE_ALPINE_PRIVATE_NETWORKING` | `true` | Railway's private network is IPv6 |
| Plausible | `HTTP_PORT`, `PORT` | `8000` | Port Plausible listens on and Railway routes to |
| Plausible | `RAILWAY_RUN_UID` | `0` | The start script runs as root only to hand the volume to the `plausible` user, then runs Plausible as that user |
| Plausible | `TMPDIR` | `/var/lib/plausible/tmp` | Temporary files on the volume |
| Plausible | `PLAUSIBLE_RUN_SH` | script | Start script: waits for the databases, creates and migrates them, creates the owner, starts Plausible |
| Postgres | `POSTGRES_PASSWORD` | generated | Database password |
| ClickHouse | `CLICKHOUSE_USER`, `CLICKHOUSE_PASSWORD`, `CLICKHOUSE_DB` | `plausible`, generated, `plausible_events_db` | ClickHouse account and database for events |
| ClickHouse | `CLICKHOUSE_RUN_SH` | script | Start script: small log tables and low-memory settings |

## Upgrading

Change the Plausible image tag (for example `ghcr.io/plausible/community-edition:v3.3.0`) and redeploy; migrations run on start. Read the [release notes](https://github.com/plausible/analytics/releases) first, and upgrade ClickHouse only to a version Plausible's [compose file](https://github.com/plausible/community-edition/blob/master/compose.yml) uses. Back up both databases before a major version.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Deploy fails with `ADMIN_EMAIL and ADMIN_PASSWORD must be set` | The owner is created on the first start. Set both variables and redeploy |
| Login fails with the generated password | The owner is created on the first start only. If you changed `ADMIN_PASSWORD` or `ADMIN_EMAIL` later, use the old values, or reset the password by email |
| Script tag points to the Railway domain after adding a custom domain | Set `BASE_URL` to your custom domain and redeploy |
| Invitations and password resets never arrive | No email settings. See **Email** above |
| Visits don't show up | Check that the domain in the script tag matches the site you added, and that an ad blocker isn't blocking `/js/script.js` |
| Everyone is logged out after a redeploy | `SECRET_KEY_BASE` was changed or removed |

## License

Plausible Community Edition is [AGPL-3.0](https://github.com/plausible/analytics/blob/master/LICENSE.md). ClickHouse is Apache-2.0.

## Testing

Tested on 2026-11-07 with Plausible CE v3.2.1 in a throwaway Railway project deployed from the template. All three services were healthy about a minute after deploy, and the owner account was created on the first start. Without a login, the dashboard redirected to the login page and the stats API refused requests; a wrong password and a stranger opening the sign-up page were refused, and Postgres and ClickHouse had no public endpoint. The owner logged in and added a site, pageviews sent to `/api/event` appeared in the dashboard stats (visitors, top pages, source, browser and country from the visitor's real IP), and the tracking script was served. After redeploying all three services, the owner was left unchanged and the site and its stats were still there. At idle the three services used about 1.1 GB of RAM together. Not tested: email, Google Search Console, MaxMind and the browser dashboard UI (only its HTTP endpoints).
