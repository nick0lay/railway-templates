# Railway's Postgres 17 image (SSL, volume handling) plus pg_partman, which
# Lago's database schema requires (it partitions the enriched events table).
FROM ghcr.io/railwayapp-templates/postgres-ssl:17

RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-17-partman \
 && rm -rf /var/lib/apt/lists/*
