# Deploy and Host Browserless 2.63 (Chromium) on Railway

Browserless is headless Chrome as a service. Connect Puppeteer or Playwright to a remote browser over a websocket, or call its REST API to get rendered HTML, screenshots, PDFs and scraped data. This template runs Browserless v2 from the official image, pinned to release v2.63.2, behind a generated token.

## About Hosting Browserless 2.63 (Chromium)

Browserless is a single stateless service: it launches a fresh Chromium for each session and deletes the temporary profile afterwards, so no database or volume is needed. This template uses the official `ghcr.io/browserless/chromium:v2.63.2` image directly, with no wrapper or extra proxy. Every session, API, management and metrics route requires the generated `TOKEN` (as `?token=` or a Bearer header). The server listens on IPv4 and IPv6, so other services reach it over Railway's private network on port 3000. Session limits are sized for Railway: 5 concurrent sessions, a queue of 10 and a 5-minute session timeout, all adjustable. A healthcheck and restart-on-failure are set.

## Common Use Cases

- Give n8n, Flowise, LangChain or a browser-use agent a remote Chrome to browse, click and fill forms
- Take screenshots and generate PDFs of web pages or invoices from any language with one HTTP call
- Scrape JavaScript-heavy sites with Puppeteer or Playwright without installing Chrome in your app
- Run end-to-end tests or monitoring scripts against a shared browser

## Dependencies for Browserless 2.63 (Chromium) Hosting

- Browserless (`ghcr.io/browserless/chromium:v2.63.2`), public, token required

### Deployment Dependencies

- Browserless on GitHub: https://github.com/browserless/browserless
- Documentation: https://docs.browserless.io/
- Licence: https://github.com/browserless/browserless/blob/main/LICENSE

### Implementation Details

After deploy, open the **Browserless** service's Variables tab. Copy `BROWSER_WS_ENDPOINT` for Puppeteer, `BROWSER_PLAYWRIGHT_ENDPOINT` for Playwright, or `BROWSER_HTTP_ENDPOINT` and `TOKEN` for the REST API.

Screenshot with curl:

```bash
curl -s -X POST "https://your-domain/chromium/screenshot?token=YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com"}' -o example.png
```

Puppeteer:

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

Playwright (client 1.61 to 1.65):

```js
import { chromium } from "playwright-core";

const browser = await chromium.connect("wss://your-domain/chromium/playwright?token=YOUR_TOKEN");
```

From another service in the same project, reference the private endpoints, for example `${{Browserless.BROWSER_WS_ENDPOINT_PRIVATE}}` and `${{Browserless.BROWSER_TOKEN}}`. The connection variable names (`BROWSER_TOKEN`, `BROWSER_WS_ENDPOINT`, `BROWSER_PLAYWRIGHT_ENDPOINT`, their `_PRIVATE` versions, `BROWSER_DOMAIN`) match the older Railway Browserless templates; the private port is now 3000 and WebDriver endpoints are not included.

| Variable | Default | Purpose |
|---|---|---|
| `TOKEN` | generated | Required on every request |
| `CONCURRENT` | 5 | Sessions at the same time (a few hundred MB RAM each, typically) |
| `QUEUED` | 10 | Waiting requests before HTTP 429 |
| `TIMEOUT` | 300000 | Maximum session length in ms |

Other REST endpoints: `/chromium/content`, `/chromium/pdf`, `/chromium/scrape`, `/chromium/function`, `/json/version`, `/pressure`. The OpenAPI docs are at `/docs/`.

Security: anyone with the token can drive a browser from your service, including against your private network. Keep it secret and rotate it if it leaks.

Licence: Browserless is dual-licensed under SSPL-1.0 or the Browserless commercial licence. It is source-available, not OSI open source. Upstream requires a commercial licence for closed-source commercial sites, applications or CI systems, and the SSPL has obligations if you offer Browserless as a service to others. This template deploys the unmodified official image; choosing and complying with the right licence is your responsibility.

## Why Deploy Browserless 2.63 (Chromium) on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Browserless 2.63 (Chromium) on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
