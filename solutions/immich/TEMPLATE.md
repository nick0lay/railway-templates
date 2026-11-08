# Deploy and Host Immich on Railway

Immich is a self-hosted photo and video library, an open-source alternative to Google Photos. The mobile apps back up your phone automatically, and the web app lets you browse a timeline, albums and a map. It also finds people by face and finds photos by describing them ("dog on the beach").

## About Hosting Immich

Immich runs as a server (web app, API and background jobs) plus a machine learning service for smart search, faces and text in photos. It needs PostgreSQL with the VectorChord vector extension, Redis-compatible job queues, and a volume large enough for your library, thumbnails and converted videos. On a fresh install, whoever opens the URL first becomes the admin, and Immich migrates the database on start, so versions should be pinned.

This template creates your admin account at deploy and runs Immich with CPU machine learning, Immich's Postgres image and Valkey on Railway's private network.

**Pro plan recommended:** your library lives on a volume, which is capped at 5 GB on Hobby. On Pro it starts at 50 GB and you can live-resize it up to 1 TB. Hobby works for a small trial library.

## Common Use Cases

- Automatic phone photo and video backup for you and your family
- Replacing Google Photos or iCloud Photos with a library you own
- Searching photos by content, people, places and text in the image
- Sharing albums with family and friends through links or shared accounts
- Keeping a private, searchable archive of scanned photos

## Dependencies for Immich Hosting

- PostgreSQL 17 with VectorChord (Immich's own image)
- Valkey 9 (Redis-compatible)
- A volume for the library, and one for machine learning models

### Deployment Dependencies

- Immich: https://github.com/immich-app/immich
- Documentation: https://docs.immich.app
- Mobile apps: https://docs.immich.app/features/mobile-app
- Images: https://github.com/immich-app/immich/pkgs/container/immich-server

### Implementation Details

**What you set:** `ADMIN_EMAIL`, the email you log in with. Everything else is generated.

**After deploy:**

1. Open the Immich URL and log in with `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD` (variables of `immich-server`). Immich asks you to choose a new password on the first login.
2. Add users under Administration → Users. There is no public sign-up.
3. Install the Immich app on your phone, enter the server URL, and turn on backup.

**This template:**

- Creates the admin account on first start, so nobody else can claim your instance
- Includes the machine learning service for smart search, face recognition, duplicate detection and OCR, on CPU and with no public URL
- Unloads models after 5 minutes without use and releases their memory, so idle RAM stays low
- Uses Immich's Postgres image with VectorChord, as Immich requires
- Keeps the library on a volume at `/data` and the models on their own volume
- Protects Valkey with a generated password and keeps Postgres, Valkey and machine learning private
- Pins Immich 3.3.6 and checks health on `/api/server/ping`

**Notes:** upgrade by changing the image tag on both `immich-server` and `immich-machine-learning` to the same version; read Immich's release notes first, because it migrates the database on start. Watch the `/data` volume usage and grow it before it fills.

## Why Deploy Immich on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Immich on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
