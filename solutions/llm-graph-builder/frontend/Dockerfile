# Neo4j LLM Graph Builder web UI, built from the upstream release tag
# (github.com/neo4j-labs/llm-graph-builder, Apache-2.0) and served by nginx.
# nginx adds HTTP basic auth (upstream only offers Auth0) and proxies /api/ to the
# private Backend service, so the browser never talks to the backend or to Neo4j.
#
# VITE_* values are compiled into the JavaScript bundle at build time: change them,
# then redeploy (Railway rebuilds the image).

FROM node:20.20.2-bookworm-slim AS build
ARG LGB_VERSION=v0.8.7
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "${LGB_VERSION}" \
      https://github.com/neo4j-labs/llm-graph-builder.git /src
WORKDIR /src/frontend
RUN yarn install --frozen-lockfile --network-timeout 600000

# Same-origin API path: nginx below forwards /api/* to the backend.
ARG VITE_BACKEND_API_URL=/api
# Must match the LLM_MODEL_CONFIG_* variables set on the Backend service.
ARG VITE_LLM_MODELS=openai_gpt_5.4_mini,openai_gpt_5.5
ARG VITE_LLM_MODELS_PROD=openai_gpt_5.4_mini,openai_gpt_5.5
ARG VITE_REACT_APP_SOURCES=local,web,wiki,youtube
# Empty = upstream default: all chat modes, with "global search" hidden by the app when the
# backend reports no Graph Data Science plugin (Neo4j Community). Values are internal keys:
# vector, graph, graph_vector, fulltext, graph_vector_fulltext, entity_vector, global_vector.
ARG VITE_CHAT_MODES=""
# "Open in Bloom" button: the template points it at the Neo4j Browser of this project.
ARG VITE_BLOOM_URL=""
ARG VITE_ENV=DEV
ARG VITE_SKIP_AUTH=true
ARG VITE_TIME_PER_PAGE=50
ARG VITE_CHUNK_SIZE=5242880
ARG VITE_LARGE_FILE_SIZE=5242880
ARG VITE_BATCH_SIZE=2
ARG VITE_CHUNK_OVERLAP=20
ARG VITE_TOKENS_PER_CHUNK=200
ARG VITE_CHUNK_TO_COMBINE=1
RUN VITE_BACKEND_API_URL="$VITE_BACKEND_API_URL" \
    VITE_LLM_MODELS="$VITE_LLM_MODELS" \
    VITE_LLM_MODELS_PROD="$VITE_LLM_MODELS_PROD" \
    VITE_REACT_APP_SOURCES="$VITE_REACT_APP_SOURCES" \
    VITE_CHAT_MODES="$VITE_CHAT_MODES" \
    VITE_BLOOM_URL="$VITE_BLOOM_URL" \
    VITE_ENV="$VITE_ENV" \
    VITE_SKIP_AUTH="$VITE_SKIP_AUTH" \
    VITE_TIME_PER_PAGE="$VITE_TIME_PER_PAGE" \
    VITE_CHUNK_SIZE="$VITE_CHUNK_SIZE" \
    VITE_LARGE_FILE_SIZE="$VITE_LARGE_FILE_SIZE" \
    VITE_BATCH_SIZE="$VITE_BATCH_SIZE" \
    VITE_CHUNK_OVERLAP="$VITE_CHUNK_OVERLAP" \
    VITE_TOKENS_PER_CHUNK="$VITE_TOKENS_PER_CHUNK" \
    VITE_CHUNK_TO_COMBINE="$VITE_CHUNK_TO_COMBINE" \
    yarn run build

FROM nginx:1.30.6-alpine
RUN apk add --no-cache openssl \
    && rm -f /etc/nginx/conf.d/default.conf
COPY --from=build /src/frontend/dist /usr/share/nginx/html
# Runs from the image's entrypoint before nginx starts: writes the login file and the site config.
COPY 40-graph-builder.sh /docker-entrypoint.d/40-graph-builder.sh
RUN chmod +x /docker-entrypoint.d/40-graph-builder.sh
ENV PORT=8080
EXPOSE 8080
