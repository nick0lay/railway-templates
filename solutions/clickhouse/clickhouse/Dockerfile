# ClickHouse for Railway, from the official prebuilt image.
#
# CLICKHOUSE_IMAGE_TAG picks the image. An empty value (the template default)
# falls back to the newest ClickHouse LTS release tested with this template.
# .github/workflows/clickhouse-lts.yml opens a PR when a newer LTS is out;
# test it with the template before merging. Don't use `latest` here: monthly
# releases are supported for 3 months and ClickHouse can't be downgraded.
ARG CLICKHOUSE_IMAGE_TAG
FROM clickhouse/clickhouse-server:${CLICKHOUSE_IMAGE_TAG:-26.8}

COPY network.xml /etc/clickhouse-server/config.d/railway-network.xml
COPY system-logs.xml /etc/clickhouse-server/config.d/railway-system-logs.xml

EXPOSE 8123
