# Deploy and Host Odoo 20 on Railway

Odoo is open-source business software: CRM, sales, invoicing and accounting, inventory, purchase, manufacturing, projects, website, point of sale and more than 40 other apps that share one database. Odoo Community Edition is LGPL-licensed and is one of the most used self-hosted ERP systems. This template runs Odoo 20, the current major release, from the official image.

## About Hosting Odoo 20

Odoo needs PostgreSQL, a volume for attachments (the filestore), and a database created with an administrator account before anyone can log in. A default Odoo container does none of that safely: the database manager at `/web/database/manager` is open to whoever finds the URL first, many setups ship with `admin` / `admin`, and Odoo 20 listens only on 127.0.0.1 unless told otherwise.

This template runs the official `odoo:20.0` image with PostgreSQL 18 on Railway's private network. The database and the administrator account are created on first start with a generated password, the database manager is switched off, and nothing has to be filled in before the deploy.

## Common Use Cases

- CRM, quotations and sales orders for a small or mid-size company
- Invoicing, payments and accounting
- Inventory, warehouses and purchasing for distribution, retail and e-commerce
- Manufacturing with bills of materials and work orders
- Projects, tasks and timesheets for service companies
- A self-hosted alternative to Odoo Online, ERPNext or NetSuite, with your data in your own database

## Dependencies for Odoo 20 Hosting

- PostgreSQL 18 (private, generated password)

### Deployment Dependencies

- Odoo: https://github.com/odoo/odoo
- Official image: https://hub.docker.com/_/odoo
- Documentation: https://www.odoo.com/documentation/master/

### Implementation Details

**What you set:** nothing. The administrator password, the master password and the database password are generated.

**After deploy:**

1. Wait about a minute for the first start; the Odoo logs show `odoo-setup: database created` when it is ready.
2. Open the Odoo URL and log in as `admin` with the `ODOO_ADMIN_PASSWORD` variable of the Odoo service.
3. Install apps from the **Apps** menu (CRM, Sales, Invoicing, Inventory, ...), or list them in `ODOO_INIT_MODULES` before the first deploy.
4. Change the admin password and e-mail in **Preferences**, and invite your users.
5. Optional: set `SMTP_SERVER`, `SMTP_USER`, `SMTP_PASSWORD` and `EMAIL_FROM` to send e-mail.

**This template:**

- Uses the official `odoo:20.0-20261102` image, pinned, and PostgreSQL 18
- Creates the database on first start with a generated administrator password; `admin` / `admin` never works
- Disables the database manager and database list (`list_db = False`, one database by `dbfilter`), so nobody can create, copy, back up or drop databases from the web
- Sets a generated master password as a second lock
- Listens on 0.0.0.0 (Odoo 20 defaults to 127.0.0.1) with proxy mode on behind Railway's HTTPS
- Runs threaded, so live chat, notifications and the websocket bus work on the single Railway port
- Starts without SMTP settings; empty mail variables don't crash the start
- Never recreates an existing database; updates all modules automatically when you change the image version
- Keeps attachments and sessions on a volume (`/var/lib/odoo`) and PostgreSQL private
- Checks health on `/web/health`

**Notes:** `ODOO_ADMIN_PASSWORD`, `ODOO_LANGUAGE`, `ODOO_COUNTRY`, `ODOO_INIT_MODULES` and `ODOO_WITH_DEMO` are used on the first start only; after that, change them inside Odoo. Odoo Enterprise apps are not included. To let Claude or another AI agent work in Odoo, deploy Odoo 20 + MCP instead.

## Why Deploy Odoo 20 on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Odoo 20 on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
