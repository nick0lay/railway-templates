# Apache Kafka 4.4 + Kafka UI

Deploy Apache Kafka 4.4 on Railway in KRaft mode (no ZooKeeper), with a persistent volume, a private listener for your Railway services, a SASL-protected TCP proxy for outside clients, and Kafka UI behind a login.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/apache-kafka-44?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Overview

- **Kafka**: one node that is both broker and KRaft controller, from the official `apache/kafka:4.4.0` image
- **Volume** at `/var/lib/kafka` (log directory `/var/lib/kafka/data`), so topics and messages survive redeploys
- **Private listener** on port 9092: plaintext, reachable only from services in the same Railway project
- **External listener** on port 9094 behind a Railway TCP proxy: SASL/SCRAM-SHA-512 with a generated password
- **Kafka UI** (`ghcr.io/kafbat/kafka-ui:v1.5.0`): web console for topics, messages, consumer groups and broker settings, behind a login form

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                            Internet                              │
└───────────────┬───────────────────────────────────┬──────────────┘
                │ HTTPS (public domain)             │ TCP proxy
                ▼                                   │ (SASL/SCRAM-SHA-512)
┌───────────────────────────────┐                   │
│ Kafka UI (public, login form) │                   │
│ PORT=8080                     │                   │
└───────────────┬───────────────┘                   │
                │ kafka.railway.internal:9092       │ <proxy-domain>:<port> → 9094
                ▼                                   ▼
┌──────────────────────────────────────────────────────────────────┐
│ Kafka 4.4 (KRaft: broker + controller)                           │
│                                                                  │
│   9092 INTERNAL   plaintext, private network (your services)     │
│   9093 CONTROLLER localhost only                                 │
│   9094 EXTERNAL   SASL_PLAINTEXT, SCRAM-SHA-512 (TCP proxy)      │
│                                                                  │
│        ┌──────────────────────────────────────┐                  │
│        │  /var/lib/kafka  (volume)            │                  │
│        └──────────────────────────────────────┘                  │
└──────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Kafka | `apache/kafka:4.4.0` | Broker and KRaft controller. Private listener plus SASL listener on a TCP proxy |
| Kafka UI | `ghcr.io/kafbat/kafka-ui:v1.5.0` | Web console (public, login form) |

Both are upstream images. Kafka starts from a short script kept in the `KAFKA_RUN_SH` variable: it writes `server.properties`, formats the volume on the first start, and sets the SASL user.

## Environment Variables

### Kafka: User-Configurable

| Variable | Default | Description |
|----------|---------|-------------|
| `KAFKA_SASL_USERNAME` | `kafka` | User name for clients outside Railway |
| `KAFKA_SASL_PASSWORD` | generated (32 letters and digits) | Password for that user. Re-applied on every start, so changing it and redeploying rotates it. Avoid `,` `=` `]` and `"` if you set your own |
| `KAFKA_HEAP_OPTS` | `-Xms512m -Xmx512m` | Broker JVM heap. Raise it (and the service memory) for heavier traffic |
| `KAFKA_LOG_RETENTION_HOURS` | `168` | How long messages are kept (7 days) |
| `KAFKA_LOG_RETENTION_BYTES` | `-1` | Size limit per partition before old segments are deleted. `-1` means no limit, so watch the volume |
| `KAFKA_NUM_PARTITIONS` | `1` | Partitions for automatically created topics |
| `KAFKA_AUTO_CREATE_TOPICS` | `true` | Create a topic on first produce |
| `KAFKA_EXTRA_PROPERTIES` | empty | Extra `server.properties` lines, one per line, appended last (for example `message.max.bytes=5242880`) |

### Kafka: Auto-Configured (Do Not Change)

| Variable | Value | Why |
|----------|-------|-----|
| `KAFKA_BOOTSTRAP_SERVERS` | `${{RAILWAY_PRIVATE_DOMAIN}}:9092` | Reference it from other services: `${{Kafka.KAFKA_BOOTSTRAP_SERVERS}}` |
| `KAFKA_PUBLIC_BOOTSTRAP_SERVERS` | `${{RAILWAY_TCP_PROXY_DOMAIN}}:${{RAILWAY_TCP_PROXY_PORT}}` | Bootstrap address for clients outside Railway |
| `KAFKA_DATA_DIR` | `/var/lib/kafka/data` | Log directory inside the volume (a sub-folder, so the volume's `lost+found` is not read as a partition) |
| `RAILWAY_RUN_UID` | `0` | Runs the container as root so Kafka can write to the Railway volume |
| `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` | `60` | Gives Kafka time to shut down cleanly on redeploy |
| `KAFKA_RUN_SH` | script | Start script. Edit only if you know Kafka's listener settings |

The advertised addresses come from Railway: `RAILWAY_PRIVATE_DOMAIN` for the private listener, `RAILWAY_TCP_PROXY_DOMAIN` and `RAILWAY_TCP_PROXY_PORT` for the external one. If you remove the TCP proxy, Kafka starts with the private listener only.

### Kafka UI

| Variable | Default | Description |
|----------|---------|-------------|
| `SPRING_SECURITY_USER_NAME` | `admin` | Login user |
| `SPRING_SECURITY_USER_PASSWORD` | generated | Login password |
| `AUTH_TYPE` | `LOGIN_FORM` | Keep it: the UI is on a public domain |
| `KAFKA_CLUSTERS_0_NAME` | `railway` | Cluster name shown in the UI |
| `KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS` | `${{Kafka.RAILWAY_PRIVATE_DOMAIN}}:9092` | Connects over the private network |
| `DYNAMIC_CONFIG_ENABLED` | `false` | Cluster settings come from variables, not the UI |
| `SERVER_FORWARDHEADERSSTRATEGY` | `framework` | Trust Railway's proxy headers so redirects stay on HTTPS |
| `JAVA_OPTS` | `-Xms128m -Xmx384m` | UI JVM heap |
| `PORT` | `8080` | Port Railway routes the public domain to |

## Connecting

### From a service in the same Railway project

Set a variable on your service:

```
KAFKA_BOOTSTRAP_SERVERS=${{Kafka.KAFKA_BOOTSTRAP_SERVERS}}
```

No authentication or TLS: the private network is only reachable from your project. Railway's private network uses IPv6; the broker listens on both IPv6 and IPv4.

### From outside Railway

Read `KAFKA_PUBLIC_BOOTSTRAP_SERVERS`, `KAFKA_SASL_USERNAME` and `KAFKA_SASL_PASSWORD` from the Kafka service variables, then create `client.properties`:

```properties
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="kafka" password="<password>";
```

```bash
B=<proxy-domain>:<port>
kafka-topics.sh --bootstrap-server $B --command-config client.properties --create --topic orders
echo "hello" | kafka-console-producer.sh --bootstrap-server $B --command-config client.properties --topic orders
kafka-console-consumer.sh --bootstrap-server $B --command-config client.properties --topic orders --from-beginning
```

Other clients use the same settings, for example in Python (`confluent-kafka`):

```python
conf = {
    "bootstrap.servers": "<proxy-domain>:<port>",
    "security.protocol": "SASL_PLAINTEXT",
    "sasl.mechanisms": "SCRAM-SHA-512",
    "sasl.username": "kafka",
    "sasl.password": "<password>",
}
```

The TCP proxy checks the password but does not encrypt traffic. Use it for development and for data that may cross the internet unencrypted. Otherwise keep clients on Railway's private network, and delete the TCP proxy in the Kafka service's Networking settings if you don't need it.

## Backups

Kafka keeps its data in the log directory on the volume. Options:

- **Railway volume backups**: enable them on the Kafka volume (service → Volume → Backups) for scheduled snapshots.
- **Replicate to another cluster** with MirrorMaker 2 when you need an off-platform copy.
- **Sink topics** you can't lose into a database or object storage with Kafka Connect.

## Cost and plan

The two services idle at about 0.9 GB of RAM together (measured: Kafka about 0.45 GB with the default 512 MB heap, Kafka UI about 0.4 GB), so the Hobby plan is enough to start. Disk use grows with your retention settings: set `KAFKA_LOG_RETENTION_HOURS` or `KAFKA_LOG_RETENTION_BYTES` to fit the volume, and grow the volume in the service settings when needed.

## Troubleshooting

- **Clients time out after connecting**: Kafka returns its advertised address after the first connection. Outside Railway, use `KAFKA_PUBLIC_BOOTSTRAP_SERVERS`; inside, use `KAFKA_BOOTSTRAP_SERVERS`. Don't mix them.
- **`Authentication failed ... SCRAM-SHA-512`**: check the user name and password, and set `sasl.mechanism=SCRAM-SHA-512` (not `PLAIN`).
- **Logs say "no TCP proxy on this service"**: the TCP proxy was removed. Add one for port 9094 under Networking, then redeploy.
- **`... is not writable`**: `RAILWAY_RUN_UID` must be `0`, and the volume must be mounted at `/var/lib/kafka`.
- **Broker killed or slow**: raise `KAFKA_HEAP_OPTS` and the service memory together; keep the heap at about half of the memory.
- **Volume full**: lower retention, delete unused topics in Kafka UI, or grow the volume.
- **Kafka UI shows the cluster offline**: Kafka is still starting, or `KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS` was changed. It should be `${{Kafka.RAILWAY_PRIVATE_DOMAIN}}:9092`.

## Next steps

A Kafka Connect / Debezium variant for change data capture from Postgres is planned as a separate template.

## Testing

Tested on 2026-11-09: clean deploy from the template, topic created and a message produced and consumed through the SASL TCP proxy, wrong password rejected, Kafka UI login (wrong password rejected), topic created and message produced and read back through Kafka UI over the private listener, and data still there after a Kafka redeploy.
