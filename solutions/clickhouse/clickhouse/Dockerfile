# ClickHouse for Railway, from the official prebuilt image.
#
# CLICKHOUSE_IMAGE_TAG picks the image. An empty value falls back to the tested
# default below instead of silently using `latest`.
ARG CLICKHOUSE_IMAGE_TAG
FROM clickhouse/clickhouse-server:${CLICKHOUSE_IMAGE_TAG:-25.8}

COPY network.xml /etc/clickhouse-server/config.d/railway-network.xml
COPY system-logs.xml /etc/clickhouse-server/config.d/railway-system-logs.xml

EXPOSE 8123
