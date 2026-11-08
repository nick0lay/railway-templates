# Deploy and Host Excalidraw on Railway

Excalidraw is an open-source virtual whiteboard for hand-drawn style diagrams, sketches and wireframes. It works in the browser, has live collaboration and shareable links, and encrypts drawings end to end, so the server never sees their content.

## About Hosting Excalidraw

The Excalidraw app alone is a static site: drawing works, but live collaboration needs a Socket.IO collaboration server, and share links, collaboration rooms and images need a storage backend. The official build sends those to excalidraw.com and Firebase, and its settings are fixed at build time, so most self-hosted setups either lose these features or keep sending drawings to excalidraw.com. A public instance without a login can also be used by anyone to store files.

This template runs the whole stack on Railway: the Excalidraw app, the official collaboration server, a storage service for share links, rooms and images, and PostgreSQL, behind one gateway with a login. Everything uses one domain, the services behind the gateway are private, and every version is pinned and tested.

## Common Use Cases

- A private whiteboard for a team: architecture diagrams, flowcharts and sketches
- Live collaboration in workshops, interviews and planning sessions without third-party servers
- Share links to diagrams for teammates, kept on your own infrastructure
- Wireframes and UI mockups in a hand-drawn style
- Diagrams for docs and blog posts, exported as PNG or SVG

## Dependencies for Excalidraw Hosting

- PostgreSQL 17
- Caddy 2.10 (gateway)

### Deployment Dependencies

- Excalidraw: https://github.com/excalidraw/excalidraw
- Excalidraw fork with self-hosted storage and runtime settings: https://github.com/alswl/excalidraw
- Collaboration server: https://github.com/excalidraw/excalidraw-room
- Storage backend: https://github.com/alswl/excalidraw-storage-backend

### Implementation Details

**What you set:** nothing. Optionally `AUTH_USERNAME` (default `admin`).

**After deploy:**

1. Open the Excalidraw URL and log in with `AUTH_USERNAME` and the generated `AUTH_PASSWORD` (Excalidraw service → Variables).
2. Click Share → Start session for live collaboration, or Share → Export to link for a share link.
3. Give the password to everyone who should open the site, room links or share links.

**This template:**

- Runs live collaboration and share links on your own servers, with no Firebase and no excalidraw.com backend
- Protects the whole site with a login (HTTP basic auth), including the storage API and the collaboration socket
- Serves the app, storage and collaboration on one domain, so a custom domain needs no changes
- Keeps share links, rooms and images in PostgreSQL on a volume; drawings are stored end-to-end encrypted
- Keeps the app, collaboration server, storage and database private
- Creates the storage table before the first start, avoiding a first-start failure of the storage backend
- Pins Excalidraw v0.18.1 and every other image

**Notes:** the five services idle at about 0.3 GB of RAM together. Anyone who opens a room link or share link needs the login. Excalidraw's fonts and the public library browser load from Excalidraw's CDN.

## Why Deploy Excalidraw on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Excalidraw on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
