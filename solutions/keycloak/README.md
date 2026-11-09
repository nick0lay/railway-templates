# Keycloak 26

Self-hosted [Keycloak](https://www.keycloak.org/) on Railway: open-source identity and access management with single sign-on over OpenID Connect, OAuth 2.0 and SAML 2.0, social login, LDAP / Active Directory federation and two-factor authentication. A self-hosted alternative to Auth0, Okta and AWS Cognito. This template runs the official Keycloak image in production mode with PostgreSQL. The first admin is created at deploy with a generated password, Postgres is reachable only over the private network, and the version is pinned and tested.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/keycloak-2682?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
        Admins (console)          Your apps and their users (OIDC / SAML)
              │ HTTPS                           │ HTTPS
              ▼                                 ▼
┌──────────────────────────────────────────────────────────────┐
│ Railway project                                              │
│                                                              │
│  Keycloak :8080 (public, admin login required)               │
│    kc.sh start, health on /health/ready                      │
│        │ JDBC                                                │
│        ▼                                                     │
│  Postgres :5432 (private)                                    │
│    realms, users, clients, sessions                          │
│    volume /var/lib/postgresql/data                           │
└──────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Keycloak | `quay.io/keycloak/keycloak:26.8.2` | Login pages, admin console, OIDC / SAML endpoints (public, admin login required) |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:17` | All Keycloak data: realms, users, clients, sessions (private, volume) |

## What this template does

- **Official image, production mode.** `quay.io/keycloak/keycloak` pinned to 26.8.2, started with `kc.sh start` (not `start-dev`), so the H2 dev database and dev defaults are never used.
- **Admin created at deploy.** `KC_BOOTSTRAP_ADMIN_USERNAME` and a generated `KC_BOOTSTRAP_ADMIN_PASSWORD` create the first admin on the first start.
- **Correct URLs behind Railway's proxy.** Railway terminates TLS at its edge. Keycloak serves HTTP on 8080 (`KC_HTTP_ENABLED=true`), trusts the `X-Forwarded-*` headers (`KC_PROXY_HEADERS=xforwarded`) and uses `KC_HOSTNAME` (your public domain) for tokens, redirects and the console, so issuer URLs are `https://...`.
- **Healthcheck on the readiness endpoint.** Health endpoints normally live on management port 9000, which Railway's healthcheck can't reach. `KC_HTTP_MANAGEMENT_HEALTH_ENABLED=false` serves `/health/ready` on port 8080, and Railway waits for it before routing traffic.
- **Sized for a small service.** JVM heap capped with `JAVA_OPTS_KC_HEAP` (`-Xmx768m`), and single-node caches (`KC_CACHE=local`) so Keycloak doesn't try to discover cluster members.
- **Private database.** Postgres has no public domain or TCP proxy.

## After deploy

1. Open the Keycloak URL and click **Administration Console**.
2. Log in with `KC_BOOTSTRAP_ADMIN_USERNAME` (default `admin`) and `KC_BOOTSTRAP_ADMIN_PASSWORD` (Keycloak service → Variables).
3. Keycloak shows a banner that this admin is temporary. In the `master` realm, go to **Users → Add user**, set a password under **Credentials**, assign the `admin` role under **Role mapping**, log in as the new user and delete the temporary admin. Turn on two-factor authentication for it (**Authentication → Required actions → Configure OTP**).
4. Create a realm for your apps (keep `master` for administrators only), then add one client per app under **Clients**.

## Connecting an app

Most libraries need only the realm's discovery URL, a client ID and, for confidential clients, a client secret:

```
Issuer / discovery:  https://<your-domain>/realms/<realm>/.well-known/openid-configuration
Authorization:       https://<your-domain>/realms/<realm>/protocol/openid-connect/auth
Token:               https://<your-domain>/realms/<realm>/protocol/openid-connect/token
SAML metadata:       https://<your-domain>/realms/<realm>/protocol/saml/descriptor
```

Get an admin token from the command line (for the Admin REST API or scripts):

```bash
curl -s -X POST "https://<your-domain>/realms/master/protocol/openid-connect/token" \
  -d grant_type=password -d client_id=admin-cli \
  -d username=admin -d password='<KC_BOOTSTRAP_ADMIN_PASSWORD>'
```

Apps in the same Railway project can also reach Keycloak privately at `http://keycloak.railway.internal:8080`, but tokens are issued for `KC_HOSTNAME`, so use the public URL wherever the issuer is checked.

## Custom domain

Add the domain to the Keycloak service, set `KC_HOSTNAME` to `https://<custom-domain>` and redeploy. Update redirect URIs of your clients if they used the Railway domain.

## Email

Keycloak sends verification and password reset emails per realm. Set SMTP under **Realm settings → Email** in the admin console; no variables are needed.

## Variables

### User-configurable

| Service | Variable | Default | Notes |
|---|---|---|---|
| Keycloak | `KC_BOOTSTRAP_ADMIN_USERNAME` | `admin` | First admin, created on the first start only |
| Keycloak | `KC_BOOTSTRAP_ADMIN_PASSWORD` | generated | Read it after deploy. Changing it later has no effect on the existing admin |
| Keycloak | `KC_HOSTNAME` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL. Change it when you add a custom domain |
| Keycloak | `JAVA_OPTS_KC_HEAP` | `-Xms128m -Xmx768m` | JVM heap. Raise `-Xmx` for many users, realms or sessions |
| Keycloak | `KC_CACHE` | `local` | Single-node caches. Keep it with one replica |

Any other [Keycloak option](https://www.keycloak.org/server/all-config) can be added as a `KC_*` variable, for example `KC_LOG_LEVEL=info,org.keycloak.events:debug` or `KC_FEATURES=token-exchange`.

### Auto-configured (do not change)

| Service | Variable | Value | Why |
|---|---|---|---|
| Keycloak | `KC_DB`, `KC_DB_URL`, `KC_DB_USERNAME`, `KC_DB_PASSWORD` | `postgres`, from the Postgres service | JDBC connection over the private network |
| Keycloak | `KC_HTTP_ENABLED`, `KC_HTTP_PORT`, `PORT` | `true`, `8080`, `8080` | Railway's edge terminates TLS and routes to 8080 |
| Keycloak | `KC_PROXY_HEADERS` | `xforwarded` | Lets Keycloak see the original HTTPS scheme and client IP |
| Keycloak | `KC_HEALTH_ENABLED`, `KC_HTTP_MANAGEMENT_HEALTH_ENABLED` | `true`, `false` | `/health/ready` on port 8080 for Railway's healthcheck |
| Postgres | `POSTGRES_PASSWORD` | generated | Database password |
| Postgres | `POSTGRES_DB`, `POSTGRES_USER` | `keycloak`, `postgres` | Database and user Keycloak connects with |

## Backups

All state is in Postgres. Turn on volume backups for the Postgres service in Railway, or dump the database:

```bash
pg_dump "$DATABASE_URL" > keycloak.sql
```

Realms can also be exported from the admin console (**Realm settings → Action → Partial export**), but that export leaves out user passwords.

## Cost

In our test Keycloak used about 0.75 GB of RAM at idle and Postgres about 0.16 GB, which fits the Hobby plan. Usage grows with active sessions; raise `-Xmx` in `JAVA_OPTS_KC_HEAP` when the heap fills.

## Upgrading

Change the image tag (for example `quay.io/keycloak/keycloak:26.9.0`) and redeploy. Keycloak migrates its database on start. Read the [upgrade notes](https://www.keycloak.org/docs/latest/upgrading/) first and back up Postgres before a minor or major upgrade; a migrated database can't be used by an older version.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Healthcheck fails during the first deploy | The first start builds Keycloak's configuration and creates the schema, which takes 1 to 2 minutes. The healthcheck waits up to 10 minutes; check the logs for a database error |
| `Invalid parameter: redirect_uri` | Add your app's callback URL to the client's **Valid redirect URIs** |
| Issuer in tokens is the Railway domain after adding a custom domain | Set `KC_HOSTNAME` to the custom domain and redeploy |
| Admin login fails with the generated password | The admin is created on the first start only. If you changed the variable later, use the old value. To recover a lost admin, see Keycloak's [bootstrap admin recovery](https://www.keycloak.org/server/bootstrap-admin-recovery) (`kc.sh bootstrap-admin user`) |
| Service restarts with `OutOfMemoryError` | Raise `-Xmx` in `JAVA_OPTS_KC_HEAP` and the service's memory limit |
| "Temporary admin" banner | Expected until you create a permanent admin (see **After deploy**) |

## License

Keycloak is [Apache-2.0](https://github.com/keycloak/keycloak/blob/main/LICENSE.txt). PostgreSQL uses the PostgreSQL License.

## Testing

Tested on 2026-11-09 with Keycloak 26.8.2 in throwaway Railway projects deployed from the template. Both services were healthy about a minute after deploy. Over the public domain the OpenID Connect discovery document returned the issuer `https://<railway-domain>/realms/master` (HTTPS, public hostname), `/` and `/admin/` redirected to the admin console on HTTPS, and the console's login form loaded. The generated admin logged in through the login form (redirected back to the console with an authorization code) and through the token endpoint with `admin-cli`; a wrong password was refused, and the Admin REST API refused requests without a token. A realm created through the Admin REST API was still there after redeploying both services, and the admin could still log in. Postgres had no public domain or TCP proxy. At idle Keycloak used about 0.75 GB of RAM and Postgres about 0.16 GB. Not tested: email, social login, LDAP federation, SAML clients and custom domains.
