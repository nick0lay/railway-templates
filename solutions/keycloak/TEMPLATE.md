# Deploy and Host Keycloak 26.8.2 on Railway

Keycloak is the open-source identity and access management server from the CNCF. It gives your apps single sign-on (SSO) with OpenID Connect, OAuth 2.0 and SAML 2.0, user registration and login pages, social login (Google, GitHub, Microsoft), LDAP and Active Directory federation, two-factor authentication and fine-grained roles. It is a self-hosted alternative to Auth0, Okta and AWS Cognito.

## About Hosting Keycloak 26.8.2

This template runs the official `quay.io/keycloak/keycloak` image, pinned to 26.8.2, in production mode (`kc.sh start`) with PostgreSQL 17 on a volume. Keycloak sits behind Railway's HTTPS edge: it serves HTTP on port 8080, trusts Railway's `X-Forwarded-*` headers and builds every URL from your public domain, so tokens, redirects and the admin console work without extra setup. The first admin is created on the first start with a generated password, so nobody else can take over your instance. Postgres has no public endpoint. The JVM heap is capped for a small service, and Railway's healthcheck uses Keycloak's own readiness endpoint (`/health/ready`).

## Common Use Cases

- Single sign-on for your own apps and internal tools (Grafana, n8n, GitLab, Outline, Nextcloud, Kubernetes dashboards) with OpenID Connect or SAML
- Login, sign-up, password reset and two-factor authentication for a SaaS product without paying per user for Auth0 or Okta
- Social login (Google, GitHub, Microsoft, Apple) and LDAP / Active Directory federation behind one login page
- Securing APIs with OAuth 2.0 access tokens, client credentials and role-based access control
- Multi-tenant identity with one realm per customer or environment

## Dependencies for Keycloak 26.8.2 Hosting

- Keycloak 26.8.2 (`quay.io/keycloak/keycloak:26.8.2`), public, admin login required
- PostgreSQL 17 (`ghcr.io/railwayapp-templates/postgres-ssl:17`), private, with a volume

### Deployment Dependencies

- Keycloak documentation: https://www.keycloak.org/documentation
- Server configuration reference: https://www.keycloak.org/server/all-config
- Running behind a reverse proxy: https://www.keycloak.org/server/reverseproxy
- Source and releases: https://github.com/keycloak/keycloak

### Implementation Details

After deploy:

1. Open the Keycloak URL and click **Administration Console**.
2. Log in with `KC_BOOTSTRAP_ADMIN_USERNAME` (default `admin`) and the generated `KC_BOOTSTRAP_ADMIN_PASSWORD` from the Keycloak service's Variables tab.
3. Keycloak marks this first admin as temporary. Create a permanent admin user in the master realm (Users, then Role mapping: `admin`), log in with it, and delete the temporary one.
4. Create a realm for your apps (do not use `master` for app users) and add a client per app.

Your apps use the realm's OpenID Connect discovery URL:

```
https://<your-domain>/realms/<realm>/.well-known/openid-configuration
```

When you add a custom domain, set `KC_HOSTNAME` to `https://<custom-domain>` and redeploy. Settings that matter:

| Variable | Default | Purpose |
|---|---|---|
| `KC_BOOTSTRAP_ADMIN_USERNAME` | `admin` | First admin, created on the first start only |
| `KC_BOOTSTRAP_ADMIN_PASSWORD` | generated | Its password |
| `KC_HOSTNAME` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL used in tokens and redirects |
| `JAVA_OPTS_KC_HEAP` | `-Xms128m -Xmx768m` | JVM heap. Raise `-Xmx` for many users or sessions |
| `KC_CACHE` | `local` | Single-node caches. One replica is supported |

In our test Keycloak used about 0.75 GB of RAM at idle and Postgres about 0.16 GB, which fits the Hobby plan. Back up the Postgres volume (Railway volume backups or `pg_dump`); all realms, users and clients live there.

## Why Deploy Keycloak 26.8.2 on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Keycloak 26.8.2 on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
