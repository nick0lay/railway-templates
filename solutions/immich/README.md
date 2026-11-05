# Immich

Self-hosted [Immich](https://github.com/immich-app/immich) on Railway: a photo and video library you control, an alternative to Google Photos and iCloud Photos. It includes machine learning on CPU for smart search, face recognition and text in photos (OCR). The admin account is created for you at deploy, so nobody else can claim your instance. The version is pinned and tested.

> **Pro plan recommended.** Your photos and videos are stored on the `immich-server` volume. On the Hobby plan a volume can hold at most 5 GB, and Immich also stores thumbnails and converted videos there. On Pro the volume starts at 50 GB and you can grow it yourself, without downtime, up to 1 TB (volume settings → Live Resize). Hobby is fine for trying Immich out with a small library.

## Architecture

```
              Browser / Immich mobile apps (iOS, Android)
                               │ HTTPS
                               ▼
┌────────────────────────────────────────────────────────────────┐
│ Railway project                                                │
│                                                                │
│  immich-server :2283 (public, login required)                  │
│    web app, API, background jobs        volume /data           │
│    (thumbnails, metadata, video)        photos, videos, thumbs │
│      │              │               │                          │
│      ▼              ▼               ▼                          │
│  Postgres :5432  Valkey :6379   immich-machine-learning :3003  │
│  (private,       (private)      (private, volume /cache)       │
│   volume)        job queues     smart search, faces, OCR       │
│  VectorChord                    models downloaded on first use │
└────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| immich-server | `ghcr.io/immich-app/immich-server:v3.3.6` | Web app, API and background jobs (public). Library on a volume at `/data` |
| immich-machine-learning | `ghcr.io/immich-app/immich-machine-learning:v3.3.6` | CPU models for smart search, face detection and recognition, OCR (private). Model cache on a volume at `/cache` |
| Postgres | `ghcr.io/immich-app/postgres:17-vectorchord0.4.3-pgvector0.8.1` | Immich's own Postgres image with the VectorChord vector extension (private, volume) |
| Valkey | `valkey/valkey:9.1.3` | Job queues, password-protected (private) |

## What this template does differently

- **Admin created at deploy.** On a fresh Immich install, whoever opens the URL first registers as the admin. This template creates the admin on first start with your `ADMIN_EMAIL` and a generated `ADMIN_PASSWORD`. After that, Immich refuses any further admin sign-up, and only the admin can add users.
- **Machine learning included and private.** Smart search ("beach at sunset"), face recognition, duplicate detection and OCR work out of the box on CPU. The machine learning service has no public URL.
- **Low idle memory.** Models unload after 5 minutes without use (`MACHINE_LEARNING_MODEL_TTL`) and their memory goes back to the system (`MACHINE_LEARNING_MODEL_ARENA=false`), so the machine learning service idles at a few hundred MB.
- **The database image Immich requires.** Immich needs Postgres with the VectorChord extension. This template uses Immich's own image on Postgres 17 (Immich 3.3.6 supports 14 to 19; Postgres 14 reaches end of life on 2026-11-12).
- **Pinned versions.** Immich 3.3.6 on both Immich services instead of `release`. Immich migrates the database on start, so you upgrade when you choose.
- **Private networking** for Postgres, Valkey and machine learning; generated passwords; healthcheck on `/api/server/ping`.

## After deploy

1. Open the `immich-server` URL and log in with `ADMIN_EMAIL` and the `ADMIN_PASSWORD` variable (on the `immich-server` service). Immich asks you to choose a new password on the first login, then walks you through a few settings (theme, storage template).
2. Add family members or friends under **Administration → Users**. There is no public sign-up.
3. Install the Immich app on your phone, enter the server URL, log in, and turn on backup.
4. Smart search and face recognition run in the background after uploads. The first jobs download the models (about 2 GB), so the first results take a few minutes.

## Variables

### User-configurable

| Variable | Service | Default | Notes |
|---|---|---|---|
| `ADMIN_EMAIL` | immich-server | (required) | Email of the admin account. You log in with it |
| `ADMIN_PASSWORD` | immich-server | generated | Read it after deploy. Applied only when the admin is created on first start |
| `ADMIN_NAME` | immich-server | `Admin` | Display name of the admin |
| `TZ` | immich-server | `Etc/UTC` | Timezone for photos without timezone information, e.g. `Europe/Berlin` |
| `MACHINE_LEARNING_MODEL_TTL` | immich-machine-learning | `300` | Seconds a model stays loaded after its last use |
| `MACHINE_LEARNING_REQUEST_THREADS` | immich-machine-learning | `2` | Raise it if you want faster processing of a large import |
| `POSTGRES_SHARED_BUFFERS` | Postgres | `128MB` | Postgres memory cache. Immich's image uses 512MB; 128MB keeps idle RAM low. Raise it for large libraries |

Most other settings (models, job concurrency, video transcoding, storage template, OAuth, SMTP) are changed in the web UI under **Administration → Settings**.

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `IMMICH_SETUP_JS` | script | Run by the start command to create the admin on first start. Later starts log `admin-setup: skipped: Admin setup is not available` |
| `DB_URL` | `${{Postgres.DATABASE_URL}}` | Private network |
| `REDIS_HOSTNAME`, `REDIS_PORT`, `REDIS_PASSWORD` | `${{Valkey.*}}` | Private network |
| `IMMICH_MACHINE_LEARNING_URL` | `http://${{immich-machine-learning.RAILWAY_PRIVATE_DOMAIN}}:3003` | Private network. Also editable in Administration → Settings → Machine Learning |
| `IMMICH_HOST` | `::` on machine learning | Listens on IPv4 and IPv6, so the server reaches it on any Railway private network |
| `MACHINE_LEARNING_CACHE_FOLDER` | `/cache` | Models are kept on the volume, so restarts don't download them again |
| `MACHINE_LEARNING_MODEL_ARENA` | `false` | Returns memory after models unload |
| `POSTGRES_PASSWORD`, `VALKEY_PASSWORD` | generated | Letters and digits only, as Immich requires |
| `PGDATA`, `POSTGRES_INITDB_ARGS` | volume path, `--data-checksums` | As Immich recommends |
| `PORT`, `IMMICH_PORT` | `2283` (server), `3003` (machine learning) | |

## Storage

- **Library:** the `immich-server` volume at `/data` holds originals, thumbnails, converted videos, profile pictures and Immich's nightly database dumps (`/data/backups`). Check its usage in the volume's metrics, and grow it before it fills (Pro: Live Resize, up to 1 TB).
- **Database:** the Postgres volume holds metadata, faces and search vectors. It starts at about 0.45 GB, mostly reverse-geocoding data, and grows slowly with the library.
- **Models:** the `immich-machine-learning` volume holds downloaded models (about 2.3 GB with the defaults).
- **Backups:** Immich dumps the database every night to `/data/backups`. Railway volume backups (service → Backups) cover the files as well. Keep a copy of irreplaceable photos somewhere else too.

## Resource use

Measured idle on Railway, with no activity and models unloaded: about 2 GB RAM in total (immich-server 0.7-0.9 GB, machine learning about 0.5 GB, Postgres about 0.45 GB, Valkey 20 MB) and almost no CPU. That is roughly $20 a month at Railway's usage prices, plus $0.15 per GB of photos. Uploads, thumbnail generation, video conversion and machine learning use more CPU and RAM while they run. A first import of thousands of photos keeps the machine learning service busy for a while; that is normal.

## Upgrading

Change the image tag on **both** `immich-server` and `immich-machine-learning` to the same version (for example `v3.3.7`). Read the [release notes](https://github.com/immich-app/immich/releases) first; Immich migrates the database on start and can't go back. Only change the Postgres image when a release note tells you to.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Login fails with the generated password | The admin is created on the first start only, and Immich makes you change the password on first login. If you changed `ADMIN_PASSWORD` or `ADMIN_EMAIL` later, use the old values |
| The page asks you to register an admin | The admin wasn't created. Check the `immich-server` logs for `admin-setup:` |
| Smart search or people find nothing | Jobs are still running, or models are downloading. See Administration → Jobs and the `immich-machine-learning` logs |
| "Machine learning server is not healthy" | Check that `immich-machine-learning` is running and that `IMMICH_MACHINE_LEARNING_URL` points to it |
| Uploads fail with "no space left" | The `/data` volume is full. Grow it (Pro: Live Resize) |
| Server doesn't start after an upgrade | The two Immich services must use the same version; read the release notes for required database changes |

## Testing

Tested on 2026-11-05 with Immich 3.3.6 in a throwaway Railway project: all four services healthy, migrations ran, and the admin was created at first start. The web app loaded and reported the instance as already set up, the API refused requests without a login, a second admin sign-up was refused ("Admin setup is not available"), a wrong password was refused, and the admin logged in. Two photos were uploaded through the API: thumbnails and metadata were generated, the face in the portrait was detected, and smart search returned the right photo for "dog" and for "old man". After a redeploy of the server, the photos, search and login were still there, and the setup step skipped itself. A second fresh deploy with the Postgres memory setting passed the same checks. On 2026-11-06 a third fresh deploy on Postgres 17 passed: admin created, login required, upload and smart search worked.
