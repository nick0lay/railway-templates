# DataCat (https://github.com/replit/datacat) built from a pinned upstream commit.
# Upstream publishes no image or releases yet. The two app stages mirror upstream's root Dockerfile at that
# commit, with three additions:
#   - sources come from a fetch of DATACAT_REF instead of the build context;
#   - an agent stage builds the DataCat Agent for linux/amd64 and linux/arm64 into /app/downloads, so the
#     server's one-line installer (/install.sh) works for your hosts;
#   - start.mjs waits for Postgres and ClickHouse, starts the server and creates the first admin from
#     ADMIN_EMAIL / ADMIN_PASSWORD through the first-run setup API.
# Upgrade: change DATACAT_REF and compare upstream's Dockerfile and agent/release.sh with this file.
ARG DATACAT_REF=6c6c9859c0bfbb05f075479cd781df9f2cf80727

FROM alpine:3.22 AS src
ARG DATACAT_REF
RUN apk add --no-cache git \
    && git init -q /src && cd /src \
    && git remote add origin https://github.com/replit/datacat.git \
    && git fetch -q --depth 1 origin "${DATACAT_REF}" \
    && git checkout -q FETCH_HEAD \
    && rm -rf .git

FROM node:22-bookworm-slim AS build
WORKDIR /app
RUN corepack enable && corepack prepare pnpm@10.11.0 --activate
COPY --from=src /src/ .
RUN pnpm install --frozen-lockfile --filter @workspace/api-server... --filter @workspace/web...
RUN BASE_PATH=/ pnpm run build:selfhost

FROM golang:1.26.11-bookworm AS agent
COPY --from=src /src/agent /src/agent
WORKDIR /src/agent
RUN CGO_ENABLED=0 GOFLAGS=-buildvcs=false bash -c '\
      set -euo pipefail; \
      GOBIN=/usr/local/bin go install go.opentelemetry.io/collector/cmd/builder@v0.165.0; \
      builder --config manifest.yaml --skip-compilation; \
      cp main.go config.go logoperator.go config_test.go logoperator_test.go _build/; \
      cd _build; go mod edit -toolchain=go1.26.11; go mod tidy; \
      mkdir -p /out; \
      for arch in amd64 arm64; do \
        CGO_ENABLED=0 GOOS=linux GOARCH=$arch go build -p 2 -trimpath -tags grpcnotrace -ldflags="-s -w" \
          -o /out/datacat-agent-linux-$arch . ; \
      done; \
      cd /out && sha256sum datacat-agent-* > SHA256SUMS'

FROM node:22-bookworm-slim AS runtime
ENV NODE_ENV=production PORT=3000 DATACAT_DOWNLOADS_DIR=/app/downloads
WORKDIR /app
RUN mkdir -p /app/downloads && chown node:node /app/downloads
COPY --from=build --chown=node:node /app/artifacts/api-server/dist ./artifacts/api-server/dist
COPY --from=build --chown=node:node /app/artifacts/web/dist ./artifacts/web/dist
COPY --from=build --chown=node:node /app/LICENSE /app/NOTICE /app/THIRD_PARTY_LICENSES.md ./
COPY --from=agent --chown=node:node /out/ /app/downloads/
COPY --chown=node:node start.mjs /app/start.mjs
ARG DATACAT_REF
ENV DATACAT_REF=${DATACAT_REF}
LABEL org.opencontainers.image.title="DataCat" org.opencontainers.image.revision="${DATACAT_REF}"
USER node
EXPOSE 3000
CMD ["node", "/app/start.mjs"]
