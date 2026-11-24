# Deploy and Host SoduWork on Railway

SoduWork is an open-source, self-hosted work engine for teams and their AI agents. People file requests, AI drafts acceptance criteria, an agent harness (Pi, OpenCode, Codex, Qwen Code, Kimi Code and others) does the work, a second agent reviews it, and the person who asked signs off. The Hub holds the accounts, departments, projects, requests, files and plugins, and serves the admin console; the SoduWork desktop app connects to it.

## About Hosting SoduWork

The SoduWork Hub is a Python (FastAPI) server with a web admin console, backed by PostgreSQL. A hosted Hub needs strong secrets, an admin account, public sign-up turned off, and persistent storage for uploads, the document library, repositories and runtime data. Upstream publishes no Docker image, so a template has to build it from source at a fixed release.

This template builds the Hub from the pinned v1.13.19 release, creates the admin account at deploy time, turns off public self-registration, and keeps every state folder on one volume. Postgres 18 holds the database.

## Common Use Cases

- A team Hub for the SoduWork desktop app: requests, AI-run work, AI review and human sign-off
- Assigning work to a colleague's agent and tracking who did what
- Sharing reviewed plugins and skills across a team
- A shared document library and request inbox per department
- Trying SoduWork without a local Docker setup

## Dependencies for SoduWork Hosting

- PostgreSQL 18 (included)
- A Railway volume for uploads, the library, repositories and runtime data (included)
- The SoduWork desktop app for each team member, and your own model API keys

### Deployment Dependencies

- SoduWork: https://github.com/mdiri-ai/soduwork
- Docs: https://dev.soduwork.ai
- Self-hosting guide: https://github.com/mdiri-ai/soduwork/tree/main/ops/self-host

### Implementation Details

**What you set:** nothing is required. The admin user is `admin` and the password is generated.

**After deploy:**

1. Open the SoduWork URL and sign in as `admin` with the `ADMIN_PASS` variable of the `SoduWork` service (Variables tab).
2. Create your departments and users in the admin console, and add model providers.
3. Install the SoduWork desktop app, enter the Hub URL, and sign in with a user you created. Activate new devices in the admin console.

**This template:**

- Builds the Hub from the v1.13.19 release tag, not from the moving main branch
- Generates the admin password, the token signing secret and the connector encryption key (a valid Fernet key)
- Creates the admin on the first boot and turns off public self-registration (admins add users; you can turn it on later in the admin console)
- Keeps uploads, downloads, client releases, workspaces, releases, repositories, runtime data and the home folder on one volume at `/data`
- Runs in production mode, with CORS limited to the Hub's own domain and the desktop app
- Uses Postgres 18, and ships the matching `pg_dump` so in-app backups work
- Checks `/readyz` (Hub and database up) before switching traffic, and runs as a non-root user

**Notes:** the first build takes a few minutes (the admin console, Chromium and the bundled agent CLIs are built in). Agents do not run inside the Hub container: they run on each person's desktop app, or on a Runner you register. The admin password is used only when the first admin is created; change it later in the admin console. Upgrade by changing the release tag in the Dockerfile. SoduWork is MIT licensed. The SoduWork name and logo are trademarks of MDiRi; this template is not affiliated with or endorsed by MDiRi.

## Why Deploy SoduWork on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying SoduWork on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
