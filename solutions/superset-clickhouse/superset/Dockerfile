# Apache Superset with the drivers this template needs. The official image ships
# without database drivers: psycopg2 for the Postgres metadata database and
# clickhouse-connect for ClickHouse are added here, pinned to the versions
# Superset 6.1 accepts (clickhouse-connect >= 0.13, < 1.0).
# To upgrade Superset, change the tag and check the driver ranges in Superset's
# pyproject.toml (the "postgres" and "clickhouse" extras).
FROM apache/superset:6.1.0

USER root
RUN . /app/.venv/bin/activate \
    && uv pip install --no-cache-dir psycopg2-binary==2.9.9 clickhouse-connect==0.15.1
USER superset
