# GitLab CE + Runner

Self-hosted [GitLab Community Edition](https://gitlab.com/gitlab-org/gitlab) on Railway: Git hosting, merge requests, issues and CI/CD in one app, plus a GitLab Runner that registers itself. The root password is generated, sign-up is turned off before the instance is reachable, and the version is pinned and tested. Git works over HTTPS and over SSH through a Railway TCP proxy.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/gitlab-ce-runner?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
            Browser / git over HTTPS                 git over SSH
                       │ HTTPS                           │ TCP proxy
                       ▼                                 ▼
┌───────────────────────────────────────────────────────────────────┐
│ Railway project                                                   │
│                                                                   │
│  GitLab :80 (public domain) + :22 (TCP proxy)                     │
│    nginx → workhorse → puma (Rails), sidekiq, gitaly, sshd        │
│    bundled PostgreSQL and Redis                                   │
│    volume /var/opt/gitlab: repos, database, uploads, /etc/gitlab  │
│        ▲                                                          │
│        │ http://gitlab.railway.internal (private network)         │
│        │                                                          │
│  GitLab Runner (private, no domain)                               │
│    shell executor, volume /etc/gitlab-runner                      │
└───────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Source | Role |
|---------|--------|------|
| GitLab | `gitlab/gitlab-ce:19.5.3-ce.0` | Web UI, API, Git over HTTPS and SSH, with bundled PostgreSQL, Redis and Gitaly (public, volume) |
| GitLab Runner | `gitlab/gitlab-runner:v19.5.2` | Runs CI jobs with the shell executor. Registers itself on first start (private, volume). Optional: delete it if you don't need CI or bring your own runner |

## What this template does differently

- **No open sign-up window.** GitLab allows anyone to register on a fresh install. Here a first-start step turns sign-up off, and the healthcheck only passes after that step has run, so the deploy doesn't go green with sign-up open. Log in as `root` with the generated `GITLAB_ROOT_PASSWORD`.
- **Secrets survive redeploys.** GitLab keeps its encryption keys (`gitlab-secrets.json`), `gitlab.rb` and SSH host keys in `/etc/gitlab`, which a Railway service can't mount as a second volume. The start command moves `/etc/gitlab` onto the data volume, so CI variables, 2FA secrets and runner tokens stay readable and SSH clients see the same host key after a redeploy.
- **Tuned for about 3 GB of memory.** Puma in single mode, 10 Sidekiq threads, bundled Prometheus and exporters off, KAS off, PostgreSQL `shared_buffers` 256 MB, two nginx workers, and jemalloc set to return memory quickly.
- **Runner registered automatically.** Recent GitLab disables runner registration tokens. On first start GitLab creates a personal access token with only the `create_runner` scope (expires after 30 days); the runner uses it once to create an instance runner and register, and keeps its config on a volume.
- **Git over SSH** through a Railway TCP proxy, with clone URLs showing the proxy host and port.
- **Pinned version** instead of `latest`, so GitLab upgrades only when you choose.

## After deploy

1. Wait for the GitLab service to turn healthy (about 4 minutes on the first start; the image is 1.6 GB).
2. Open the GitLab URL and log in as `root` with the `GITLAB_ROOT_PASSWORD` variable.
3. Change the root email under **Edit profile** (it starts as `admin@example.com`) and turn on two-factor authentication.
4. Create users under **Admin → Users**, or turn sign-up back on under **Admin → Settings → General → Sign-up restrictions** (new sign-ups then need admin approval).
5. Check **Admin → CI/CD → Runners**: `railway-shell` should be online.
6. For SSH, add your public key under **Edit profile → SSH Keys**. Clone URLs look like `ssh://git@<proxy-host>:<port>/group/project.git`.

## Variables

### User-configurable

| Variable | Service | Default | Notes |
|---|---|---|---|
| `GITLAB_ROOT_PASSWORD` | GitLab | generated | Password of `root`. Applied on the first start only; change it in GitLab afterwards |
| `GITLAB_HOST` | GitLab | `${{RAILWAY_PUBLIC_DOMAIN}}` | Host in GitLab's URLs and clone links. Set it to your custom domain |
| `GITLAB_OMNIBUS_CONFIG` | GitLab | tuned settings | GitLab settings in Ruby (`gitlab.rb` syntax). Append lines for SMTP, more Puma workers and so on |
| `RUNNER_NAME` | GitLab Runner | `railway-shell` | Name shown in GitLab |
| `RUNNER_TAGS` | GitLab Runner | `shell,railway` | Runner tags. The runner also takes untagged jobs |

To send email (password resets, notifications), append SMTP settings to `GITLAB_OMNIBUS_CONFIG`, for example `gitlab_rails['smtp_enable'] = true`, `gitlab_rails['smtp_address'] = 'smtp.example.com'`, `gitlab_rails['smtp_port'] = 587`, `gitlab_rails['smtp_user_name']`, `gitlab_rails['smtp_password']`, `gitlab_rails['gitlab_email_from']`. See GitLab's [SMTP docs](https://docs.gitlab.com/omnibus/settings/smtp/).

### Auto-configured (do not change)

| Variable | Service | Value | Why |
|---|---|---|---|
| `GITLAB_SSH_HOST`, `GITLAB_SSH_PORT` | GitLab | `${{RAILWAY_TCP_PROXY_DOMAIN}}`, `${{RAILWAY_TCP_PROXY_PORT}}` | Shown in SSH clone URLs |
| `GITLAB_RUNNER_BOOTSTRAP_PAT` | GitLab | generated | Personal access token (scope `create_runner`, 30 days) the runner uses to register once |
| `GITLAB_SETUP_RB` | GitLab | Ruby script | Runs once on the first start: turns sign-up off and creates the bootstrap token |
| `GITLAB_POST_RECONFIGURE_SCRIPT` | GitLab | shell script | Runs `GITLAB_SETUP_RB` once, then marks GitLab ready for the healthcheck (`/-/railway-ready`) |
| `PORT` | GitLab | `80` | nginx port behind Railway's HTTPS |
| `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` | GitLab | `120` | Time for GitLab to stop cleanly on redeploy |
| `GITLAB_URL` | GitLab Runner | `http://${{GitLab.RAILWAY_PRIVATE_DOMAIN}}` | Runner talks to GitLab and clones over the private network |
| `GITLAB_RUNNER_BOOTSTRAP_PAT` | GitLab Runner | `${{GitLab.GITLAB_RUNNER_BOOTSTRAP_PAT}}` | See above |
| `RUNNER_START_SH` | GitLab Runner | shell script | Registers the runner if `config.toml` has none, then starts it |

## The runner

The shell executor runs jobs inside the runner container as the `gitlab-runner` user. The image is Ubuntu 24.04 with `git`, `bash` and `curl`; there is no Docker, so `image:` in `.gitlab-ci.yml` is ignored and the user can't install packages with `apt`. It suits scripts, deploy hooks, linting and calling APIs. For container builds, add your own runner with the Docker executor on a machine that allows it, and delete the `GitLab Runner` service if you don't need it.

The runner takes one job at a time. To allow more, set `concurrent` in `/etc/gitlab-runner/config.toml` on its volume, or register more runners.

**Re-register the runner** (for example after deleting it in GitLab): the bootstrap token expires 30 days after the first deploy. Create a runner under **Admin → CI/CD → Runners → New instance runner**, then either register it by hand or create a new personal access token with the `create_runner` scope, put it in the runner's `GITLAB_RUNNER_BOOTSTRAP_PAT`, delete `config.toml` from the runner volume and redeploy the runner.

## Custom domain

Add the domain to the GitLab service, set `GITLAB_HOST` to it and redeploy. GitLab reconfigures itself on start.

## Upgrading

Change the GitLab image tag (for example `gitlab/gitlab-ce:19.6.0-ce.0`) and redeploy; GitLab migrates the database on start. Follow GitLab's [upgrade path](https://gitlab-com.gitlab.io/support/toolbox/upgrade-path/): don't skip required stops between major versions. Back up first (`gitlab-backup create` from a shell in the service). Keep the runner within one minor version of GitLab.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Deploy stays "deploying" for minutes | Normal on the first start: GitLab configures itself and migrates the database. Logs show `railway-setup: GitLab is ready` when done |
| Healthcheck fails and logs show `railway-setup: FAILED` | The first-start step didn't finish. Sign-up may still be on; check the logs above that line, then redeploy |
| Out-of-memory restarts | GitLab needs about 3 GB idle and more under load. Raise the service's memory limit; don't add Puma workers without more memory |
| `git clone` over SSH times out | Use the host and port from the clone URL (the TCP proxy), not the web domain. Some networks block outbound connections to the proxy's port; use HTTPS then |
| SSH warns that the host key changed | The volume was replaced. Remove the old entry from `known_hosts` |
| Runner offline | Check the GitLab Runner logs. `runner-setup: waiting for GitLab` means GitLab isn't up yet; a 401 means the bootstrap token expired (see Re-register the runner) |
| Pipelines stay pending | No online runner matches the job's tags. The runner takes tagged jobs only for `RUNNER_TAGS`, plus untagged jobs |
| A job fails with "command not found" | The shell executor runs in the runner container, which has `git`, `bash` and `curl` only; `image:` and `services:` are ignored |
| HTTPS git asks for a password and refuses it | Accounts with 2FA need a personal access token as the password |

## Testing

Tested on 2026-11-05 with GitLab CE 19.5.3 and GitLab Runner 19.5.2 in a throwaway Railway project. GitLab became healthy in about 4 minutes; the first-start step disabled sign-up and the runner registered itself. The sign-up page redirected to sign-in, the API refused requests without a token, and root logged in with the generated password. Railway's edge served nothing until the healthcheck passed; GitLab's first response was the sign-up page redirecting to sign-in. A project was cloned and pushed over HTTPS with the password, and over SSH through the TCP proxy from a host on the internet (`Welcome to GitLab, @root!`, clone and push); one client network blocked the proxy port. Pipelines ran on the shell runner. After a redeploy of GitLab, the root password, an access token, an encrypted CI variable and the SSH host key all still worked or were unchanged, and the runner stayed online; after a redeploy of the runner it reused its registration. Idle memory was about 3.1 GB for GitLab and 0.1 GB for the runner.
