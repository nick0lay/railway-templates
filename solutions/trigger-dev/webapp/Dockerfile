# Trigger.dev webapp for Railway.
#
# Uses the Railway-patched image built from nick0lay/trigger.dev (dual-stack
# IPv6 for Redis/Postgres on Railway's private network, ClickHouse fixes) as is,
# including upstream's Prisma migrations.
#
# Earlier versions swapped those migrations for one consolidated migration with
# `rm -rf .../migrations/*` + COPY. Railway's builder kept the original files,
# so both sets ran and the first boot failed with
# `type "AuthenticationMethod" already exists`. Upstream's migrations apply in
# well under a minute on an empty database, so the swap isn't needed.
ARG TRIGGER_IMAGE_TAG=v4.0.0
FROM ghcr.io/nick0lay/trigger.dev-railway:${TRIGGER_IMAGE_TAG}
