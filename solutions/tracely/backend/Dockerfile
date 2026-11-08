# Tracely backend image, used by both the `backend` (API) and `worker` services.
#
# Upstream publishes no images and no release tags, so this builds Tracely from
# source at a pinned commit. TRACELY_REF picks the commit (any commit SHA from
# https://github.com/jwuthri-cloud/tracely-ai/commits/main). An empty value falls
# back to the commit tested with this template.
FROM python:3.12-slim

ARG TRACELY_REF
ENV PYTHONUNBUFFERED=1 PIP_DISABLE_PIP_VERSION_CHECK=1
# build tools for sdist deps (hdbscan / umap / numba fall back to source on some platforms)
RUN apt-get update && apt-get install -y --no-install-recommends build-essential curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir uv

WORKDIR /app
RUN ref="${TRACELY_REF:-128a5d806704ca88fca03dff0a0215c8a557b779}" \
    && curl -fsSL "https://codeload.github.com/jwuthri-cloud/tracely-ai/tar.gz/${ref}" \
       | tar -xz --strip-components=1 \
         --wildcards '*/pyproject.toml' '*/uv.lock' '*/backend' '*/workers' '*/sdk' '*/scripts' \
    && uv sync --frozen --all-packages

ENV PATH="/app/.venv/bin:${PATH}"
COPY start.sh /usr/local/bin/railway-start.sh
EXPOSE 8000
# TRACELY_ROLE=api: migrations (ClickHouse, Postgres, LangGraph checkpointer, seed, S3 bucket), then the API.
# TRACELY_ROLE=worker: waits for the API, then the Celery worker (with beat when CELERY_BEAT=true).
CMD ["sh", "/usr/local/bin/railway-start.sh"]
