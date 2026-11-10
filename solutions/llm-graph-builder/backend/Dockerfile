# Neo4j LLM Graph Builder backend (FastAPI), built from the upstream release tag
# (github.com/neo4j-labs/llm-graph-builder, Apache-2.0). Same packages as the
# upstream backend/Dockerfile; differences are in the start command at the end.

FROM python:3.12.16-slim-bookworm
ARG LGB_VERSION=v0.8.7
RUN apt-get update && apt-get install -y --no-install-recommends \
        libmagic1 libgl1 libglib2.0-0 libglx-mesa0 libgomp1 libreoffice cmake \
        poppler-utils tesseract-ocr git ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1
RUN git clone --depth 1 --branch "${LGB_VERSION}" \
      https://github.com/neo4j-labs/llm-graph-builder.git /src \
    && mkdir -p /code && cp -a /src/backend/. /code/ && rm -rf /src
WORKDIR /code
RUN pip install --upgrade pip && pip install -r requirements.txt
# Local embedding model (used when EMBEDDING_PROVIDER=sentence-transformer) and NLTK data, as upstream.
RUN python -c "from transformers import AutoTokenizer, AutoModel; \
name='sentence-transformers/all-MiniLM-L6-v2'; \
AutoTokenizer.from_pretrained(name).save_pretrained('./local_model'); \
AutoModel.from_pretrained(name).save_pretrained('./local_model')" \
    && python -m nltk.downloader -d /usr/local/nltk_data punkt averaged_perceptron_tagger
ENV PORT=8000
EXPOSE 8000
# Upstream starts 8 gunicorn workers on 0.0.0.0. Here:
# - [::] so Railway's private network (IPv6) reaches it;
# - one worker by default: each worker loads its own copy of the libraries, and upload
#   chunks, chat sessions and the credential cache live in one process's memory.
ENV WEB_CONCURRENCY=1
CMD ["sh", "-c", "exec gunicorn score:app --workers ${WEB_CONCURRENCY} --worker-class uvicorn.workers.UvicornWorker --bind [::]:${PORT} --timeout 600 --graceful-timeout 60"]
