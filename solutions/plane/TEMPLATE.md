# Deploy and Host Plane on Railway

Plane is open-source project management, an alternative to Jira and Linear. Teams plan work in projects with work items, cycles (sprints), modules, and Kanban, list, calendar and Gantt views. Plane also has wiki-style pages with real-time editing, intake for requests, and a REST API.

## About Hosting Plane

Plane consists of a web app, an admin panel, public spaces, a Django API, background workers, a scheduler and a real-time server. It stores data in PostgreSQL, uses Redis for cache and RabbitMQ for background jobs, and keeps attachments in S3-compatible storage. On a fresh install, whoever opens the admin panel first becomes the instance admin.

This template runs Plane's official all-in-one image with PostgreSQL, Redis, RabbitMQ and a Railway Bucket on Railway's private network. It creates your instance admin at deploy and turns off public sign-up.

## Common Use Cases

- Sprint planning and issue tracking for software teams
- Roadmaps and project portfolios with modules and Gantt views
- A self-hosted Jira or Linear replacement that keeps your data in your own database
- Team wikis and specs in pages, linked to work items
- Intake of bug reports and requests from other teams

## Dependencies for Plane Hosting

- PostgreSQL 18
- Redis 8
- RabbitMQ 3.13
- Railway Bucket for attachments

### Deployment Dependencies

- Plane: https://github.com/makeplane/plane
- Documentation: https://developers.plane.so/self-hosting/overview
- Image: https://hub.docker.com/r/makeplane/plane-aio-community

### Implementation Details

**What you set:** `ADMIN_EMAIL`, the email you log in with. Everything else is generated.

**After deploy:**

1. Open the Plane URL and log in with `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD`.
2. Create your workspace and first project.
3. Invite your team from the workspace settings (Members). Invited people can sign up even though public sign-up is off.
4. Manage the instance (sign-up, login methods, email) in the admin panel at `/god-mode`.

**This template:**

- Creates the instance admin on first start, so nobody else can claim your instance
- Turns off public sign-up: only invited people can join
- Runs the whole Plane app in one service from the official all-in-one image (web, admin, spaces, API, workers, real-time server and proxy)
- Stores attachments in a Railway Bucket, uploaded straight from the browser with signed URLs
- Generates `SECRET_KEY` and `LIVE_SERVER_SECRET_KEY`
- Pins Plane 1.4.3, PostgreSQL 18, Redis 8.10 and RabbitMQ 3.13.7
- Keeps Redis and RabbitMQ private, with an append-only file on a volume for Redis
- Checks health on `/api/instances/`

**Notes:** the first deploy takes 3 to 4 minutes while Plane migrates the database. Don't change `SECRET_KEY` after the first deploy. To send invitation emails, set up SMTP in the admin panel under Email.

## Why Deploy Plane on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Plane on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
