#!/bin/sh
# The Next.js Starter fetches regions, products and collections from Medusa
# while it builds, and Railway's private network is not reachable during image
# builds. So the storefront is built here, at container start, once Medusa is
# healthy (migrations done, publishable key registered).
set -e
cd /app

echo "storefront: waiting for $MEDUSA_BACKEND_URL/health"
node -e '
  const url = process.env.MEDUSA_BACKEND_URL + "/health";
  const end = Date.now() + 30 * 60 * 1000;
  (async function wait() {
    try { const r = await fetch(url); if (r.ok) process.exit(0); } catch {}
    if (Date.now() > end) { console.error("storefront: Medusa not healthy after 30 min"); process.exit(1); }
    setTimeout(wait, 5000);
  })();'

echo "storefront: building"
yarn build
echo "storefront: starting"
exec node_modules/.bin/next start -H 0.0.0.0 -p "${PORT:-8000}"
