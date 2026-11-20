# Browserless 2.64 (Chromium)

Headless Chrome as a service. This template runs [Browserless](https://github.com/browserless/browserless) v2 from the official image `ghcr.io/browserless/chromium:v2.64.0` on Railway, behind a generated token. Connect Puppeteer or Playwright over a websocket, or call the REST API for page content, screenshots, PDFs and scraping, from n8n, Flowise, LangChain, browser agents or your own code.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/browserless-263-chromium?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

**Licence: SSPL-1.0 or the Browserless commercial licence.** Read the [Licence](#licence) section before you use it in a commercial product.

## Architecture

```
Your app / Puppeteer / Playwright / n8n
   |  HTTPS + WSS, ?token=TOKEN or Authorization: Bearer TOKEN
   v
+------------------------------------------------+
| Browserless (public)                           |
| ghcr.io/browserless/chromium:v2.64.0  :3000    |
| REST API + websocket endpoints, 401 without    |
| the token; one Chromium per session            |
+------------------------------------------------+
   ^
   |  ws://browserless.railway.internal:3000 (private network, same token)
Other services in the same project
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Browserless | `ghcr.io/browserless/chromium:v2.64.0` | Public. REST API and websocket endpoints for Puppeteer, Playwright and CDP clients. Launches a fresh Chromium for each session and closes it at the end |

One service, no database and no volume: Browserless is stateless by design. Each session gets a temporary profile that is deleted when it ends, so nothing needs to persist across redeploys. The image is pinned to a release tag.

## After deploy

1. Open the **Browserless** service, Variables tab. Copy `BROWSER_WS_ENDPOINT` (Puppeteer), `BROWSER_PLAYWRIGHT_ENDPOINT` (Playwright) or `BROWSER_HTTP_ENDPOINT` plus `TOKEN` (REST API).
2. Try it:

```bash
curl -s "https://your-domain/json/version?token=YOUR_TOKEN"

curl -s -X POST "https://your-domain/chromium/screenshot?token=YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com"}' -o example.png
```

### Puppeteer

```js
import puppeteer from "puppeteer-core";

const browser = await puppeteer.connect({
  browserWSEndpoint: "wss://your-domain?token=YOUR_TOKEN",
});
const page = await browser.newPage();
await page.goto("https://example.com");
console.log(await page.title());
await browser.close();
```

### Playwright

```js
import { chromium } from "playwright-core";

const browser = await chromium.connect("wss://your-domain/chromium/playwright?token=YOUR_TOKEN");
const page = await browser.newPage();
await page.goto("https://example.com");
await browser.close();
```

Use a Playwright client from 1.61 to 1.65: this release bundles those Playwright server versions (only 1.65 was tested here). Python Playwright: `p.chromium.connect("wss://your-domain/chromium/playwright?token=YOUR_TOKEN")`. Puppeteer-style CDP clients (including Playwright's `connect_over_cdp`) use `BROWSER_WS_ENDPOINT`.

### From another service in the same project

Reference the private variables so traffic stays on Railway's private network:

```
BROWSERLESS_WS=${{Browserless.BROWSER_WS_ENDPOINT_PRIVATE}}
BROWSERLESS_URL=${{Browserless.BROWSER_HTTP_ENDPOINT_PRIVATE}}
BROWSERLESS_TOKEN=${{Browserless.BROWSER_TOKEN}}
```

### n8n, Flowise, LangChain, browser agents

Most integrations ask for a websocket endpoint (`BROWSER_WS_ENDPOINT`) or a base URL plus token. These variable names match the older Railway Browserless templates: `BROWSER_TOKEN`, `BROWSER_DOMAIN`, `BROWSER_DOMAIN_PRIVATE`, `BROWSER_PORT_PRIVATE`, `BROWSER_WS_ENDPOINT`, `BROWSER_PLAYWRIGHT_ENDPOINT` and their `_PRIVATE` versions. `BROWSER_PORT_PRIVATE` is now 3000 (no extra proxy). The WebDriver endpoint variables of those templates are not provided.

## Endpoints

| Endpoint | Method | What it does |
|----------|--------|--------------|
| `/` (websocket) | WS | Puppeteer / CDP connect |
| `/chromium/playwright` | WS | Playwright connect |
| `/chromium/content` | POST | Rendered HTML of a page |
| `/chromium/screenshot` | POST | PNG or JPEG screenshot |
| `/chromium/pdf` | POST | PDF of a page |
| `/chromium/scrape` | POST | Elements by CSS selector as JSON |
| `/chromium/function` | POST | Run your own Puppeteer code |
| `/json/version` | GET | Browser version and the websocket URL |
| `/pressure`, `/sessions`, `/metrics` | GET | Load, running sessions, stats |
| `/docs/` | GET | OpenAPI documentation (static, no token) |
| `/debugger/` | GET | Interactive debugger (static page; running code needs the token) |

The short paths (`/content`, `/screenshot`, `/pdf`, `/function`) also work. Full reference: https://docs.browserless.io/

## Environment variables

### User-configurable

| Variable | Default | Notes |
|----------|---------|-------|
| `TOKEN` | generated, 48 letters and digits | Required on every session and API call. Change it to rotate; update clients that use it |
| `CONCURRENT` | `5` | Sessions running at the same time. A Chromium session typically takes a few hundred MB of RAM (more on heavy pages). Raise it with your plan's memory |
| `QUEUED` | `10` | Requests waiting for a free session; beyond that clients get HTTP 429 |
| `TIMEOUT` | `300000` | Maximum session length in ms (5 minutes). A stuck script is closed after it |
| `DEBUG` | `browserless*,-**:verbose,-**:trace,-**:debug` | Log level. Info, warnings and errors only. Debug lines include each session's launch options, which contain `TOKEN` |

Other Browserless settings can be added as variables, for example `CORS=true` for browser-side clients, `ALLOW_GET=true` for GET requests on the REST API, or `HEALTH=true` with `MAX_CPU_PERCENT` / `MAX_MEMORY_PERCENT` to refuse new sessions under load. See https://docs.browserless.io/enterprise/docker/config

### Auto-configured (do not change)

| Variable | Value | Why |
|----------|-------|-----|
| `HOST` | `::` | Listens on IPv4 and IPv6. The Railway private network is IPv6; `0.0.0.0` would break private connections |
| `PORT` | `3000` | Matches the public domain's target port |
| `PROXY_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Makes `/json/version` and session links return your public `wss://` URL instead of `localhost`. If you remove the public domain, the start command drops it so the service still starts for private-network use |
| `DEBUG_COLORS` | `false` | Plain log lines |
| `BROWSER_TOKEN` | `${{TOKEN}}` | Alias for other services |
| `BROWSER_DOMAIN`, `BROWSER_DOMAIN_PRIVATE`, `BROWSER_PORT_PRIVATE` | public domain, private domain, `${{PORT}}` | Parts for building your own URLs |
| `BROWSER_WS_ENDPOINT`, `BROWSER_PLAYWRIGHT_ENDPOINT`, `BROWSER_HTTP_ENDPOINT` | built from the public domain and `TOKEN` | Copy-paste connection strings |
| `BROWSER_*_PRIVATE` | built from the private domain, port 3000 and `TOKEN` | Private-network connection strings |

## Security

- Every session and every API, management and metrics route needs the token. Only static files (the OpenAPI docs, the debugger page, the favicon used as healthcheck) are served without it; the debugger cannot start a browser without the token.
- Anyone with the token can drive a browser from your Railway service, including requests to other services on your project's private network. Keep the token secret, rotate it if it leaks, and do not put it in client-side code.
- The healthcheck (`/favicon-32x32.png`) shows that the HTTP server is up. Chromium starts per session, so a broken browser shows up on the first session, not in the healthcheck.

## Licence

Browserless is dual-licensed: **SSPL-1.0 or the Browserless commercial licence** ([LICENSE](https://github.com/browserless/browserless/blob/main/LICENSE)). It is source-available, not OSI open source.

- Upstream states that using Browserless to build commercial sites or applications, or in a continuous-integration system, that are closed-source requires a commercial licence: https://www.browserless.io/contact
- Under SSPL, offering Browserless as a service to others requires releasing the source of the whole stack you use to run that service.
- Personal projects, evaluation and open-source projects that comply with the SSPL can use it under the SSPL.

This template only deploys the unmodified official image. Choosing the licence that fits your use, and complying with it, is your responsibility.

## Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| HTTP 401 | Token missing or wrong. Send `?token=YOUR_TOKEN` or `Authorization: Bearer YOUR_TOKEN` |
| HTTP 429 | All `CONCURRENT` sessions busy and the queue (`QUEUED`) full. Raise both if memory allows, or close sessions in your code |
| Sessions closed after 5 minutes | `TIMEOUT` reached. Raise it for long-running agents |
| Service restarts, out-of-memory in logs | Too many sessions for the plan's memory. Lower `CONCURRENT` or raise the memory limit |
| `/json/version` returns `ws://localhost:3000` | No public domain. Fine for private-network use; add a domain (or set `PROXY_URL` to your custom domain) for public URLs |
| Playwright connect fails with a version error | Use a client version the server bundles (1.61 to 1.65 for this release) |
| Private connection refused | Use `ws://browserless.railway.internal:3000` (the `_PRIVATE` variables), not port 3001 from older templates |

## Tested

2026-11-18: deployed from the template on Railway. Requests without a token or with a wrong token were refused on every session, API and management route (HTTP 401). With the token: `/json/version` returned the public `wss://` URL, `/chromium/content` of example.com, a PNG screenshot and a PDF; Puppeteer and Playwright 1.65 connected over the public websocket; another service reached the API over the private network. After a redeploy, the same token and all checks passed again.
