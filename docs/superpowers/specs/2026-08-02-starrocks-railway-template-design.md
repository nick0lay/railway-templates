I # StarRocks Railway Template — Design

Date: 2026-08-02
Status: Approved

## Goal

Add a Railway template for [StarRocks](https://www.starrocks.io/) — an MPP analytical database positioned as a ClickHouse alternative — to `solutions/starrocks/`. No StarRocks template exists on Railway today.

The template follows the version-override pattern already used by `clickhouse-chui` and `questdb`: the Dockerfile builds `FROM` the official image at `latest`, and a Railway build variable pins a specific version when desired.

## Scope

In scope:

- One Railway service running StarRocks (FE + BE) from `starrocks/allin1-ubuntu`.
- Persistent Railway volume for FE metadata and BE storage.
- Public HTTP access to the FE web UI, REST API, and Stream Load ingestion.
- MySQL-protocol access documented via Railway TCP Proxy.
- Auto-generated root password applied on first boot.
- `README.md` (technical) and `TEMPLATE.md` (marketplace copy), plus root `README.md` updates.

Out of scope:

- A companion web SQL UI service. ClickHouse needed CH-UI because its HTTP port is an API, not a UI; StarRocks ships an FE web UI and speaks the MySQL wire protocol, so existing clients (DBeaver, `mysql`, BI tools) connect directly.
- Shared-data (`RUN_MODE=shared_data`) mode, which requires an S3-compatible storage volume and its own configuration story.
- Multi-node / high-availability topologies.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          Internet                                │
└──────────────┬────────────────────────────────┬─────────────────┘
               │ HTTPS (public domain)          │ TCP Proxy (manual)
               ▼                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      StarRocks (single service)                  │
│                                                                  │
│   feproxy (nginx) :$PORT ──► FE http :8030                       │
│     · FE web UI · REST API · Stream Load (fixes 307 redirects)   │
│                                                                  │
│   FE query port :9030 (MySQL protocol) ◄── TCP Proxy             │
│                                                                  │
│   supervisord ─┬─ feservice (FE)                                 │
│                ├─ beservice (BE)                                 │
│                ├─ feproxy   (nginx)                              │
│                └─ director  (registers BE with FE on boot)       │
│   All inter-component traffic on 127.0.0.1                       │
│                                                                  │
│   ┌────────────────────────────────────────────┐                 │
│   │ Volume /var/lib/starrocks                  │                 │
│   │   fe-meta/     ◄── symlink $SR_HOME/fe/meta│                 │
│   │   be-storage/  ◄── symlink $SR_HOME/be/... │                 │
│   └────────────────────────────────────────────┘                 │
└─────────────────────────────────────────────────────────────────┘
```

### Why the all-in-one image

Railway's private network is IPv6-only. A split FE/BE deployment requires the FE to register the BE with `ALTER SYSTEM ADD BACKEND '<host>:<port>'` and requires both nodes to agree on a routable address via `priority_networks`, which is expressed as IPv4 CIDR. `starrocks/allin1-ubuntu` runs both roles in one container pinned to `127.0.0.1`, avoiding the problem entirely. It also matches how this repository already ships single-container databases (`questdb`, `clickhouse-chui`).

Trade-off, to be stated in the README: this is a single-node deployment. Vertical scaling only; no HA.

## Files

| Path | Purpose |
|------|---------|
| `solutions/starrocks/starrocks/Dockerfile` | `FROM starrocks/allin1-ubuntu:${STARROCKS_IMAGE_TAG:-latest}`; overrides `CMD` only |
| `solutions/starrocks/starrocks/railway-entrypoint.sh` | Wrapper: volume symlinks, feproxy port, BE memory limit, root password init |
| `solutions/starrocks/README.md` | Technical documentation |
| `solutions/starrocks/TEMPLATE.md` | Railway marketplace description |
| `README.md` (repo root) | Add row to Solutions table and entry to Structure tree |

### Dockerfile

```dockerfile
ARG STARROCKS_IMAGE_TAG
FROM starrocks/allin1-ubuntu:${STARROCKS_IMAGE_TAG:-latest}

COPY railway-entrypoint.sh /railway-entrypoint.sh
RUN chmod +x /railway-entrypoint.sh

EXPOSE 8080 9030

CMD ["/railway-entrypoint.sh"]
```

`ENTRYPOINT` is deliberately not overridden: the upstream image sets it to `tini-static`, which stays PID 1 and reaps the background password job. `WORKDIR` is `/data/deploy`, so the wrapper ends with `exec ./entrypoint.sh`.

### Wrapper entrypoint

Runs before upstream's `entrypoint.sh`, in this order.

1. **Volume symlinks.** `mkdir -p /var/lib/starrocks/{fe-meta,be-storage}`, then `rm -rf` the real `$SR_HOME/fe/meta` and `$SR_HOME/be/storage` directories (created by the image build) and replace each with `ln -sfT` into the volume. `ln -sfT` onto an existing directory fails, so the removal is required.

   Symlinks rather than repointing `meta_dir` / `storage_root_path` in the config files: upstream's `entrypoint.sh` reads `$SR_HOME/fe/meta/image/VERSION` to detect run-mode changes, and `director/run.sh` reads `$SR_HOME/fe/meta/image/ROLE` for the hostname-mismatch check. Both use literal paths and would silently misbehave if the config were repointed.

2. **feproxy port.** Idempotent in-place `sed` on `$SR_HOME/feproxy/feproxy.conf.template`, rewriting the `listen <n>;` directive to `listen ${PORT:-8080};`. Upstream regenerates `feproxy.conf` from this template on every boot, so patching the template survives. The substitution matches any digit sequence so re-running against an already-patched file is safe.

3. **BE memory limit.** Grep-guarded append of `mem_limit = ${STARROCKS_BE_MEM_LIMIT:-80%}` to `$SR_HOME/be/conf/be.conf`. Without it, the BE can size itself from memory it cannot actually use and enter an opaque OOM restart loop.

4. **Root password.** The value itself is generated by Railway, not by the container: the template defines `STARROCKS_PASSWORD = ${{secret(32)}}`, so it is created at install time and visible in the service's Variables tab. The entrypoint only *applies* that value to the `root` account, because the StarRocks image — unlike ClickHouse's, which reads `CLICKHOUSE_PASSWORD` natively — has no password variable and always boots `root` passwordless.

   Marker file `/var/lib/starrocks/.root_password_set` on the volume.
   - Marker present: `export MYSQL_PWD="$STARROCKS_PASSWORD"` so upstream's `director` can authenticate on subsequent boots.
   - Marker absent and `STARROCKS_PASSWORD` non-empty: fork a background job that waits for `$SR_HOME/bootstrap_done`, then runs `SET PASSWORD FOR 'root'@'%' = PASSWORD('…')` over `127.0.0.1:9030` and writes the marker.
   - `STARROCKS_PASSWORD` empty: skip entirely, leave upstream's passwordless default.

   Waiting for `bootstrap_done` is load-bearing. On first boot `director` registers the BE over a passwordless connection; a password applied mid-sequence makes its next statement fail with error 1045, which `director` treats as fatal and shuts the container down. `bootstrap_done` is touched after `director`'s last SQL statement.

   `MYSQL_PWD` must not be exported on first boot for the mirror-image reason: sending a password to an account that has none is also a 1045.

   Single quotes and backslashes in the password are escaped before interpolation into the SQL statement.

5. `exec ./entrypoint.sh`

## Environment variables

### User-configurable

| Variable | Default | Description |
|----------|---------|-------------|
| `STARROCKS_PASSWORD` | `${{secret(32)}}` | Root password. Generated by Railway at install time and readable in the Variables tab; the entrypoint applies it to the `root` account on first boot |
| `STARROCKS_IMAGE_TAG` | `latest` | Image tag (build arg) |
| `STARROCKS_BE_MEM_LIMIT` | `80%` | BE memory ceiling, percentage or absolute (e.g. `4G`) |

### Railway-provided

| Variable | Description |
|----------|-------------|
| `PORT` | Public HTTP port; the wrapper binds feproxy to it |

`MYSQL_PWD` is exported inside the container by the wrapper and is not a Railway variable.

### Image tags

`latest` tracks the newest release line. `3.5-latest` is the LTS line. Pinned versions (`4.1.3`, `3.5.20`, …) and per-line aliases (`4.0-latest`, `3.4-latest`) are also published.

## Volume

| Mount path | Contents |
|------------|----------|
| `/var/lib/starrocks` | `fe-meta/` (FE metadata), `be-storage/` (table data), `.root_password_set` marker |

Restart safety: upstream's hostname-mismatch check short-circuits when the FE was registered as `127.0.0.1`, which the image's `priority_networks = 127.0.0.1/32` guarantees. Railway's changing container hostnames therefore do not invalidate persisted metadata.

## Access paths

| Path | How | Notes |
|------|-----|-------|
| FE web UI, REST API, Stream Load | Public domain over HTTPS | Enabled from Settings → Networking |
| SQL (MySQL protocol, port 9030) | Railway TCP Proxy | Manual post-deploy step; a template cannot pre-configure it |

## Error handling and troubleshooting (documented in README)

- Restart loop shortly after boot → BE memory; lower `STARROCKS_BE_MEM_LIMIT` or increase the service's memory.
- `ERROR 1045 (28000): Access denied` in logs after changing `STARROCKS_PASSWORD` → the marker file means the entrypoint will not re-apply it; change the password with `SET PASSWORD` over SQL first, then update the variable to match.
- Cannot connect on port 9030 → TCP Proxy not enabled.
- Data lost after redeploy → volume not mounted at `/var/lib/starrocks`.
- "FE service hostname mismatch detected" → explain the `127.0.0.1` short-circuit and when it can legitimately appear.
- Slow first boot → the image is ~1.9 GB and cluster bootstrap takes a minute or two; the service is not healthy until `director` finishes.

## Testing

Local Docker validation before the template is published (the host has Docker with an arm64 image available):

1. Build with the default tag; confirm it resolves to `latest`.
2. Run with a non-default `PORT`, a mounted volume, and `STARROCKS_PASSWORD` set. Confirm:
   - HTTP on `$PORT` serves the FE UI and `/api/health`.
   - `mysql -h 127.0.0.1 -P 9030 -u root -p<password>` connects; a passwordless connection is refused.
   - `SHOW BACKENDS` reports one alive BE.
   - A Stream Load `PUT` through `$PORT` ingests a row.
3. Create a table, insert rows, restart the container against the same volume, and confirm the data and the password both survive and the second boot does not deadlock or 1045.
4. Build with `STARROCKS_IMAGE_TAG=3.5-latest` and confirm the pin takes effect.

## Open items

None.
