# EverShop

Deploy a full-featured e-commerce store with EverShop and PostgreSQL on Railway.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Overview

This template deploys a two-service stack:

- **EverShop**: Open-source e-commerce platform with React storefront, admin panel, and GraphQL API
- **PostgreSQL**: Primary database for products, orders, customers, and all application data

EverShop includes built-in admin authentication — no additional auth proxy needed.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          Internet                                │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     EverShop (Public)                             │
│                     Railway-assigned PORT                         │
│                                                                  │
│                     /         → Storefront (React SSR)            │
│                     /admin    → Admin Panel                       │
│                     /graphql  → GraphQL API                       │
│                                                                  │
│                ┌──────────────────────────────┐                  │
│                │     /app/media Volume        │                  │
│                │     Product images & uploads │                  │
│                └──────────────────────────────┘                  │
└───────────────────────────────┬─────────────────────────────────┘
                                │ postgresql://Postgres.railway.internal
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     PostgreSQL (Private)                          │
│                     Railway Plugin v16                            │
│                     Products, orders, customers                   │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

1. Click the **Deploy on Railway** button above
2. Wait for services to deploy (first build takes several minutes)
3. Find your admin credentials in the **EverShop** service **Variables** tab (`ADMIN_EMAIL` and `ADMIN_PASSWORD`)
4. Access the admin panel at `https://your-url.railway.app/admin`

## Services

| Service | Source | Description |
|---------|--------|-------------|
| EverShop | `evershop/Dockerfile` | E-commerce platform (public) |
| PostgreSQL | Railway Plugin | Primary database (private) |

## Accessing EverShop After Deployment

After deployment, click on the **EverShop** service to find your URL:

1. **Deployments Tab**: The URL is displayed directly under the service name
2. **Settings > Networking**: Go to Settings tab → scroll to Networking → find Public Networking

### Storefront

Visit `https://your-url.railway.app/` to see the store. The storefront is empty by default — add products via the admin panel.

### Admin Panel

Visit `https://your-url.railway.app/admin` and log in with the credentials from the Variables tab.

## Environment Variables

### EverShop — User-Configurable

| Variable | Default | Description |
|----------|---------|-------------|
| `ADMIN_EMAIL` | `admin@example.com` | Initial admin user email |
| `ADMIN_PASSWORD` | `${{secret(32)}}` | Initial admin user password (auto-generated) |
| `ADMIN_NAME` | `Admin` | Initial admin display name |
| `SEED_DEMO_DATA` | `true` | Seed demo products, categories, and widgets on first deploy |
| `SENDGRID_API_KEY` | - | SendGrid API key for transactional emails (optional) |
| `SHOP_HOME_URL` | - | Store URL override (auto-detected from `RAILWAY_PUBLIC_DOMAIN` on Railway) |

The admin user is created automatically on first deployment. These variables are only used during initial setup — changing them later does not update existing credentials. Use the admin panel to manage users after deployment.

`SHOP_HOME_URL` is only needed if `RAILWAY_PUBLIC_DOMAIN` is not set (e.g., custom domain without Railway's auto-generated domain). If neither is set, EverShop defaults to `http://localhost:{port}`, which causes incorrect redirects.

### Auto-Configured (Do Not Change)

| Variable | Value | Description |
|----------|-------|-------------|
| `DB_HOST` | `${{Postgres.PGHOST}}` | PostgreSQL host via Railway's private network |
| `DB_PORT` | `${{Postgres.PGPORT}}` | PostgreSQL port |
| `DB_USER` | `${{Postgres.PGUSER}}` | PostgreSQL username |
| `DB_PASSWORD` | `${{Postgres.PGPASSWORD}}` | PostgreSQL password |
| `DB_NAME` | `${{Postgres.PGDATABASE}}` | PostgreSQL database name |

Changing these breaks the database connection.

## Email Notifications (Optional)

This template includes the [@evershop/sendgrid](https://www.npmjs.com/package/@evershop/sendgrid) extension pre-configured. To enable transactional emails:

1. Sign up for a [SendGrid](https://sendgrid.com/) account
2. Create an API key with "Mail Send" permission
3. Add `SENDGRID_API_KEY` to the EverShop service variables in Railway
4. Redeploy the service

Once configured, EverShop sends emails for:
- **Order confirmations** — sent to customers after placing an order
- **Welcome emails** — sent to customers after registration
- **Password reset** — sent when customers request a password reset

The sender address (`from`) is configured in the admin panel under store settings, or can be set in `config/default.json` via `system.notification_emails.from`.

### Using Resend Instead

To use [Resend](https://resend.com/) instead of SendGrid, replace `@evershop/sendgrid` with `@evershop/resend` in `package.json` and `config/default.json`, then set `RESEND_API_KEY` instead of `SENDGRID_API_KEY`.

## Volume

| Service | Mount Path | Purpose |
|---------|------------|---------|
| EverShop | `/app/media` | Product images, category images, and uploaded files |

Data persists across redeployments.

## Troubleshooting

### Login redirects to localhost

EverShop uses `shop.homeUrl` config to generate all URLs. If not set, it defaults to `http://localhost:{port}`. The entrypoint auto-detects this from `RAILWAY_PUBLIC_DOMAIN`. If you're using a custom domain only, set `SHOP_HOME_URL` to your full URL (e.g., `https://shop.example.com`).

### Admin login not working

1. Check `ADMIN_EMAIL` and `ADMIN_PASSWORD` in the EverShop service Variables tab
2. If this is a fresh deployment, wait a minute — the admin user is created shortly after the server starts
3. Check the deploy logs for `[create-admin]` messages

### 502 Bad Gateway

EverShop takes several minutes to start on first deployment (runs database migrations). Check the deploy logs — you should see migration progress.

### Products not showing on storefront

The storefront is empty by default. Log in to the admin panel at `/admin` to add products, categories, and configure your store.

### Uploaded images lost after redeploy

Verify the `/app/media` volume is mounted on the EverShop service in **Settings > Volumes**.

### Database connection errors

Check that `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, and `DB_NAME` are correctly referencing the PostgreSQL service variables. These should be auto-configured — do not change them manually.

## Resources

- [EverShop Documentation](https://evershop.io/docs)
- [EverShop GitHub](https://github.com/evershop/evershop)
- [EverShop Admin Guide](https://evershop.io/docs/development/getting-started/introduction)
