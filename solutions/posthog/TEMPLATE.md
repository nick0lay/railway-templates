# Deploy and Host PostHog on Railway

PostHog is an open-source product analytics platform, an alternative to Mixpanel, Amplitude, Hotjar and LaunchDarkly in one tool. It records events from your website and apps, and gives you trends, funnels, retention, user paths, session replay, feature flags, A/B experiments, surveys and a SQL editor over your own data.

## About Hosting PostHog

Self-hosted PostHog is a large system. Events come in through a capture service, pass through Kafka to an ingestion pipeline that resolves people and properties, and land in ClickHouse, where every chart is queried. Postgres holds the app data, Redis caches, Temporal and Celery run background jobs, and S3 storage keeps session recordings and exports. ClickHouse needs PostHog's own configuration, Kafka topics must exist before consumers start, and a fresh instance lets the first visitor sign up as the owner.

This template runs PostHog's official images as 23 services behind one public Caddy entry point, the same routing PostHog's Docker setup uses. It creates your admin account at deploy, configures ClickHouse, Kafka and storage for Railway's private network, and pins every image to one tested PostHog commit.

## Common Use Cases

- Product analytics for a web or mobile app: trends, funnels, retention, paths
- Session replay to watch how users move through your product
- Feature flags and A/B experiments without a separate service
- A Mixpanel, Amplitude or Hotjar replacement that keeps event data on your own infrastructure
- In-app surveys and a SQL editor over raw events

## Dependencies for PostHog Hosting

- ClickHouse 26.9 (PostHog build), Kafka API (Redpanda 25.1), ZooKeeper 3.7
- PostgreSQL 15, Redis 7.2, S3 storage (SeaweedFS)
- Temporal 1.29

### Deployment Dependencies

- PostHog: https://github.com/PostHog/posthog
- Self-hosting docs: https://posthog.com/docs/self-host
- Docker setup this template follows: https://github.com/PostHog/posthog/blob/master/docker-compose.hobby.yml

### Implementation Details

**What you set:** `POSTHOG_ADMIN_EMAIL`, the email you log in with. Optionally `POSTHOG_ORGANIZATION_NAME`.

**After deploy:**

1. Wait for the first start: Web runs PostHog's migrations, about 30 minutes. Its logs show `posthog-setup: starting web server` when ready.
2. Open the PostHog URL and log in with `POSTHOG_ADMIN_EMAIL` and the generated `POSTHOG_ADMIN_PASSWORD` (Web service → Variables).
3. Copy the project API key from Settings → Project and add the snippet to your site, with `api_host` set to your PostHog URL.

**This template:**

- Creates the admin at deploy, so no visitor can claim your instance; new organizations can't be created after that
- Exposes one public service; ClickHouse, Kafka, Postgres, Redis and storage stay private
- Generates the Django secret, encryption salt, storage keys and database password
- Configures ClickHouse from the same PostHog commit as the images, pre-creates Kafka topics, and prepares the plugin server's job queue database
- Includes session replay, feature flags, surveys, destinations and batch exports
- Leaves out error tracking symbolication, LLM analytics and logs capture, and heatmap screenshots (see the README)

**Notes:** PostHog needs a lot of resources. The services idle at about 15 GB of RAM together, so expect a larger Railway bill than a single app.

## Why Deploy PostHog on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying PostHog on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
