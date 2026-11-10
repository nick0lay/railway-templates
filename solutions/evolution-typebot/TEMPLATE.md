# Deploy and Host Evolution API + Typebot on Railway

Evolution API + Typebot gives you WhatsApp chatbots without writing code. Typebot is an open-source visual flow builder; Evolution API connects a WhatsApp number by scanning a QR code, like WhatsApp Web, with no Meta Business approval. Messages to your number start a Typebot flow, and its replies, buttons and media go back to the chat.

## About Hosting Evolution API + Typebot

Evolution API is a Node.js service that keeps WhatsApp sessions open and exposes them as a REST API with a web manager. For each chat it calls Typebot's viewer, which runs your published flows. Typebot also has a builder app for editing flows, and both apps need PostgreSQL and Redis. Typebot signs users in with an emailed code and stores images in S3-compatible storage.

This template deploys the whole stack on Railway's private network: Evolution API with its own PostgreSQL and Redis, the Typebot builder and viewer with their own PostgreSQL and Redis, a Railway Bucket for uploads, and Mailpit to catch the sign-in emails. The Typebot integration is already turned on in Evolution API and set to the API that Typebot 3 uses.

## Common Use Cases

- WhatsApp lead qualification and booking flows
- Customer support FAQ bots that hand over to a human when you reply from the phone
- Order status, reminders and surveys on WhatsApp
- AI answers on WhatsApp with Typebot's OpenAI and Anthropic blocks
- Running several WhatsApp numbers, each with its own flow

## Dependencies for Evolution API + Typebot Hosting

- PostgreSQL 18 (two: one for each app)
- Redis 8 (two: one for each app)
- Railway Bucket (S3-compatible storage)
- Mailpit (catches Typebot sign-in emails until you add SMTP)

### Deployment Dependencies

- Evolution API: https://github.com/evolution-foundation/evolution-api
- Evolution API docs: https://doc.evolution-api.com
- Typebot: https://github.com/baptisteArno/typebot.io
- Typebot docs: https://docs.typebot.io

### Implementation Details

**What you set:** only `ADMIN_EMAIL`, the email you sign in to Typebot with.

**After deploy:**

1. Open the `typebot-builder` URL, enter your `ADMIN_EMAIL`, and get the sign-in code from the `mailpit` URL (user `admin`, password `MAILPIT_PASSWORD`).
2. Build a flow in Typebot, click Publish, and copy its public ID from the Share tab.
3. Open `https://<evolution-domain>/manager`, log in with the `AUTHENTICATION_API_KEY` of the Evolution API service, create an instance and scan its QR code in WhatsApp (Settings → Linked devices).
4. In the instance's Typebot integration, add a bot: URL = the `TYPEBOT_URL` variable of Evolution API, Typebot = the public ID, trigger = all messages or a keyword.
5. Message your number from another phone.

**This template:**

- Pins Evolution API 2.3.7 (the image's `latest` tag is a release candidate), Typebot 3.19, PostgreSQL 18 and Redis 8.10
- Turns on the Typebot integration with `TYPEBOT_API_VERSION=latest`, Typebot's current chat API (Evolution API 2.3 otherwise defaults to the deprecated one)
- Puts the viewer URL in a `TYPEBOT_URL` variable, ready to paste
- Gives each app its own database, because both run Prisma migrations in the same schema name
- Protects every public service: generated Evolution API key, Typebot sign-up limited to `ADMIN_EMAIL` and invited people, Mailpit behind a generated password
- Stores WhatsApp sessions in PostgreSQL so restarts don't log your number out, and saves messages, contacts and chats
- Uses a Railway Bucket for uploads, with a read-only file server for the `public/` folder

**Notes:** Evolution API passes your contact's `remoteJid` and `pushName` to the flow, and also its global `apiKey`; only declare that variable in a flow that needs it. Don't change `ENCRYPTION_SECRET` after the first deploy. Upgrade Typebot by changing the builder and viewer to the same tag. WhatsApp may ban numbers that send bulk or unsolicited messages. Evolution API and Typebot are not affiliated with WhatsApp or Meta.

## Why Deploy Evolution API + Typebot on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Evolution API + Typebot on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
