# Cap (open-source Loom)

Self-hosted [Cap](https://github.com/CapSoftware/Cap) on Railway: the open-source alternative to Loom. Record your screen with the Cap desktop app, and share a link that plays in any browser. This template runs the official web app and media server images pinned by digest, with MySQL 8.4 on a volume, recordings in a Railway Bucket, and every secret generated. You can log in without setting up email, and nobody else can create an account unless you allow it.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/cap-open-source-loom?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
        Cap desktop app / your browser            viewers of shared links
                       │ HTTPS                             │ HTTPS
                       ▼                                   ▼
┌────────────────────────────────────────────────────────────────────┐
│ Railway project                                                    │
│                                                                    │
│  Cap :3000 (public)  ── private network ──►  MediaServer :3456     │
│    web app, login, share pages,  ◄── webhook ──  (private)         │
│    upload and playback links                  ffmpeg: verify,      │
│    migrates MySQL on start                    remux, thumbnails    │
│        │                    │                        │             │
│        ▼                    ▼                        ▼             │
│  MySQL :3306          Bucket (S3) ◄──────────────────┘             │
│  (private, volume)    recordings; the app and viewers reach it     │
│  users, videos        through short-lived presigned links          │
└────────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| Cap | `ghcr.io/capsoftware/cap-web` (pinned by digest) | Next.js web app (public): login, dashboard, share pages, upload and playback links. Runs database migrations on start, healthcheck `/api/status` |
| MediaServer | `ghcr.io/capsoftware/cap-media-server` (pinned by digest) | ffmpeg worker (private): verifies and remuxes recordings, makes thumbnails and previews, reports back to Cap over the private network |
| MySQL | `mysql:8.4.13` | Users, organizations, videos, comments (private, volume) |
| Bucket | Railway Bucket | The recordings themselves. Uploads and playback use presigned URLs, so the bucket stays private |

## What this template does differently

- **Login without email setup.** Cap signs you in with a 6-digit email code. Without an email provider, Cap prints the code to the `Cap` service's deploy logs, so you can log in right away. Only members of your Railway project can read those logs.
- **Nobody else can sign up.** Someone who finds your URL can ask for a code, but the code only appears in your logs, so they can't use it. Before you turn on email delivery, set `CAP_ALLOWED_SIGNUP_DOMAINS` (see "After deploy").
- **Pinned images.** Cap publishes only a `latest` tag. This template pins the web app and media server to the image digests it was tested with, so a new upstream build can't break your instance on redeploy.
- **Railway Bucket instead of MinIO.** You don't run or expose a separate MinIO service. The bucket is private, and recordings are uploaded and played through short-lived presigned links.
- **Media server included and connected.** MediaServer is private. It shares a generated webhook secret with Cap, and Cap listens on IPv6 as well, so it is reachable over Railway's private network.
- **Private database.** MySQL 8.4 LTS has a volume and no public TCP proxy. The app connects over the private network.
- **Healthchecks and restart policy.** Railway waits for `/api/status` and `/health` before it switches traffic, and restarts a crashed service.

## After deploy

1. Open the `Cap` URL and choose **Log in**. Enter your email address.
2. Open the `Cap` service in Railway, go to **Deployments → View logs**, and find the `VERIFICATION CODE` block for your email address. Enter the 6-digit code. It expires after 10 minutes.
3. Finish onboarding (name and organization).
4. Install the [Cap desktop app](https://cap.so/download). In its settings, set **Cap Server URL** to your `Cap` URL, then sign in. Recordings now upload to your Railway Bucket.
5. Close sign-up for good. After your own account exists, set `CAP_ALLOWED_SIGNUP_DOMAINS` on `Cap`. Use your company domain to let teammates join, or `closed.invalid` to allow nobody new. Existing accounts can still log in.
6. Optional: to send login codes by email, add `RESEND_API_KEY` and `RESEND_FROM_DOMAIN` from [Resend](https://resend.com). Do step 5 first. With email turned on, anyone allowed by `CAP_ALLOWED_SIGNUP_DOMAINS`, or anyone at all if it is empty, can create an account.

New recordings get a public share link by default. Set `CAP_VIDEOS_DEFAULT_PUBLIC=false` to make them private until you share them.

## Variables

### User-configurable (on `Cap`)

| Variable | Default | Notes |
|---|---|---|
| `CAP_ALLOWED_SIGNUP_DOMAINS` | empty | Comma-separated email domains that may create new accounts. `closed.invalid` allows nobody new. It applies to new accounts only; existing users can always log in |
| `RESEND_API_KEY`, `RESEND_FROM_DOMAIN` | empty | Optional. Email login codes and notifications through Resend. Without them, codes go to the deploy logs |
| `CAP_VIDEOS_DEFAULT_PUBLIC` | `true` | `false` makes new recordings private by default |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | empty | Optional. Adds "Sign in with Google" (redirect URI `https://YOUR-DOMAIN/api/auth/callback/google`) |
| `ASSEMBLY_API_KEY` | empty | Optional. AssemblyAI transcripts and captions |
| `OPENAI_API_KEY`, `GROQ_API_KEY` | empty | Optional. AI titles, summaries and chapters |

Cap supports more options, including OIDC login, other AI providers and S3-compatible storage per organization. See the upstream [environment reference](https://github.com/CapSoftware/Cap/blob/main/packages/env/server.ts).

### Auto-configured (do not change)

| Variable | Value | Why |
|---|---|---|
| `NEXTAUTH_SECRET` | generated, 64 hex | Signs login sessions |
| `DATABASE_ENCRYPTION_KEY` | generated, 64 hex | Encrypts stored credentials, such as custom S3 keys. **Never change it after the first deploy** |
| `MEDIA_SERVER_WEBHOOK_SECRET` | generated, 64 hex | Shared with MediaServer (`${{Cap.MEDIA_SERVER_WEBHOOK_SECRET}}`) |
| `WEB_URL`, `NEXTAUTH_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL in links. Change both if you add a custom domain |
| `DATABASE_URL` | `mysql://cap:...@${{MySQL.RAILWAY_PRIVATE_DOMAIN}}:3306/cap` | Private network |
| `MEDIA_SERVER_URL`, `MEDIA_SERVER_WEBHOOK_URL` | private domains, ports 3456 and 3000 | Cap and MediaServer talk over the private network |
| `CAP_AWS_*`, `S3_PUBLIC_ENDPOINT`, `S3_INTERNAL_ENDPOINT`, `S3_PATH_STYLE` | `${{Bucket.*}}`, `true` | The Railway Bucket |
| `PORT` | `3000` (Cap), `3456` (MediaServer) | |

## Custom domain

Add the domain to the `Cap` service. Then set `WEB_URL` and `NEXTAUTH_URL` to `https://your-domain` and point the desktop app at the new URL.

## Upgrading

Cap publishes `latest` images only. To upgrade, set both `Cap` and `MediaServer` to a newer image (`ghcr.io/capsoftware/cap-web:latest` and `ghcr.io/capsoftware/cap-media-server:latest`, or newer digests) at the same time. Cap migrates MySQL on start. Back up the MySQL volume first, because a migrated database can't go back to an older version.

## Backups

Your account data is in MySQL and your recordings are in the Bucket. Turn on volume backups for MySQL in Railway. Bucket objects are not part of the MySQL backup.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| No login email arrives | Expected without Resend. The code is in the `Cap` deploy logs (`VERIFICATION CODE`). Use the newest one; each code expires after 10 minutes |
| `AccessDenied` when signing up | `CAP_ALLOWED_SIGNUP_DOMAINS` doesn't include your email domain. Existing accounts are not affected |
| `Rate limit check failed ... 307` lines in the logs | Harmless. Cap's hosted rate limiter (Vercel Firewall) isn't available when self-hosted, so Cap uses its built-in limit in the process. Any verify attempt, right or wrong, uses up the code, so codes can't be guessed |
| Recording stays "processing" | Check the `MediaServer` logs. Both services must run, and `MEDIA_SERVER_WEBHOOK_SECRET` must match on both |
| Desktop app can't connect | Use the full `https://` URL of `Cap` in the desktop app settings, and update it after a domain change |
| Upload fails with a storage error | The Bucket variables on `Cap` must reference the template's `Bucket`. Don't remove the bucket |

## Testing

Tested on Railway on 2026-11-23. All three services became healthy within a minute, and idle memory was about 0.5 GB in total. Anonymous requests to the dashboard and the upload and desktop APIs were refused, and a wrong code gave no session. The owner signed in with the code from the deploy log. A stranger's code request gave them nothing they could use. The test uploaded an MP4 through the desktop API to the Railway Bucket. The media server verified it with a full decode, and it played back through presigned links, both for the owner and anonymously on the public share page. After `CAP_ALLOWED_SIGNUP_DOMAINS` was set and all services were redeployed, the owner could still log in and the recording still played, and a new sign-up was refused. Not tested: the desktop app itself, the browser UI, email delivery and AI features.

## License

Cap is licensed under the [GNU Affero General Public License v3.0](https://github.com/CapSoftware/Cap/blob/main/LICENSE) (AGPL-3.0), with some desktop crates under MIT. If you modify Cap and let others use it over a network, you must offer them your modified source code. This template is not affiliated with Cap Software, Inc. You are responsible for your instance and the recordings you store in it.
