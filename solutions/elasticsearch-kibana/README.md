# Elasticsearch + Kibana

Self-hosted [Elasticsearch](https://github.com/elastic/elasticsearch) 9 and [Kibana](https://github.com/elastic/kibana) on Railway, with security on. Elasticsearch is private and requires a password. Kibana is the only public service, and it asks for a login. The password Kibana uses to reach Elasticsearch is set up automatically when Elasticsearch starts, so there are no manual steps after deploy.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/elasticsearch-kibana?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
                 You (browser)
                      │ HTTPS
                      ▼
┌──────────────────────────────────────────────────────────────┐
│ Railway project                                              │
│                                                              │
│  Kibana :5601 (public, login required)                       │
│    logs in to Elasticsearch as kibana_system                 │
│        │ HTTP, private network                               │
│        ▼                                                     │
│  Elasticsearch :9200 (private, volume)                       │
│    security on, single node, user elastic                    │
│    other services use its ELASTICSEARCH_URL                  │
└──────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Elasticsearch | `elastic/elasticsearch:9.5.6` | Search and analytics engine. Private, no public domain, volume at `/usr/share/elasticsearch/data` |
| Kibana | `elastic/kibana:9.5.6` | Web UI: Discover, dashboards, Dev Tools console, index management (public, login required) |

## What this template does differently

- **Security on, nothing open.** Many Elasticsearch templates turn security off and give Elasticsearch a public domain, so anyone with the URL can read and delete your data. Here every request to Elasticsearch needs a password, Elasticsearch has no public domain or TCP proxy, and Kibana shows its login page.
- **No manual Kibana setup.** Kibana can't log in to Elasticsearch as the `elastic` superuser; it needs the built-in `kibana_system` user with its own password. Normally you set that password by hand. Here Elasticsearch sets it on every start from the generated `KIBANA_SYSTEM_PASSWORD`, and Kibana connects as soon as it's done.
- **Works without kernel tuning.** Railway can't raise `vm.max_map_count`, which Elasticsearch normally requires. The template uses `node.store.allow_mmap=false` and `discovery.type=single-node`, so Elasticsearch starts without it.
- **Heap from one variable.** `ES_HEAP_SIZE` (default `1g`) sets the Java heap.
- **Volume permissions handled.** Railway volumes are owned by root and Elasticsearch runs as user 1000. The start command fixes ownership as root, then starts Elasticsearch as user 1000.
- **Pinned versions**, telemetry off, generated Kibana encryption keys, healthcheck on Kibana's `/api/status`.

## After deploy

1. Open the Kibana URL. It takes about two minutes to start the first time.
2. Log in as `elastic` with the `ELASTIC_PASSWORD` variable of the Elasticsearch service. The Kibana service shows the same values as `LOGIN_USERNAME` and `LOGIN_PASSWORD`.
3. Open **Dev Tools → Console** to send requests to Elasticsearch, or add data under **Integrations** or **Upload a file**.
4. For apps and other users, create users and roles under **Stack Management → Security**, or API keys under **Stack Management → API keys**. Use the `elastic` superuser only for administration.

## Connecting from other services

Services in the same Railway project reach Elasticsearch over the private network:

```
ELASTICSEARCH_URL=${{Elasticsearch.ELASTICSEARCH_URL}}        # http://elasticsearch.railway.internal:9200
ELASTICSEARCH_USERNAME=${{Elasticsearch.ELASTIC_USERNAME}}
ELASTICSEARCH_PASSWORD=${{Elasticsearch.ELASTIC_PASSWORD}}
```

Better: create an API key in Kibana and pass it as `Authorization: ApiKey <key>`.

### Exposing Elasticsearch publicly (optional)

To reach Elasticsearch from outside Railway, open the Elasticsearch service → **Settings → Networking → Generate Domain** and set the target port to `9200`. Traffic goes through Railway's HTTPS edge, and every request still needs a password or an API key:

```bash
curl -u elastic:$ELASTIC_PASSWORD https://<your-elasticsearch-domain>/
```

Use an API key with limited privileges for each client rather than the `elastic` password. Don't use a TCP proxy for port 9200: it's plain HTTP, so the password would be sent unencrypted.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Elasticsearch | `ES_HEAP_SIZE` | `1g` | Java heap, e.g. `512m`, `2g`, `4g`. Keep it at about half of the RAM you want Elasticsearch to use; the rest goes to off-heap memory and the file cache |
| Elasticsearch | `ELASTIC_PASSWORD` | generated | Password of the `elastic` superuser. Read it after deploy. Changing the variable later only works as long as you never changed the password inside Elasticsearch (Kibana or the API) |

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Elasticsearch | `KIBANA_SYSTEM_PASSWORD` | generated | Password of the built-in `kibana_system` user. Set in Elasticsearch on every start |
| Elasticsearch | `ES_SETUP_SH` | script | Run in the background by the start command. Waits for Elasticsearch, then sets the `kibana_system` password. Logs `kibana-setup: kibana_system password: HTTP 200` |
| Elasticsearch | `ES_JAVA_OPTS` | `-Xms${{ES_HEAP_SIZE}} -Xmx${{ES_HEAP_SIZE}}` | Heap from `ES_HEAP_SIZE` |
| Elasticsearch | `discovery.type` | `single-node` | One node; also skips the production bootstrap checks |
| Elasticsearch | `node.store.allow_mmap` | `false` | Railway can't raise `vm.max_map_count` |
| Elasticsearch | `network.host` | `::0` | Listen on IPv4 and IPv6 on the private network |
| Elasticsearch | `xpack.security.enabled` | `true` | Passwords required |
| Elasticsearch | `xpack.security.http.ssl.enabled`, `xpack.security.transport.ssl.enabled` | `false` | Plain HTTP inside Railway's private network (which is encrypted); single node, no transport traffic |
| Elasticsearch | `xpack.security.enrollment.enabled` | `false` | Kibana is configured by variables, not enrollment tokens |
| Elasticsearch | `ELASTIC_USERNAME`, `ELASTICSEARCH_URL` | `elastic`, private URL | For reference from other services |
| Elasticsearch | `RAILWAY_RUN_UID` | `0` | The start command needs root to fix volume ownership. Elasticsearch itself runs as user 1000 |
| Kibana | `ELASTICSEARCH_HOSTS` | `http://${{Elasticsearch.RAILWAY_PRIVATE_DOMAIN}}:9200` | Private network |
| Kibana | `ELASTICSEARCH_USERNAME`, `ELASTICSEARCH_PASSWORD` | `kibana_system`, `${{Elasticsearch.KIBANA_SYSTEM_PASSWORD}}` | How Kibana logs in to Elasticsearch |
| Kibana | `LOGIN_USERNAME`, `LOGIN_PASSWORD` | from Elasticsearch | Copies of your login, shown here for convenience. Not used by Kibana |
| Kibana | `XPACK_SECURITY_ENCRYPTIONKEY`, `XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY`, `XPACK_REPORTING_ENCRYPTIONKEY` | generated | Encrypt sessions, saved secrets (connectors, alerting rules) and reports. **Never change the saved-objects key after the first deploy** |
| Kibana | `SERVER_PUBLICBASEURL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL. Update it if you add a custom domain |
| Kibana | `TELEMETRY_OPTIN` | `false` | No usage data sent to Elastic |
| Kibana | `PORT` | `5601` | |

## Resources and cost

Measured idle on Railway with the default 1 GB heap: Elasticsearch about 1.8 GB RAM, Kibana about 1.1 GB, under 0.1 vCPU together. That is roughly $30 a month at Railway's usage prices. The stack needs a paid plan (Railway's Free and Trial plans allow 0.5–1 GB per service, which is not enough). Lower `ES_HEAP_SIZE` to `512m` for small test datasets; raise it for larger ones.

Hobby volumes are 5 GB. Elasticsearch stops allocating shards when the disk is 85–90% full and makes indices read-only at 95%. Delete old indices, set an index lifecycle policy, or grow the volume (Pro plan) before it fills up.

## Upgrading

Change the image tag on both services to the same version, for example `elastic/elasticsearch:9.5.7` and `elastic/kibana:9.5.7`. Kibana must not be newer than Elasticsearch, so upgrade Elasticsearch first. Read the [release notes](https://www.elastic.co/docs/release-notes/elasticsearch) first; you can upgrade within 9.x but not downgrade.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Kibana says "Kibana server is not ready yet" | It's still starting, or can't log in to Elasticsearch. Check the Elasticsearch logs for `kibana-setup:`; `HTTP 200` means the password was set. Kibana keeps retrying |
| Login with `elastic` fails | You changed the `elastic` password inside Elasticsearch; use that one. `ELASTIC_PASSWORD` only applies while the password was never changed through the API |
| Elasticsearch exits with an out-of-memory error | `ES_HEAP_SIZE` is too large for the RAM you allow the service, or too small for your data. Keep the heap at about half of the service's memory |
| Indexing fails with `index read-only / allow delete` | The volume is over 95% full. Free space or grow the volume, then clear the block: `PUT _all/_settings {"index.blocks.read_only_allow_delete": null}` |
| Another service can't connect | Use `http://` (not `https://`) and the private URL, with a username and password or an API key |
| Saved connectors or alerting rules stop working after a change | `XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY` was changed. Restore the old value |

## License

The Elasticsearch and Kibana source code is available under AGPLv3, SSPL or the Elastic License 2.0. Elastic's official images, used here, are distributed under the Elastic License 2.0, which allows self-hosting but not offering Elasticsearch as a managed service to third parties. The free Basic features are included; paid features need an Elastic subscription.

## Testing

Tested on 2026-11-05 with Elasticsearch and Kibana 9.5.6 in a throwaway Railway project: both services healthy, the `kibana_system` password was set automatically about 30 seconds after Elasticsearch started, and Elasticsearch had no public domain or TCP proxy. On the Kibana domain, the login page loaded, API calls without a login returned 401, a wrong password was refused, and `elastic` with the generated password logged in. A document was indexed and found through Kibana. After Elasticsearch was redeployed, the setup step ran again, Kibana reconnected, and the document was still there.
