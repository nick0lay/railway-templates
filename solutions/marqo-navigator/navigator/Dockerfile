# Marqo Navigator — admin UI and search console for Marqo.
#
# Can be overridden by Railway environment variable `NAVIGATOR_IMAGE_TAG`.
ARG NAVIGATOR_IMAGE_TAG
FROM viljarfivexer/marqo-navigator:${NAVIGATOR_IMAGE_TAG:-v0.1.19}

WORKDIR /app

# The upstream published image crashes on boot. Its Dockerfile runs an unpinned
# `npm install express`, which resolved to Express 5 after Oct 2024. Express 5
# rejects the bare `app.get('*')` wildcard that the proxy registers in
# src/proxy/index.mjs, so the process dies with "TypeError: Missing parameter
# name at 1" before it ever listens.
#
# Pinning Express 4 at build time is the fix. Doing it here rather than at
# container start keeps deploys hermetic — no npm registry call on boot.
RUN npm install express@4 --no-audit --no-fund

EXPOSE 9882

# Serves the built SPA, proxies /proxy/* to Marqo, exposes /metrics to
# Prometheus. MARQO_API_URL points it at the Marqo service.
CMD ["node", "--experimental-modules", "./runtime/proxy/index.mjs"]
