# Deploy and Host Plausible Analytics on Railway

Plausible Analytics is lightweight, open-source web analytics, an alternative to Google Analytics. It needs no cookies and collects no personal data, so most sites can use it without a cookie banner. The tracking script is under 1 KB, and the dashboard shows visitors, pages, sources, countries, devices, goals and funnels on a single page.

## About Hosting Plausible Analytics

Plausible Community Edition runs as one Elixir app with two databases: PostgreSQL for users, sites and settings, and ClickHouse for pageviews and events. ClickHouse uses a lot of memory and disk with its default settings, both databases have to be created and migrated on the first start and after upgrades, and a fresh install lets the first visitor to the sign-up page become the owner, so the owner account should exist before the URL is shared.

This template creates your owner account at deploy and limits sign-up to people you invite. Postgres and ClickHouse are private, on volumes, and ClickHouse runs with Plausible's low-memory settings and small internal log tables. Databases are created and migrated on every start, and every version is pinned and tested.

## Common Use Cases

- Privacy-friendly analytics for websites, blogs and docs, without a cookie banner
- A self-hosted Google Analytics alternative with your data on your own infrastructure
- Analytics for many client sites from one dashboard, with shared or public dashboards
- Goals, custom events, revenue tracking and funnels for marketing sites and SaaS landing pages
- Traffic data for your own tools through Plausible's Stats API

## Dependencies for Plausible Analytics Hosting

- PostgreSQL 17
- ClickHouse 24.12

### Deployment Dependencies

- Plausible Community Edition: https://github.com/plausible/community-edition
- Plausible Analytics: https://github.com/plausible/analytics
- Configuration: https://github.com/plausible/community-edition/wiki/configuration

### Implementation Details

**What you set:** `ADMIN_EMAIL`, the email you log in with. Optionally `ADMIN_NAME`.

**After deploy:**

1. Open the Plausible URL and log in with `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD` (Plausible service → Variables).
2. Click Add a website, enter your domain and paste the script tag into your site's `<head>`.
3. To invite teammates or get weekly reports by email, add SMTP variables (see the README).

**This template:**

- Creates the owner account at deploy, so no visitor can claim your instance
- Limits sign-up to invited people (`DISABLE_REGISTRATION=invite_only`)
- Keeps PostgreSQL and ClickHouse private, with no public domain or TCP proxy
- Tunes ClickHouse for a small service: Plausible's low-memory settings, high-volume internal logs off
- Creates and migrates both databases on every start, so upgrades need no manual step
- Keeps geolocation data and temporary files on a volume
- Generates the session secret and the two-factor encryption key
- Pins Plausible v3.2.1, ClickHouse 24.12 and PostgreSQL 17, with a healthcheck that also checks both databases

**Notes:** the three services idle at about 1.1 GB of RAM together. Country-level geolocation works out of the box; city-level data needs a free MaxMind license key. Email needs an SMTP provider; without one, everything else works, but invitations and password-reset emails are not sent.

## Why Deploy Plausible Analytics on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Plausible Analytics on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
