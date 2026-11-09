# Deploy and Host Apache Kafka 4.4 on Railway

Apache Kafka is the open-source event streaming platform used for message queues, event-driven microservices, change data capture and real-time data pipelines. Kafka 4 runs in KRaft mode, without ZooKeeper. This template adds Kafka UI, a web console to browse topics, messages and consumer groups.

## About Hosting Apache Kafka 4.4

Kafka needs a persistent log directory, listeners that clients can actually reach, and a sensible heap size. On Railway that means binding to the IPv6 private network, advertising the right host names for private and public clients, and keeping the broker away from the open internet unless it asks for credentials. Many Kafka images and templates still use ZooKeeper, the `latest` tag, or a listener with no authentication.

This template runs one Kafka 4.4 node in KRaft mode (broker and controller in one process) from the official `apache/kafka` image, with a volume for the log directory. Services in your Railway project connect over the private network. Clients outside Railway connect through a TCP proxy that requires a SASL/SCRAM-SHA-512 user name and password. Kafka UI is the only public web service, and it has a login form.

## Common Use Cases

- Event bus for microservices: publish domain events once, consume them in many services
- Message queue and background job pipelines with replay and consumer groups
- Change data capture (CDC) streams from Postgres or MySQL with Debezium or Kafka Connect
- Log, metrics and clickstream ingestion into ClickHouse, Elasticsearch or a data lake
- A Kafka development and staging cluster for testing producers and consumers

## Dependencies for Apache Kafka 4.4 Hosting

- Apache Kafka 4.4.0 (official `apache/kafka` image)
- Kafka UI v1.5.0 (`ghcr.io/kafbat/kafka-ui`)

### Deployment Dependencies

- Apache Kafka: https://kafka.apache.org/
- Kafka documentation: https://kafka.apache.org/documentation/
- Kafka UI (kafbat): https://github.com/kafbat/kafka-ui

### Implementation Details

**What you set:** nothing. Optionally `KAFKA_SASL_USERNAME` (default `kafka`) and `SPRING_SECURITY_USER_NAME` (default `admin`).

**After deploy:**

1. Open the Kafka UI URL and log in with `SPRING_SECURITY_USER_NAME` and the generated `SPRING_SECURITY_USER_PASSWORD` (Kafka UI service → Variables).
2. From another service in the same project, set `KAFKA_BOOTSTRAP_SERVERS=${{Kafka.KAFKA_BOOTSTRAP_SERVERS}}` (plaintext, private network).
3. From outside Railway, use `KAFKA_PUBLIC_BOOTSTRAP_SERVERS` (Kafka service → Variables) with SASL:

```properties
bootstrap.servers=<KAFKA_PUBLIC_BOOTSTRAP_SERVERS>
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="kafka" password="<KAFKA_SASL_PASSWORD>";
```

**This template:**

- Runs Kafka 4.4 in KRaft mode: no ZooKeeper, one service, one volume
- Keeps data on a volume, so topics and messages survive redeploys
- Has two listeners: plaintext on the private network for your Railway services, and SASL/SCRAM on a TCP proxy for outside clients, each advertised with the right address
- Generates the SASL password and re-applies it on every start, so changing the variable is enough to rotate it
- Protects Kafka UI with a login form and a generated password
- Sizes the JVM heap for the Hobby plan (512 MB broker, 384 MB UI), adjustable with variables
- Pins every image version

**Notes:** the TCP proxy is SASL-authenticated but not TLS-encrypted, so prefer the private network for sensitive data, or remove the TCP proxy if you don't need outside access. The two services idle at about 1 GB of RAM together. This is a single broker: topics have one replica, so it suits apps, staging and moderate production loads, not multi-zone durability.

## Why Deploy Apache Kafka 4.4 on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Apache Kafka 4.4 on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
