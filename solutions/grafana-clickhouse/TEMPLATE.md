# Deploy and Host Grafana + ClickHouse on Railway

Grafana is the open-source platform for dashboards, alerts and data exploration. ClickHouse is a fast open-source column database for analytics, logs and time series. Together they make a self-hosted analytics and observability stack: load events, logs or metrics into ClickHouse and chart them in Grafana with plain SQL.

## About Hosting Grafana + ClickHouse

Grafana needs the ClickHouse data source plugin, a data source configured with the database's host and credentials, and persistent storage for its own database of users and dashboards. ClickHouse needs a volume, a password on its account, and settings that keep its internal log tables from filling a small disk. On Railway the two also have to reach each other over the IPv6 private network. A fresh Grafana logs in with `admin`/`admin`, so the password should be changed before the URL is shared.

This template does all of that at deploy. The official ClickHouse plugin is installed at a pinned version, the data source is provisioned and connected over the private network, and a starter dashboard shows what is in ClickHouse. The admin password is generated, sign-up is off, and both services keep their data on volumes.

## Common Use Cases

- Product and business analytics dashboards on event data in ClickHouse
- Log and metrics exploration with SQL, as a lighter alternative to Elasticsearch and Kibana
- Real-time dashboards for IoT, ad-tech or trading data
- Alerts on ClickHouse queries (thresholds, error rates, missing data)
- A shared analytics database for several apps in one Railway project, with Grafana on top

## Dependencies for Grafana + ClickHouse Hosting

- Grafana 13.3
- ClickHouse 26.8 (LTS)

### Deployment Dependencies

- Grafana: https://github.com/grafana/grafana
- ClickHouse data source plugin: https://github.com/grafana/clickhouse-datasource
- ClickHouse: https://github.com/ClickHouse/ClickHouse

### Implementation Details

**What you set:** nothing. All passwords are generated.

**After deploy:**

1. Open the Grafana URL and log in as `admin` with the generated `GF_SECURITY_ADMIN_PASSWORD` (Grafana service → Variables).
2. Open Dashboards → ClickHouse → ClickHouse overview.
3. Load data into ClickHouse with `CLICKHOUSE_PUBLIC_URL` (from outside Railway) or `CLICKHOUSE_URL` (from apps in the project), then build panels with the ClickHouse data source.

**This template:**

- Installs the official ClickHouse plugin (4.23.5) before Grafana starts
- Provisions the ClickHouse data source from the ClickHouse service's variables, over the private network
- Adds a starter dashboard: version, uptime, storage, rows, queries per minute, largest tables, slowest queries
- Generates the Grafana admin password and turns off sign-up and anonymous access
- Keeps Grafana's database and ClickHouse's data on volumes
- Gives ClickHouse a generated password, IPv6 and IPv4 listening, and small internal log tables
- Pins Grafana 13.3.1, plugin 4.23.5 and ClickHouse 26.8, with healthchecks on both services

**Notes:** ClickHouse has a public HTTPS domain so you can load data from outside Railway; it requires the generated password. Remove the domain if all your data comes from inside the project. Grafana alert emails need SMTP variables (see the README).

## Why Deploy Grafana + ClickHouse on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Grafana + ClickHouse on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
