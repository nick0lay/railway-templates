# Marqo — embedding inference and the search API.
#
# This template runs Marqo in EXTERNAL VECTOR STORE mode: given VESPA_CONFIG_URL,
# VESPA_QUERY_URL, VESPA_DOCUMENT_URL and ZOOKEEPER_HOSTS, run_marqo.sh skips
# starting its own Vespa entirely. That is what makes the template deployable —
# bundled together, Marqo and Vespa need ~1010 threads and Railway caps a
# container at 1000. Split out, this service runs on about 47.
#
# With Vespa elsewhere the only state worth keeping here is the downloaded model
# cache, and a volume mounts straight onto it. The entrypoint wrapper exists for
# a different reason — see railway-entrypoint.sh.
#
# NOTE ON TAGS: Marqo's `latest` is NOT the newest build. Upstream deprecated
# the open-source project after 2.16.1 (Mar 2025) and now publishes current
# releases only under `-cloud` tags. See README.md "Image Tags".
ARG MARQO_IMAGE_TAG
FROM marqoai/marqo:${MARQO_IMAGE_TAG:-latest}

COPY railway-entrypoint.sh /railway-entrypoint.sh
RUN chmod +x /railway-entrypoint.sh

# Run as root to avoid volume permission issues (Railway recommendation).
ENV RAILWAY_RUN_UID=0

# Private service — Caddy reaches it over Railway's internal network.
EXPOSE 8882

# Gates startup on the Vespa cluster being reachable. Railway has no service
# ordering, so without this Marqo crash-loops through a cold deploy.
ENTRYPOINT ["/railway-entrypoint.sh"]
