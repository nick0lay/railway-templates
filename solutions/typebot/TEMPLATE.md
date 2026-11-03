# Deploy and Host Typebot on Railway

Typebot is an open-source chatbot builder. You design conversations visually (lead forms, quizzes, customer support, AI chats with OpenAI or Anthropic), then embed them on your website, share a link, or connect them to WhatsApp. Results are collected in one place and can be sent to Google Sheets, webhooks, Zapier or Make.

## About Hosting Typebot

Typebot has two web apps: the builder, where you create bots, and the viewer, which runs them for your visitors. They share a PostgreSQL database and Redis, and need S3-compatible storage for images and files used in bots. Typebot signs users in with an emailed link, so it also needs a way to send email.

This template deploys all of it on Railway's private network with persistent volumes, and a Railway Bucket for storage. A built-in mail catcher (Mailpit) receives the sign-in emails, so you can log in right after deploy without configuring an email provider. You can switch to real SMTP later.

## Common Use Cases

- Lead generation and qualification forms that feel like a conversation
- Customer support and FAQ bots, including AI answers with OpenAI or Anthropic
- Quizzes, surveys and onboarding flows embedded on your website
- WhatsApp bots for orders, bookings and support
- Collecting results into Google Sheets, a webhook or your CRM

## Dependencies for Typebot Hosting

- PostgreSQL 18
- Redis 8
- Railway Bucket (S3-compatible storage)
- Mailpit (catches sign-in emails until you add SMTP)

### Deployment Dependencies

- Typebot: https://github.com/baptisteArno/typebot.io
- Self-hosting docs: https://docs.typebot.io/self-hosting
- Mailpit: https://github.com/axllent/mailpit

### Implementation Details

**What you set:** only `ADMIN_EMAIL`, the email you sign in with.

**After deploy:**

1. Open the `typebot-builder` URL and enter your `ADMIN_EMAIL`.
2. Open the `mailpit` URL, log in as `admin` with the generated `MAILPIT_PASSWORD`, and click the link in the "Sign in to Typebot" email.
3. Build a bot, publish it, and embed it from the Share tab. It runs on the `typebot-viewer` URL.

**This template:**

- Lets you sign in without an email provider (Mailpit catches the sign-in emails behind a password)
- Uses a Railway Bucket instead of MinIO, with a small read-only file server (`files`) that publishes only the bucket's `public/` folder, because Railway Buckets are private
- Closes sign-up: only `ADMIN_EMAIL` and invited people can create accounts
- Pins tested versions (Typebot 3.19, Postgres 18, Redis 8.10) and has health checks on every service
- Unlocks all features for self-hosted workspaces (`DEFAULT_WORKSPACE_PLAN=UNLIMITED`)

**Notes:**

- To send real emails (invitations, notifications), set the `SMTP_*` variables on `typebot-builder` to your provider. The viewer takes them over automatically.
- Don't change `ENCRYPTION_SECRET` after the first deploy; credentials saved in your bots depend on it.
- Upgrade by changing the image tag of `typebot-builder` and `typebot-viewer` to the same version.

## Why Deploy Typebot on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Typebot on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
