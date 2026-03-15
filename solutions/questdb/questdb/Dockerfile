# Use official QuestDB image
# Can be overridden by Railway environment variable `QUESTDB_IMAGE_TAG`
ARG QUESTDB_IMAGE_TAG
FROM questdb/questdb:${QUESTDB_IMAGE_TAG:-latest}

# Wrapper to map Railway's dynamic PORT to QuestDB's HTTP/Console port
COPY entrypoint.sh /railway-entrypoint.sh
RUN chmod +x /railway-entrypoint.sh

ENTRYPOINT ["/railway-entrypoint.sh"]
