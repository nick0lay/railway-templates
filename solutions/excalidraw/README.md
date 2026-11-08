# Excalidraw

Self-hosted [Excalidraw](https://github.com/excalidraw/excalidraw) on Railway, with live collaboration and share links that run on your own servers. Most Excalidraw templates deploy only the drawing app, so "Live collaboration" and "Export to link" either fail or still send your drawings to excalidraw.com. This template adds the collaboration server, a storage service for share links, collaboration rooms and images, and PostgreSQL. A login protects the whole site, and every version is pinned and tested.

## Architecture

```
                 Browser (you and your team)
                        │ HTTPS, login required
                        ▼
┌────────────────────────────────────────────────────────────┐
│ Railway project                                            │
│                                                            │
│  Excalidraw :8080 (public gateway, Caddy, basic auth)      │
│    /             ──▶ Frontend :80   Excalidraw app (nginx) │
│    /socket.io/*  ──▶ Room :80       live collaboration     │
│    /api/v2/*     ──▶ Storage :8080  share links, rooms,    │
│                                     images                 │
│                        │                                   │
│                        ▼                                   │
│                  Postgres :5432 (private, volume)          │
└────────────────────────────────────────────────────────────┘
```

Only the gateway has a public domain. The app, the collaboration server, the storage service and the database are reachable only over Railway's private network.

## Services

| Service | Source | Role |
|---------|--------|------|
| Excalidraw | `caddy:2.10.2-alpine` | Public gateway: login, routes to the other services |
| Frontend | `alswl/excalidraw:v0.18.1-fork-b2` | Excalidraw v0.18.1 app, built with a self-hosted storage backend and runtime settings (private) |
| Room | `excalidraw/excalidraw-room:sha-03ff435` | Official Excalidraw collaboration server, Socket.IO (private) |
| Storage | `alswl/excalidraw-storage-backend:v2023.11.11` | Stores share-link scenes, collaboration rooms and images (private) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:17` | Storage database (private, volume) |

The Frontend image comes from [alswl/excalidraw](https://github.com/alswl/excalidraw), a fork that follows upstream releases and adds two things the official image lacks: settings read at container start instead of build time, and an HTTP storage backend instead of Firebase for collaboration rooms and images.

## What this template does differently

- **Collaboration and share links stay on your servers.** The app is configured to use the template's own collaboration server and storage, with no Firebase and no excalidraw.com backend. Drawings are end-to-end encrypted in the browser; the key is in the part of the link after `#`, which never reaches the server, so the database holds only ciphertext.
- **Login on the whole site.** A Caddy gateway asks for a user name and password (HTTP basic auth) before anything loads, including the storage API and the collaboration socket. Without it, anyone who finds the URL could use your instance to store files.
- **One domain.** The app, the storage API and the collaboration socket share the gateway's domain, so a custom domain works without changing any URL.
- **Storage that survives restarts.** Share links, rooms and images are kept in PostgreSQL on a volume, not in memory.
- **Fixed first start.** The storage service creates its table before it starts. Without this, its three storage areas race to create the table on the first start and two of them fail until a restart.
- **IPv6 private network.** The app's nginx also listens on IPv6, which Railway's private network uses.
- **Pinned versions** for every image.

## After deploy

1. Open the Excalidraw service's URL. Your browser asks for a login: the user is `AUTH_USERNAME` (`admin` by default) and the password is the generated `AUTH_PASSWORD` (Excalidraw service → Variables).
2. Draw. Your drawing is saved in your browser, as on excalidraw.com.
3. **Live collaboration:** click **Share → Start session** and send the room link to a teammate.
4. **Share link:** click **Share → Export to link** to get a read-and-copy link for the current drawing.
5. Everyone who opens the site, a room link or a share link needs the login. Share the password with your team, or change `AUTH_PASSWORD` and redeploy the Excalidraw service to revoke access.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Excalidraw | `AUTH_USERNAME` | `admin` | Login user name for the whole site |
| Excalidraw | `AUTH_PASSWORD` | generated | Login password. Change it and redeploy to revoke access. The gateway refuses to start if it is empty |
| Storage | `BODY_LIMIT` | `50mb` | Largest scene or image upload |
| Storage | `LOG_LEVEL` | `warn` | `log`, `warn`, `error` or `debug` |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Excalidraw | `PORT` | `8080` | Port Railway routes the public domain to |
| Excalidraw | `FRONTEND_UPSTREAM`, `STORAGE_UPSTREAM`, `ROOM_UPSTREAM` | private hosts | Where the gateway sends each path |
| Excalidraw | `GATEWAY_RUN_SH` | script | Start script: hashes the password and starts Caddy |
| Frontend | `VITE_APP_WS_SERVER_URL` | `/` | Collaboration server on the same domain |
| Frontend | `VITE_APP_STORAGE_BACKEND`, `VITE_APP_HTTP_STORAGE_BACKEND_URL` | `http`, `/api/v2` | Rooms and images go to the Storage service, not Firebase |
| Frontend | `VITE_APP_BACKEND_V2_GET_URL`, `VITE_APP_BACKEND_V2_POST_URL` | `/api/v2/scenes/` | Share links use the Storage service, not json.excalidraw.com |
| Frontend | `VITE_APP_FIREBASE_CONFIG` | `{}` | Firebase is not used |
| Frontend | `VITE_APP_DISABLE_TRACKING`, `VITE_APP_ENABLE_TRACKING` | `true`, `false` | No analytics |
| Frontend | `FRONTEND_RUN_SH` | script | Start script: nginx listens on IPv6 too, then the fork's launcher writes the settings and starts nginx |
| Room | `PORT`, `CORS_ORIGIN` | `80`, `*` | The gateway login protects the socket |
| Storage | `PORT` | `8080` | Private port |
| Storage | `STORAGE_URI` | from the Postgres service | Private network |
| Storage | `STORAGE_RUN_SH` | script | Start script: waits for Postgres, creates the storage table, starts the API |
| Postgres | `POSTGRES_PASSWORD` | generated | Database password |

## Upgrading

When [alswl/excalidraw](https://hub.docker.com/r/alswl/excalidraw/tags) publishes a build for a new Excalidraw release (tags look like `v0.18.1-fork-b2`), change the Frontend image tag and redeploy. Drawings stored in the database stay readable: they are encrypted scenes in Excalidraw's own format. Back up Postgres first.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| The browser keeps asking for the login | Wrong user or password. Read `AUTH_USERNAME` and `AUTH_PASSWORD` on the Excalidraw service |
| A teammate can't open a room or share link | Every page on the site needs the login, including room and share links. Give them the password |
| Excalidraw service fails with `AUTH_PASSWORD is empty` | Set a password and redeploy |
| "Live collaboration" shows a connection error | Check that the Room service is running; the gateway sends `/socket.io/` to it |
| Share link says the scene could not be loaded | Check that Storage and Postgres are running. Links created before a database was deleted are gone |
| 502 from the gateway right after deploy | The other services are still starting. Wait a minute |

## License

Excalidraw, the alswl fork and excalidraw-room are MIT. excalidraw-storage-backend is MIT.

## Testing

Tested on 2026-11-08 in a throwaway Railway project deployed from the template; all five services were up about 30 seconds after deploy. Without a login, with a wrong password and with a wrong user name, the app, the storage API (read, upload, rooms, images) and the collaboration socket (polling and WebSocket upgrade) all returned 401. With the login, in a real browser (headless Chromium): user A drew a rectangle and started a collaboration session, user B opened the room link and saw it, B drew an ellipse that appeared for A live over a WebSocket through the gateway, and the room was saved to the Storage service. A share link created with Export to link pointed to the template's own domain and opened the drawing in another browser. No scene or collaboration traffic went to excalidraw.com or Firebase; only Excalidraw's fonts load from its CDN. After redeploying all five services, the share link, the collaboration room and stored images were still there and opened in a browser. At idle the five services used about 0.3 GB of RAM together. Not tested: image uploads in the browser (the image storage API was tested directly), the library browser and custom domains.
