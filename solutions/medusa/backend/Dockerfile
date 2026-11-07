# Medusa v2 server and worker. The same image runs both; MEDUSA_WORKER_MODE picks the role.
ARG NODE_IMAGE=node:22.23.4-bookworm-slim

FROM ${NODE_IMAGE} AS build
# package-lock.json was written by npm 11; npm 10 (bundled with Node 22) rejects it.
RUN npm install -g npm@11.1.0 --no-audit --no-fund
WORKDIR /app
COPY package.json package-lock.json .npmrc ./
RUN npm ci --no-audit --no-fund
COPY . .
RUN npx medusa build \
 && cd .medusa/server \
 && (test -f package-lock.json || cp ../../package-lock.json .) \
 && cp ../../.npmrc . \
 && npm ci --omit=dev --no-audit --no-fund

FROM ${NODE_IMAGE}
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build /app/.medusa/server ./
COPY start.sh ./start.sh
EXPOSE 9000
CMD ["sh", "start.sh"]
