# EverShop Railway Template

## Template Overview

# Deploy and Host EverShop on Railway

EverShop is an open-source e-commerce platform built with React, GraphQL, and Node.js. It provides a modern storefront, powerful admin panel, and flexible GraphQL API — all deployable with one click on Railway.

## About Hosting EverShop

This template deploys a production-ready e-commerce stack:

- **EverShop**: Full-featured e-commerce platform with React SSR storefront, admin dashboard, and GraphQL API
- **PostgreSQL**: Primary database for products, orders, customers, and all application data
- **Persistent Storage**: Railway volume for product images and uploaded files
- **Auto-Setup**: Initial admin user and optional demo data created automatically on first deploy
- **Email Support**: Optional SendGrid or Resend integration for order confirmations, welcome emails, and password resets

## Getting Started After Deployment

### Accessing the Admin Panel

The admin panel is located at `/admin` — you must append this path to your Railway URL manually. It is not linked from the storefront.

1. Click on the **EverShop** service in your Railway dashboard
2. Find your public URL in the **Deployments** tab or **Settings > Networking**
3. Open `https://your-url.up.railway.app/admin` in your browser
4. Log in with your admin credentials (see below)

### Admin Credentials

The admin password is auto-generated on deploy. To find it:

1. Open your Railway project dashboard
2. Click on the **EverShop** service
3. Go to the **Variables** tab
4. Find `ADMIN_EMAIL` and `ADMIN_PASSWORD` — click the eye icon to reveal

### Setting Up Your Store

1. Log in to the admin panel at `/admin`
2. If demo data is enabled (`SEED_DEMO_DATA=true`), your store comes pre-populated with sample products, categories, and widgets
3. Add or edit product categories under **Catalog > Categories**
4. Add or edit products under **Catalog > Products**
5. Configure shipping, payment, and tax settings
6. Visit your storefront at the root URL to see your store

### Email Notifications (Optional)

To enable transactional emails (order confirmations, welcome emails, password resets):

1. Sign up for a [SendGrid](https://sendgrid.com/) account and create an API key
2. In your Railway project, click on the **EverShop** service → **Variables** tab
3. Add `SENDGRID_API_KEY` with your API key
4. Redeploy the service

Emails are sent for order confirmations, customer registration, and password resets. You can also use [Resend](https://resend.com/) as an alternative — see the [README](./README.md) for details.

## Common Use Cases

- Online retail stores with product catalogs and checkout
- Headless commerce with the GraphQL API powering custom frontends
- Marketplace MVP for testing product-market fit
- Digital product stores with downloadable goods
- B2B wholesale portals with custom pricing
- Drop-shipping storefronts with third-party fulfillment

## Dependencies for EverShop Hosting

- Docker (runs as a container)
- Node.js 20 (Alpine-based image)

### Deployment Dependencies

- [Node.js 20 Alpine Docker Image](https://hub.docker.com/_/node)
- [@evershop/evershop npm package](https://www.npmjs.com/package/@evershop/evershop)

### Services

| Service | Source | Description |
|---------|--------|-------------|
| EverShop | Custom Dockerfile | E-commerce platform (public) |
| PostgreSQL | Railway Plugin | Primary database (private) |

### Environment Variables

#### EverShop

| Variable | Description |
|----------|-------------|
| `ADMIN_EMAIL` | Initial admin email (default: `admin@example.com`) |
| `ADMIN_PASSWORD` | Initial admin password (`${{secret(32)}}` auto-generates) |
| `ADMIN_NAME` | Initial admin display name (default: `Admin`) |
| `SEED_DEMO_DATA` | Seed demo products, categories, and widgets on first deploy (default: `true`) |
| `SENDGRID_API_KEY` | SendGrid API key for transactional emails (optional) |
| `DB_HOST` | PostgreSQL host (auto-configured) |
| `DB_PORT` | PostgreSQL port (auto-configured) |
| `DB_USER` | PostgreSQL username (auto-configured) |
| `DB_PASSWORD` | PostgreSQL password (auto-configured) |
| `DB_NAME` | PostgreSQL database name (auto-configured) |

### Volume

| Service | Mount Path | Purpose |
|---------|------------|---------|
| EverShop | `/app/media` | Product images, category images, and uploads |

## Key Features

### Modern Storefront
React-based server-side rendered storefront with fast page loads, SEO optimization, and responsive design out of the box.

### Admin Dashboard
Full-featured admin panel for managing products, orders, customers, categories, coupons, and store settings — accessible at `/admin`.

### GraphQL API
Flexible GraphQL API for building custom integrations, mobile apps, or headless commerce experiences with any frontend framework.

### Built-in Authentication
Native admin authentication with email/password login. No additional auth proxy or configuration required.

### Transactional Emails
Optional SendGrid or Resend integration for order confirmations, customer welcome emails, and password reset notifications. Just add your API key — no code changes needed.

### Demo Data
Deploy with a fully populated demo store including sample products, categories, widgets, and CMS pages. Perfect for evaluating the platform before adding your own products.

### Extensible Architecture
Module-based architecture supporting custom extensions and themes. Add payment gateways, shipping providers, and custom functionality.

### Persistent Storage
Railway volume ensures product images and uploaded files survive redeployments and container restarts.

## Why Deploy EverShop on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying EverShop on Railway, you get a production-ready e-commerce store with PostgreSQL, persistent file storage, and automatic admin setup — all configured and ready to use. Host your servers, databases, AI agents, and more on Railway.
