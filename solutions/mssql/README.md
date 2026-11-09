# Microsoft SQL Server 2022 on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/microsoft-sql-server-2022-cu27?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

Microsoft SQL Server 2022 on Linux from Microsoft's official image. Free Express edition by default, data on a Railway volume, a TCP proxy so you can connect from SSMS, and daily `.bak` backups to a Railway Bucket.

Tested on 2026-11-09: clean deploy from the published template, connection through the TCP proxy, data kept after a redeploy, scheduled backups of all databases to the bucket, backup files overwritten on the next run, and a restore from the bucket into a new database.

## Architecture

```
  SSMS / Azure Data Studio / sqlcmd (your machine)
                 |
                 |  TCP proxy  <host>.proxy.rlwy.net:<port>
                 v
  +----------------------------------+        +----------------------------+
  | MSSQL (SQL Server 2022, :1433)   | <----- | Your apps on Railway       |
  | volume /var/opt/mssql            |        | mssql.railway.internal:1433|
  +----------------------------------+        +----------------------------+
                 ^         |
     sqlcmd over |         | BACKUP DATABASE ... TO URL (S3)
     private net |         v
  +------------------+   +---------------------------------------------+
  | Backup (cron,    |   | Bucket (Railway Bucket, S3-compatible)      |
  | daily 03:00 UTC) |   | mssql-backups/<db>/<db>_<Mon..Sun>.bak      |
  +------------------+   +---------------------------------------------+
```

| Service | Source | Role |
|---------|--------|------|
| MSSQL | `mcr.microsoft.com/mssql/server:2022-CU27-GDR1-ubuntu-22.04` | SQL Server. Private network on 1433, public through the TCP proxy (login required: `sa` + generated password) |
| Backup | same image (only `sqlcmd` is used) | Cron job, daily at 03:00 UTC. Tells SQL Server to back up every database to the bucket, then exits |
| Bucket | Railway Bucket | Holds the `.bak` files |

## Setup

1. Click **Deploy on Railway**. You don't need to fill in anything.
2. Wait until MSSQL is running (about a minute; the image is large on the first pull).
3. Open the MSSQL service, **Variables** tab, and copy `MSSQL_PUBLIC_HOST`, `MSSQL_PUBLIC_PORT` and `MSSQL_SA_PASSWORD`.
4. Connect with your client (see below) and create your databases and logins.

SQL Server needs at least 2 GB of RAM. It runs on the Hobby and Pro plans, not on the free trial. Expect about 1 to 2 GB of memory use at idle, more under load.

## Connecting

### SSMS, Azure Data Studio, DBeaver

| Field | Value |
|-------|-------|
| Server | `<MSSQL_PUBLIC_HOST>,<MSSQL_PUBLIC_PORT>` (comma between host and port, not a colon) |
| Authentication | SQL Server Authentication |
| Login | `sa` |
| Password | `MSSQL_SA_PASSWORD` |
| Encryption | Mandatory, tick **Trust server certificate** |

SQL Server uses a self-signed certificate, so newer clients (SSMS 20+, sqlcmd 18) refuse to connect until you trust it.

### sqlcmd

```bash
sqlcmd -S "<MSSQL_PUBLIC_HOST>,<MSSQL_PUBLIC_PORT>" -U sa -P '<password>' -C -Q "SELECT @@VERSION"
```

`-C` trusts the server certificate.

### From another service in the same project

Use reference variables:

```
ConnectionStrings__Default=${{MSSQL.MSSQL_CONNECTION_STRING}}
```

or build your own from `${{MSSQL.MSSQL_PRIVATE_HOST}}` (port 1433), `${{MSSQL.MSSQL_USER}}` and `${{MSSQL.MSSQL_SA_PASSWORD}}`. For an app, create a login and database of its own instead of using `sa`:

```sql
CREATE DATABASE appdb;
CREATE LOGIN app WITH PASSWORD = '<strong password>';
USE appdb; CREATE USER app FOR LOGIN app; ALTER ROLE db_owner ADD MEMBER app;
```

If you don't need access from outside Railway, remove the TCP proxy in the MSSQL service's **Settings > Networking**.

## Variables

### User-configurable (MSSQL)

| Variable | Default | Description |
|----------|---------|-------------|
| `MSSQL_PID` | `Express` | Edition. `Express` is free for production (10 GB per database, about 1.4 GB buffer pool, 4 cores). `Developer` has all features but is licensed only for development and testing, not production. `Standard` / `Enterprise` need your own licence, or put a product key here |
| `MSSQL_SA_PASSWORD` | generated | `sa` password, 35 characters with upper case, lower case and digits. It is only applied when the server is first created. To change it later, run `ALTER LOGIN sa WITH PASSWORD = '...'` and then update this variable so the Backup service can still log in |
| `MSSQL_MEMORY_LIMIT_MB` | `2048` | Maximum memory SQL Server uses. Raise it on bigger plans, and keep it below the service memory limit |
| `ACCEPT_EULA` | `Y` | Acceptance of the [SQL Server licence terms](https://go.microsoft.com/fwlink/?linkid=857698), required by the image |

### User-configurable (Backup)

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKUP_DATABASES` | empty | Comma-separated list of databases to back up. Empty = every online database except `tempdb`, including `master`, `model` and `msdb` |
| `BACKUP_PREFIX` | `mssql-backups` | Folder in the bucket |

The schedule is the Backup service's **Settings > Cron Schedule** (`0 3 * * *`, daily at 03:00 UTC).

### Auto-configured (do not change)

| Variable | Service | Purpose |
|----------|---------|---------|
| `RAILWAY_RUN_UID=0` | MSSQL | Runs the container as root. The Railway volume is owned by root, and the image's default `mssql` user can't write to it |
| `MSSQL_USER`, `MSSQL_PRIVATE_HOST`, `MSSQL_PUBLIC_HOST`, `MSSQL_PUBLIC_PORT`, `MSSQL_CONNECTION_STRING`, `MSSQL_PUBLIC_CONNECTION_STRING` | MSSQL | Connection details for your apps and clients, built from Railway's private domain and TCP proxy |
| `MSSQL_HOST`, `MSSQL_SA_PASSWORD` | Backup | `${{MSSQL.RAILWAY_PRIVATE_DOMAIN}}` and `${{MSSQL.MSSQL_SA_PASSWORD}}` |
| `S3_ENDPOINT`, `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` | Backup | References to the Bucket's credentials |
| `BACKUP_RUN_SH` | Backup | The backup script |

The MSSQL start command is `/opt/mssql/bin/launch_sqlservr.sh /opt/mssql/bin/sqlservr -T1800`. Trace flag 1800 makes SQL Server align its log writes to 4 KB. Without it, SQL Server crashes on the first start on Railway volumes ("misaligned log IOs", then "Stack Overflow").

## Backups

The Backup service uses SQL Server 2022's own [backup to S3-compatible storage](https://learn.microsoft.com/sql/relational-databases/backup-restore/sql-server-backup-to-url-s3-compatible-object-storage). Each run:

1. creates (or refreshes) a SQL Server credential for the bucket,
2. runs `BACKUP DATABASE ... TO URL = 's3://<endpoint>/<bucket>/mssql-backups/<db>/<db>_<weekday>.bak' WITH FORMAT, INIT, CHECKSUM` for each database (with `COMPRESSION` on editions that support it; Express doesn't),
3. exits with an error if any database failed, so a failed run shows up in the Railway dashboard.

There is one file per database per weekday (`mydb_Mon.bak` ... `mydb_Sun.bak`), and each is overwritten a week later, so the bucket holds the last 7 daily backups. To keep a backup longer, download it or copy it to another name. To take a backup right away, set the Backup service's cron schedule a few minutes ahead, wait for the run, then set it back. Redeploying the Backup service does not run it.

Express has no SQL Server Agent, which is why the schedule lives in a Railway cron service.

### Restore

The credential created by the backup run stays in SQL Server, so you can restore straight from the bucket. Take the URL from the Backup service's logs (`backup ok: s3://...`):

```sql
-- overwrite the existing database
RESTORE DATABASE mydb FROM URL = 's3://<endpoint host>/<bucket>/mssql-backups/mydb/mydb_Mon.bak' WITH REPLACE;

-- or restore as a copy next to it
RESTORE FILELISTONLY FROM URL = 's3://.../mydb_Mon.bak';   -- shows the logical file names
RESTORE DATABASE mydb_copy FROM URL = 's3://.../mydb_Mon.bak'
  WITH MOVE 'mydb' TO '/var/opt/mssql/data/mydb_copy.mdf',
       MOVE 'mydb_log' TO '/var/opt/mssql/data/mydb_copy_log.ldf';
```

### Manual backup to a file

To get a `.bak` file onto your machine, download it from the bucket (Railway dashboard, or any S3 client with the Bucket's credentials). You can also back up to the volume and copy the file out:

```sql
BACKUP DATABASE mydb TO DISK = '/var/opt/mssql/data/mydb.bak' WITH FORMAT, INIT;
```

### Restore a `.bak` from another server

Upload the file to the bucket with any S3 client, then run `RESTORE DATABASE ... FROM URL` as above (with `MOVE` to `/var/opt/mssql/data/`). If no backup has run yet, run the Backup service once first, so SQL Server has the bucket credential.

## Cost and plan

- Memory: SQL Server needs at least 2 GB. With the default `MSSQL_MEMORY_LIMIT_MB=2048` the service uses about 1 to 2 GB.
- Volume: Railway's default volume size depends on your plan. Express databases are limited to 10 GB each anyway.
- Bucket: one `.bak` per database per weekday.
- The Backup service only runs for about a minute a day.

## Upgrading

The image is pinned to `2022-CU27-GDR1-ubuntu-22.04`. To move to a newer cumulative update, change the MSSQL service's image to a newer `2022-CU<n>-ubuntu-22.04` tag (or `2022-latest`) and redeploy. Take a backup first. SQL Server upgrades databases on start and cannot be downgraded afterwards. Moving to SQL Server 2025 (`2025-CU<n>-ubuntu-24.04`) works the same way, but test it on a copy of your data first.

## Troubleshooting

| Problem | Cause and fix |
|---------|---------------|
| SSMS: "The certificate chain was issued by an authority that is not trusted" | Tick **Trust server certificate** (sqlcmd: `-C`) |
| Can't connect with `host:port` | SQL Server clients use a comma: `host,port` |
| Login failed for `sa` after changing `MSSQL_SA_PASSWORD` | The variable only sets the password when the server is first created. Use the old password, run `ALTER LOGIN sa WITH PASSWORD = '...'`, then set the variable to the new value |
| Service restarts, logs show "out of memory" or the server stops right after start | The plan or service memory limit is below 2 GB, or `MSSQL_MEMORY_LIMIT_MB` is above the service limit |
| Logs show "misaligned log IOs" and "Stack Overflow" | The start command lost `-T1800`. Restore it: `/opt/mssql/bin/launch_sqlservr.sh /opt/mssql/bin/sqlservr -T1800` |
| "Rate limit of 500 logs/sec reached" during start | Harmless. SQL Server prints its whole error log at start |
| Backup run fails with "Login failed" | `MSSQL_SA_PASSWORD` on MSSQL no longer matches the real `sa` password (see above) |
| Writes fail with "would exceed your licensed limit of 10240 MB" | Express's 10 GB per-database limit. Use a licensed edition (see `MSSQL_PID`) or split the data |
| A database is missing from the backups | Only databases in `ONLINE` state are backed up. Check `BACKUP_DATABASES` |
