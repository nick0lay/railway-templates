# Deploy and Host Microsoft SQL Server 2022 on Railway

Microsoft SQL Server (MSSQL) is Microsoft's relational database for .NET, ASP.NET, Entity Framework and enterprise applications. This template runs SQL Server 2022 on Linux from Microsoft's official image, free Express edition by default, with a persistent volume, a public TCP endpoint for SSMS and daily backups to a Railway Bucket.

## About Hosting Microsoft SQL Server 2022

The template deploys the official `mcr.microsoft.com/mssql/server` image pinned to SQL Server 2022 CU27 GDR1, with your data on a Railway volume at `/var/opt/mssql`. The `sa` password is generated at deploy and meets SQL Server's password policy. A TCP proxy publishes port 1433, so you can connect from SQL Server Management Studio (SSMS), Azure Data Studio, DBeaver or `sqlcmd` on your machine, and other services in the project connect over the private network.

A second service, **Backup**, runs every day at 03:00 UTC. It uses SQL Server 2022's built-in `BACKUP DATABASE ... TO URL` with S3 storage to write a `.bak` file of every database straight into the included Railway Bucket. It keeps one file per database per weekday, so you always have the last 7 days. Restore with one `RESTORE DATABASE ... FROM URL` command.

SQL Server needs at least 2 GB of RAM, so it runs on the Hobby or Pro plan, not the free trial.

## Common Use Cases

- Database for .NET / ASP.NET Core / Entity Framework apps deployed on Railway
- Hosted SQL Server for development, staging and CI, reachable from SSMS
- Moving an on-premises SQL Server database to the cloud with a `.bak` restore
- Backend for reporting tools and low-code apps that need MSSQL

## Dependencies for Microsoft SQL Server 2022 Hosting

- Official image `mcr.microsoft.com/mssql/server:2022-CU27-GDR1-ubuntu-22.04`
- Railway volume at `/var/opt/mssql` (included)
- Railway Bucket for backups (included)

### Deployment Dependencies

- SQL Server on Linux docs: https://learn.microsoft.com/sql/linux/sql-server-linux-overview
- Editions and limits: https://learn.microsoft.com/sql/sql-server/editions-and-components-of-sql-server-2022
- Backup to S3: https://learn.microsoft.com/sql/relational-databases/backup-restore/sql-server-backup-to-url-s3-compatible-object-storage
- Template source and full guide: https://github.com/nick0lay/railway-templates/tree/main/solutions/mssql

### Implementation Details

**Editions (`MSSQL_PID`).** `Express` (default) is free for production use, with limits of 10 GB per database, about 1.4 GB of buffer pool memory and 4 cores. `Developer` has every feature but is licensed for development and testing only, not production. `Standard` or `Enterprise` require your own licence (or put a product key in `MSSQL_PID`).

**Connect from SSMS or Azure Data Studio.** Use the values from the MSSQL service's Variables tab:

```
Server:   <MSSQL_PUBLIC_HOST>,<MSSQL_PUBLIC_PORT>     (comma, not colon)
Login:    sa
Password: <MSSQL_SA_PASSWORD>
Encrypt:  Mandatory, and tick "Trust server certificate"
```

**Connect from another Railway service** with a reference variable:

```
ConnectionStrings__Default=${{MSSQL.MSSQL_CONNECTION_STRING}}
```

**Restore a backup** (files are in the bucket under `mssql-backups/<db>/<db>_<Mon..Sun>.bak`):

```sql
RESTORE DATABASE mydb FROM URL = 's3://<endpoint host>/<bucket>/mssql-backups/mydb/mydb_Mon.bak' WITH REPLACE;
```

`MSSQL_MEMORY_LIMIT_MB` (default 2048) caps the memory SQL Server uses. Raise it on bigger plans. The server starts with trace flag 1800, which SQL Server needs on Railway volumes: without it, the first start crashes on misaligned disk writes.

## Why Deploy Microsoft SQL Server 2022 on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Microsoft SQL Server 2022 on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
