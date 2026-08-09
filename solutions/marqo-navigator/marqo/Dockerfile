# Marqo — vector search engine (embedding inference + Vespa vector store).
#
# Can be overridden by Railway environment variable `MARQO_IMAGE_TAG`.
#
# NOTE ON TAGS: unlike most projects, Marqo's `latest` is NOT the newest build.
# Upstream deprecated the open-source project after 2.16.1 (Mar 2025) and now
# publishes current releases only under `-cloud` tags. See the Image Tags table
# in README.md before changing this.
ARG MARQO_IMAGE_TAG
FROM marqoai/marqo:${MARQO_IMAGE_TAG:-latest}

# Wrapper that adapts the image to Railway's one-volume-per-service limit.
COPY railway-entrypoint.sh /railway-entrypoint.sh
RUN chmod +x /railway-entrypoint.sh

# Vespa ships a directory skeleton under /opt/vespa/var (config server state,
# bundle cache, run dirs). Mounting a volume over that path hides it, so stash a
# pristine copy the entrypoint can seed an empty volume from.
RUN mkdir -p /opt/vespa-var-default && \
    cp -a /opt/vespa/var/. /opt/vespa-var-default/ 2>/dev/null || true

# Run as root to avoid volume permission issues (Railway recommendation).
# The upstream image already runs as root; this makes it explicit.
ENV RAILWAY_RUN_UID=0

# The API listens on 8882. This service is private — Caddy reaches it over
# Railway's internal network, so no PORT juggling is needed.
EXPOSE 8882

ENTRYPOINT ["/railway-entrypoint.sh"]
CMD ["./run_marqo.sh"]
