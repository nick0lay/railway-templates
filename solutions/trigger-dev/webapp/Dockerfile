# Trigger.dev webapp for Railway.
#
# Starts from the Railway-patched image built from nick0lay/trigger.dev
# (IPv6 dual-stack Redis/Postgres connections and ClickHouse fixes), then swaps
# upstream's ~700 Prisma migrations for one consolidated migration so the first
# boot on an empty database is fast.
#
# The image tag, consolidated migration and schema.prisma must all come from the
# same Trigger.dev version. Change them together.
ARG TRIGGER_IMAGE_TAG=v4.0.0
FROM ghcr.io/nick0lay/trigger.dev-railway:${TRIGGER_IMAGE_TAG}

USER root

RUN rm -rf /triggerdotdev/internal-packages/database/prisma/migrations/*
COPY consolidated-migration/ /triggerdotdev/internal-packages/database/prisma/migrations/
COPY schema.prisma /triggerdotdev/internal-packages/database/prisma/schema.prisma
RUN chown -R node:node /triggerdotdev/internal-packages/database/prisma

USER node

CMD ["./scripts/entrypoint.sh"]
