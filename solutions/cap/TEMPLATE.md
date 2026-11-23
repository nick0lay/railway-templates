# Deploy and Host Cap on Railway

Cap is the open-source alternative to Loom. Record your screen, camera and microphone with the Cap desktop app for macOS or Windows, and share a link that plays instantly in any browser. Viewers can comment and react, and you can add transcripts and AI summaries. Your recordings stay in storage you own.

## About Hosting Cap

Cap is a Next.js web app with a separate ffmpeg media server. It keeps users and videos in MySQL and stores recordings in S3-compatible storage, and browsers upload and play them through presigned links. A self-hosted install needs generated secrets, a webhook secret shared with the media server, private networking between the services, and a way to log in: Cap signs you in with email codes.

This template runs the official web app and media server images pinned by digest, with MySQL 8.4 on a volume and your recordings in a private Railway Bucket. You can log in without setting up email, and strangers can't create accounts.

## Common Use Cases

- Async video updates, demos and walkthroughs for your team, instead of meetings
- Bug reports and support replies with a screen recording and a share link
- Product demos and onboarding videos embedded in docs or websites
- A private Loom replacement where you own the recordings and the data
- Recording tutorials with transcripts and AI-generated chapters

## Dependencies for Cap Hosting

- MySQL 8.4
- Railway Bucket (S3-compatible storage) for recordings
- Cap media server (ffmpeg)

### Deployment Dependencies

- Cap: https://github.com/CapSoftware/Cap
- Self-hosting docs: https://cap.so/docs/self-hosting
- Desktop app: https://cap.so/download

### Implementation Details

**What you set:** nothing is required. Optional: `CAP_ALLOWED_SIGNUP_DOMAINS` to control who may create accounts, `RESEND_API_KEY` and `RESEND_FROM_DOMAIN` to email login codes, Google login, and AssemblyAI, OpenAI or Groq keys for transcripts and AI summaries.

**After deploy:**

1. Open the Cap URL, choose Log in and enter your email address.
2. Open the Cap service's deploy logs in Railway and copy the 6-digit code from the VERIFICATION CODE block. Enter it within 10 minutes.
3. In the Cap desktop app settings, set Cap Server URL to your Cap URL and sign in.
4. Set `CAP_ALLOWED_SIGNUP_DOMAINS` to your company domain (or `closed.invalid`) before you turn on email delivery.

**This template:**

- Lets you log in without email: the login code is printed to the Cap deploy logs, which only your project members can read
- Keeps strangers out, because a code they request never reaches them. `CAP_ALLOWED_SIGNUP_DOMAINS` closes sign-up for good
- Pins the Cap web app and media server images by digest instead of the moving `latest` tag
- Stores recordings in a private Railway Bucket with presigned upload and playback links, with no separate MinIO service to run or expose
- Includes the media server on the private network with a generated webhook secret
- Runs MySQL 8.4 LTS on a volume, private, with no public TCP proxy
- Generates every secret (session, encryption and webhook keys)
- Checks health on `/api/status` and `/health`, and restarts crashed services

**Notes:** new recordings get a public share link by default; set `CAP_VIDEOS_DEFAULT_PUBLIC=false` to change that. Never change `DATABASE_ENCRYPTION_KEY` after the first deploy. For a custom domain, set `WEB_URL` and `NEXTAUTH_URL` to it. Upgrade by changing both Cap images together, and back up MySQL first. Cap is licensed under AGPL-3.0. This template is not affiliated with Cap Software, Inc.

## Why Deploy Cap on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Cap on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
