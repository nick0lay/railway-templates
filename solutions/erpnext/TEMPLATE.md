# Deploy and Host ERPNext on Railway

ERPNext is open-source ERP software built on the Frappe framework. It covers accounting, invoicing, inventory, sales and purchasing, manufacturing, projects, assets, CRM and HR in one system, with a web interface, a REST API and support for many countries' taxes and charts of accounts. It is a common alternative to Odoo, SAP Business One and NetSuite. ERPNext v16 also includes an MCP server, so Claude and other AI agents can work with your ERP data under a normal user login.

## About Hosting ERPNext

ERPNext runs several processes: a gunicorn web server, a socket.io realtime server, background workers, a scheduler and nginx. It stores data in MariaDB and uses Redis for cache and job queues. The site, with its database and Administrator account, must be created with `bench new-site` before anyone can log in, and every upgrade needs `bench migrate`. Frappe's compose files share one volume between all processes, which Railway doesn't allow.

This template runs Frappe's official ERPNext v16 image with MariaDB 11.8 and two Redis instances on Railway's private network. The web, realtime, worker, scheduler and nginx processes run in one service with the site volume. The site is created on first start with a generated Administrator password.

## Common Use Cases

- Accounting, invoicing and payments for a small or mid-size company
- Inventory, warehouses, purchasing and sales orders for distribution and retail
- Manufacturing with bills of materials, work orders and production planning
- Projects, timesheets and billing for service companies
- Letting Claude or another AI agent look up invoices, stock and orders, or draft documents, through ERPNext's MCP server
- A self-hosted Odoo or NetSuite replacement with your data in your own database

## Dependencies for ERPNext Hosting

- MariaDB 11.8
- Redis 8 (cache)
- Redis 8 (job queue and realtime events)

### Deployment Dependencies

- ERPNext: https://github.com/frappe/erpnext
- Frappe Docker: https://github.com/frappe/frappe_docker
- Documentation: https://docs.frappe.io/erpnext
- Image: https://hub.docker.com/r/frappe/erpnext

### Implementation Details

**What you set:** nothing. The Administrator password and all database and Redis passwords are generated.

**After deploy:**

1. Wait 3 to 6 minutes for the first start; the ERPNext logs show `erpnext-setup: site created` when it is ready.
2. Open the ERPNext URL and log in as `Administrator` with the `ADMIN_PASSWORD` variable of the ERPNext service.
3. Complete the setup wizard: country, currency, company and fiscal year.
4. Add users and roles, and set up an email account to send invoices.
5. To connect Claude: create a user with limited roles for the agent, then in claude.ai add a custom connector with the URL `https://<your-url>/api/v2/mcp` and log in as that user. For Claude Code, generate an API key for the user and pass it as `Authorization: token <key>:<secret>`.

**This template:**

- Uses Frappe's official `frappe/erpnext` v16.54.0 image and MariaDB 11.8.9 with the utf8mb4 settings Frappe requires
- Creates the site and installs ERPNext on first start, with a generated Administrator password; later starts skip it
- Runs `bench migrate` automatically when you change the image version
- Runs web, realtime, background worker, scheduler and nginx in one service, with site files and attachments on a volume
- Enables the scheduler, so emails, recurring documents and auto-repeat work
- Keeps MariaDB and both Redis instances private, with generated passwords
- Stores MariaDB data and the job queue on volumes
- Serves ERPNext's built-in MCP server at `/api/v2/mcp` on the same domain, behind ERPNext login (OAuth or API key)
- Checks health on `/api/method/ping`

**Notes:** connect agents as a user with limited roles, never as Administrator. Set `HOST_NAME` to your custom domain if you add one, so emails and links use it. Changing `ADMIN_PASSWORD` after the first deploy has no effect; change the password in ERPNext. Back up from **Backups** in ERPNext before upgrading.

## Why Deploy ERPNext on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying ERPNext on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
