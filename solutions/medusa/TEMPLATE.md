# Deploy and Host Medusa on Railway

Medusa is an open-source commerce platform, often used as a self-hosted Shopify alternative. It gives you a headless commerce API (products, carts, orders, payments, customers, multi-region pricing) and an admin dashboard, and the Next.js Starter Storefront gives you a complete shop front on top of it.

## About Hosting Medusa

A production Medusa install is more than one server. It needs PostgreSQL, Redis for events, workflows and locks, a worker process for background jobs, storage for product images, and a storefront built with a publishable API key that only exists after the backend has run once. It also needs an admin account: Medusa has no sign-up page for the admin, so someone has to create the first user from the command line.

This template sets all of that up in one deploy. The Medusa server, a separate Medusa worker, the storefront, PostgreSQL, Redis and a Railway Bucket are wired over the private network. The admin user and the storefront's publishable key are created on first start, and a demo store is loaded so the shop works the moment the deploy finishes.

## Common Use Cases

- Launch an online store you own, with no per-order platform fees
- Build a custom storefront, app or marketplace on Medusa's headless API
- Sell in several regions and currencies from one backend
- Replace a Shopify or WooCommerce shop that has outgrown its plugins
- B2B ordering portals and catalogs with custom workflows

## Dependencies for Medusa Hosting

- PostgreSQL 18 (products, orders, customers)
- Redis 8 (event bus, workflow engine, locks)
- Railway Bucket (product images and uploads)

### Deployment Dependencies

- Medusa: https://github.com/medusajs/medusa
- Next.js Starter Storefront: https://github.com/medusajs/nextjs-starter-medusa
- Medusa documentation: https://docs.medusajs.com

### Implementation Details

**What you set:** `MEDUSA_ADMIN_EMAIL`, the email you log in to the admin with. Optionally set `SEED_DEMO_DATA=false` before the first deploy for an empty store.

**After deploy:**

1. Wait for the Medusa service to turn healthy (3 to 5 minutes on the first start: migrations and demo data).
2. Open `https://<Medusa domain>/app` and log in with `MEDUSA_ADMIN_EMAIL` and the generated `MEDUSA_ADMIN_PASSWORD`.
3. Open the Storefront URL to see the shop with the demo products.
4. Add your products, regions and payment providers in the admin.

**This template:**

- Creates the admin user from your variables on first start; there is no admin sign-up page, so nobody else can claim the store
- Creates the storefront's publishable API key automatically, so the shop works on the first deploy without copying keys between services
- Runs a separate Medusa worker for background jobs, subscribers and scheduled jobs, so the API stays fast
- Shares events, workflows and locks between server and worker through Redis
- Stores product images in a Railway Bucket and serves them from the Medusa domain
- Keeps PostgreSQL, Redis and the worker private; only the admin/API and the storefront are public
- Pins Medusa 2.22.4, Node 22, PostgreSQL 18 and Redis 8.10, with healthchecks on the server and storefront

**Notes:** card payments need a Stripe key and the Stripe provider in the backend; email needs a notification provider. Both are optional and covered in the Medusa docs.

## Why Deploy Medusa on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Medusa on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
