# SoduWork Hub built from a pinned upstream release tag (https://github.com/mdiri-ai/soduwork).
# The stages mirror upstream ops/self-host/Dockerfile at that tag, with three changes:
#   - sources come from a git clone of SODUWORK_TAG instead of the build context;
#   - postgresql-client-18 instead of 16, so in-app backups work against Postgres 18;
#   - the image starts as root in entrypoint.sh, which links all state to one volume at /data
#     and then runs the upstream command as the soduwork user (uid 10001).
# Upgrade: change SODUWORK_TAG and compare upstream's ops/self-host/Dockerfile with this file.
ARG SODUWORK_TAG=v1.13.19
ARG NODE_IMAGE=node:22-bookworm-slim
ARG PYTHON_IMAGE=python:3.12-slim-bookworm

FROM alpine:3.22 AS src
ARG SODUWORK_TAG
RUN apk add --no-cache git \
    && git clone --depth 1 --branch "${SODUWORK_TAG}" https://github.com/mdiri-ai/soduwork.git /src \
    && rm -rf /src/.git

FROM ${NODE_IMAGE} AS admin-build
WORKDIR /build/hub-frontend
COPY --from=src /src/hub-frontend/package.json /src/hub-frontend/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY --from=src /src/hub-frontend/src ./src
COPY --from=src /src/hub-frontend/public ./public
COPY --from=src /src/hub-frontend/index.html /src/hub-frontend/vite.config.js ./
COPY --from=src /src/client/core/connector-brand.js /build/client/core/connector-brand.js
COPY --from=src /src/client/components/panels/connector-config.js /build/client/components/panels/connector-config.js
COPY --from=src /src/client/components/client-auth/legal-html.js /build/client/components/client-auth/legal-html.js
COPY --from=src /src/client/components/client-auth/legal-html.css /build/client/components/client-auth/legal-html.css
COPY --from=src /src/client/assets/connector-brands /build/client/assets/connector-brands
RUN npm run build

FROM ${NODE_IMAGE} AS node-runtime

FROM ${PYTHON_IMAGE} AS runtime
ENV PYTHONUNBUFFERED=1 PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
       | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" \
       > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update && apt-get install -y --no-install-recommends git openssh-client \
       chromium fonts-noto-cjk postgresql-client-18 \
    && apt-get purge -y --auto-remove curl gnupg && rm -rf /var/lib/apt/lists/*
COPY --from=node-runtime /usr/local/bin/node /usr/local/bin/node
COPY --from=node-runtime /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && npm install -g --no-audit --no-fund \
       @earendil-works/pi-coding-agent@0.83.0 \
       @openai/codex@0.147.0
COPY --from=node-runtime /usr/local/LICENSE /usr/local/LICENSE.nodejs
WORKDIR /srv/app/hub-backend
COPY --from=src /src/hub-backend/requirements.txt ./requirements.txt
RUN python -m pip install -r requirements.txt
COPY --from=src /src/hub-backend/app ./app
COPY --from=src /src/hub-backend/migrations ./migrations
COPY --from=src /src/hub-backend/jiyong-alembic.ini ./jiyong-alembic.ini
COPY --from=src /src/hub-backend/jiyong-migrations ./jiyong-migrations
COPY --from=src /src/hub-backend/installers ./installers
COPY --from=src /src/hub-backend/plugins ./plugins
COPY --from=src /src/hub-backend/alembic.ini ./alembic.ini
COPY --from=src /src/hub-backend/db_admin.py ./db_admin.py
COPY --from=src /src/hub-backend/full_backup.py ./full_backup.py
COPY --from=src /src/hub-backend/runner_main.py ./runner_main.py
COPY --from=src /src/hub-backend/pack_plugin.py ./pack_plugin.py
COPY --from=src /src/hub-backend/requirements-runner.txt ./
COPY --from=src /src/hub-backend/import_client_release.py ./import_client_release.py
COPY --from=src /src/hub-backend/ops_publish_builtin_plugins.py ./ops_publish_builtin_plugins.py
COPY --from=src /src/hub-backend/client-update-trust.json ./client-update-trust.json
COPY --from=admin-build /build/hub-frontend/dist /srv/app/hub-frontend/dist
COPY --from=src /src/skills /srv/app/skills
COPY --from=src /src/third-party /srv/app/third-party
COPY --from=src /src/LICENSE /srv/app/LICENSE
RUN groupadd --gid 10001 soduwork && useradd --uid 10001 --gid 10001 --create-home soduwork \
    && mkdir -p uploads downloads client-releases workspaces releases /srv/runtime /srv/app/repos \
    && chown -R 10001:10001 /srv/app /srv/runtime
COPY entrypoint.sh /usr/local/bin/soduwork-entrypoint
RUN chmod 0755 /usr/local/bin/soduwork-entrypoint
ENV SODUWORK_SHOT_BROWSER=/usr/bin/chromium SODUWORK_DATA_ROOT=/srv/runtime

ARG SODUWORK_TAG
ENV SODUWORK_DEPLOY_COMMIT="${SODUWORK_TAG}" \
    SODUWORK_RELEASE_TAG="${SODUWORK_TAG}" \
    SODUWORK_DEPLOY_AT=""
LABEL org.opencontainers.image.title="SoduWork Hub" \
      org.opencontainers.image.version="${SODUWORK_TAG}"
EXPOSE 8989
ENTRYPOINT ["/usr/local/bin/soduwork-entrypoint"]
CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8989"]
