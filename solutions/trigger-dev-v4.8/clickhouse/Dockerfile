# ClickHouse for Trigger.dev.
#
# Pinned, not `latest`: a new ClickHouse release can reject Trigger.dev's
# migrations. 26.10 rejects migration 022 (errors_v1, an AggregatingMergeTree
# with plain columns outside the sorting key) unless the MergeTree setting
# below is on. Upgrading the pin is safe; going back to an older ClickHouse is
# not, because older versions can't read data written by newer ones.
ARG CLICKHOUSE_IMAGE_TAG=26.10
FROM clickhouse/clickhouse-server:${CLICKHOUSE_IMAGE_TAG}

COPY trigger-dev.xml /etc/clickhouse-server/config.d/trigger-dev.xml
