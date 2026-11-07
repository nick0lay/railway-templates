# Medusa Next.js Starter Storefront, built from the official repository at a pinned commit.
ARG NODE_IMAGE=node:22.23.4-bookworm-slim
FROM ${NODE_IMAGE}

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# github.com/medusajs/nextjs-starter-medusa, main on 2026-04-23
ARG STOREFRONT_REF=9818886f06e493cb2249733d114d339aa216ef00
WORKDIR /app
RUN git init -q . \
 && git remote add origin https://github.com/medusajs/nextjs-starter-medusa \
 && git fetch -q --depth 1 origin "$STOREFRONT_REF" \
 && git checkout -q FETCH_HEAD \
 && rm -rf .git

RUN corepack enable && yarn install --immutable

COPY next.config.js ./next.config.js
COPY healthcheck-route.ts ./src/app/api/healthcheck/route.ts

COPY start.sh ./start.sh

ENV NEXT_TELEMETRY_DISABLED=1 NODE_ENV=production
EXPOSE 8000
CMD ["sh", "start.sh"]
