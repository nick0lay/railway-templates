# SoduWork 1.13

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/soduwork-113?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

Self-hosted [SoduWork](https://github.com/mdiri-ai/soduwork) Hub on Railway: the open-source work engine for teams and their AI agents. People file requests, an agent harness does the work, a second agent reviews it and a person signs off. The Hub holds accounts, departments, projects, requests, files and plugins, serves the admin console, and is what the SoduWork desktop app connects to.

Upstream publishes no Docker image, so this template builds the Hub from the pinned **v1.13.19** release. The admin account is created at deploy, public sign-up is off, and all Hub state lives on one volume.

SoduWork is MIT licensed. The SoduWork name and logo are trademarks of MDiRi; this template is not affiliated with or endorsed by MDiRi.

## Architecture

```
        Admin console (browser)        SoduWork desktop app (each team member)
                    │ HTTPS                        │ HTTPS + WebSocket
                    ▼                              ▼
┌───────────────────────────────────────────────────────────────┐
│ Railway project                                               │
│                                                               │
│  SoduWork :8989 (public)                                      │
│    FastAPI Hub + admin console, built from v1.13.19           │
│    healthcheck /readyz, runs as uid 10001                     │
│        │                          │                           │
│        ▼                          ▼                           │
│  Postgres 18 (private)      Volume /data                      │
│    accounts, requests,        uploads/  (attachments, library)│
│    projects, plugins          downloads/  client-releases/    │
│                               workspaces/  releases/          │
│                               repos/  runtime/  home/         │
└───────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| SoduWork | `hub/` in this folder: Dockerfile that builds upstream tag `v1.13.19` | Hub API and admin console (public, volume at `/data`, healthcheck `/readyz`) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Database (private, volume) |

## What this template does differently

- **Pinned release.** The Dockerfile clones the `v1.13.19` tag and mirrors upstream's own `ops/self-host/Dockerfile`. Deploys don't change under you when upstream's main branch moves.
- **Admin at deploy, sign-up closed.** `ADMIN_PASS` is generated and the `admin` user is created on the first boot. Upstream turns public self-registration on by default (it's stored in the database), so the entrypoint turns it off once through the admin API. A marker on the volume keeps your later choice if you turn it back on in the admin console.
- **All state on one volume.** Upstream's compose file uses seven volumes. The entrypoint links all seven folders (uploads, downloads, client releases, workspaces, releases, repositories, runtime data) plus the home folder to `/data`, gives the volume to the app user, and then starts the Hub as non-root.
- **Correct secrets.** `AUTH_SECRET` (64 characters) and `CONNECTOR_OAUTH_KEY` (a valid Fernet key, 32 bytes in URL-safe base64) are generated. Production mode is on, so the Hub refuses weak secrets and wildcard CORS.
- **Postgres 18 with working backups.** The image ships `postgresql-client-18` instead of upstream's 16, so the in-app `pg_dump` backup works against the Postgres 18 server.
- **Healthcheck.** Railway waits for `/readyz` (Hub up and database reachable) before switching traffic.

## After deploy

1. The first build takes a few minutes.
2. Open the SoduWork URL and sign in as `admin` with the `ADMIN_PASS` variable of the `SoduWork` service.
3. Change the admin password in user management (the variable is only used when the first admin is created).
4. Create departments and users, and add model providers in the admin console.
5. Install the [SoduWork desktop app](https://github.com/mdiri-ai/soduwork/releases), enter the Hub URL (`https://<your domain>`), and sign in with a user you created. New devices wait until an admin activates them.

Agents do not run inside the Hub container (`HUB_LOCAL_EXECUTION_ENABLED=false`, as upstream recommends). They run in each person's desktop app, or on a separate Runner you register.

## Variables

### User-configurable

| Variable | Default | Notes |
|---|---|---|
| `ADMIN_USER` | `admin` | First admin, created while the users table is empty |
| `ADMIN_PASS` | generated | First admin's password. Used only on the first boot |
| `SODUWORK_CLOSE_SIGNUP` | `true` | Turn off public self-registration on the first boot. Set `false` to keep upstream's default |
| `REPORT_AUTO` | `false` | Automatic daily personal reports |
| `IM_ENABLED` | `false` | Instant-messaging ingress |
| `REPOSITORY_SYNC_INTERVAL_SECONDS` | `0` | GitLab/Gerrit catalog refresh (0 = off) |

Other Hub settings (mail, MinIO/S3 storage, GitLab, vision models and more) are read from environment variables named after the fields in upstream's `hub-backend/app/config.py`, in capitals.

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `AUTH_SECRET` | generated | Signs login tokens. Changing it logs everyone out |
| `CONNECTOR_OAUTH_KEY` | generated Fernet key | Encrypts stored connector credentials. Never change it after the first deploy |
| `DATABASE_URL` | `postgresql+asyncpg://...` from the Postgres variables | Hub database |
| `HUB_PUBLIC_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public origin |
| `CORS_ORIGINS` | the public origin and `null` | Admin console and desktop app |
| `SODUWORK_ENV` | `production` | Strong-secret and CORS guardrails |
| `DB_MIGRATION_MODE` | `auto` | Migrations on startup (single instance) |
| `DEVICE_AUTH_COMPAT` | `false` | Legacy device registration off |
| `HUB_LOCAL_EXECUTION_ENABLED` | `false` | No agent execution in the Hub container |
| `LIBRARY_STORAGE_BACKEND`, `LIBRARY_STORAGE_DIR` | `local`, `uploads/library` | Library on the volume |
| `CLIENT_UPDATE_DIR`, `JIYONG_ASSET_DIR` | folders on the volume | |
| `PORT` | `8989` | |

## Security notes

- Keep `ADMIN_PASS` secret and change it after the first sign-in.
- New desktop devices stay pending until an admin activates them.
- Model and connector keys are entered by users and stored encrypted with `CONNECTOR_OAUTH_KEY`.

## Upgrading

Back up first (Postgres and the volume). Then change `ARG SODUWORK_TAG` in `hub/Dockerfile` to a newer [release](https://github.com/mdiri-ai/soduwork/releases), compare upstream's `ops/self-host/Dockerfile` at that tag with this one, and redeploy. Migrations run on startup. Rollback needs the matching database, files and keys together.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Deploy waits on the healthcheck | The first boot runs migrations. Check the deploy logs for database errors |
| `admin` login fails | Use the `ADMIN_PASS` value from the first deploy. Changing the variable later doesn't change an existing account |
| Desktop app can't connect | Use the `https://` Hub URL without `/api`. Activate the device in the admin console |
| Users can't sign themselves up | Expected: sign-up is off. Add users in the admin console, or turn self-registration on there (it also needs mail set up) |

## Testing

Tested on Railway on 2026-11-24 with SoduWork v1.13.19. The build and deploy took about 2.5 minutes, and idle memory was about 0.16 GB for the Hub and 0.2 GB for Postgres. `/readyz` reported the Hub and database ready. Without a token, the admin APIs returned 401, and a wrong password or user name was refused. The admin signed in with the generated password. Self-registration was off: a new device stayed pending and a registration request was refused. A department, a user (who could sign in), a project and a request were created, and a file was uploaded to the request and downloaded back intact. After a redeploy, the admin password, the department, the user, the request and the file were all still there, and sign-up was still off. Not tested: the desktop app, model providers and agent runs.

## License

SoduWork is licensed under the [MIT License](https://github.com/mdiri-ai/soduwork/blob/main/LICENSE). The SoduWork name and logo are trademarks of MDiRi and are not licensed under MIT. This template is not affiliated with or endorsed by MDiRi.
