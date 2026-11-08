# Deploy and Host GitLab CE + Runner on Railway

GitLab Community Edition is an open-source alternative to GitHub: Git repositories, merge requests, code review, issues, wikis, CI/CD pipelines and a full REST and GraphQL API, on your own infrastructure. This template runs GitLab with a self-registering GitLab Runner.

## About Hosting GitLab CE + Runner

GitLab ships as one large Omnibus image that runs nginx, Rails (Puma), Sidekiq, Gitaly, PostgreSQL, Redis and sshd together. Its documented requirements start at 8 GB of memory even when tuned (16 GB by default). It keeps its encryption keys in `/etc/gitlab` apart from its data, opens sign-up to anyone on a fresh install, and needs a runner registered by hand before CI works.

This template tunes GitLab to about 3 GB idle, keeps its secrets on the same volume as its data, turns sign-up off before the deploy goes healthy, registers a runner automatically, and exposes Git over SSH through a Railway TCP proxy.

## Common Use Cases

- Private Git hosting for a team or a side project, with merge requests and code review
- Issue tracking, boards and wikis next to the code
- CI/CD pipelines for scripts, tests, linting and deploy hooks
- A mirror of GitHub repositories you want to keep under your control
- A GitLab API backend for your own tooling

## Dependencies for GitLab CE + Runner Hosting

- GitLab CE 19.5 (bundled PostgreSQL, Redis and Gitaly)
- GitLab Runner 19.5 (shell executor)

### Deployment Dependencies

- GitLab: https://gitlab.com/gitlab-org/gitlab
- Docker install docs: https://docs.gitlab.com/install/docker/
- Memory-constrained setup: https://docs.gitlab.com/omnibus/settings/memory_constrained_envs/
- GitLab Runner: https://docs.gitlab.com/runner/

### Implementation Details

**What you set:** nothing. The root password is generated.

**After deploy:**

1. Wait about 4 minutes for the first start.
2. Open the GitLab URL and log in as `root` with the `GITLAB_ROOT_PASSWORD` variable.
3. Change the root email and turn on two-factor authentication.
4. Add users under Admin → Users (sign-up is off), and your SSH key under Edit profile → SSH Keys.
5. Push a `.gitlab-ci.yml`: the `railway-shell` runner picks up the job.

**This template:**

- Generates the root password and turns sign-up off on the first start; the healthcheck passes only after that
- Keeps `/etc/gitlab` (`gitlab-secrets.json`, `gitlab.rb`, SSH host keys) on the data volume, so secrets and host keys survive redeploys
- Tunes memory: Puma single mode, 10 Sidekiq threads, bundled Prometheus, exporters and KAS off, PostgreSQL `shared_buffers` 256 MB
- Registers an instance runner with the shell executor over the private network, using a short-lived token limited to creating runners
- Git over HTTPS on the Railway domain, and over SSH through a TCP proxy with matching clone URLs
- Pins GitLab CE 19.5.3 and GitLab Runner 19.5.2

**Notes:** GitLab uses about 3 GB of memory idle and more under load. The runner has no Docker: `image:` in CI jobs is ignored. Delete the runner service if you don't need CI. Set `GITLAB_HOST` when you add a custom domain. Upgrade by changing the image tag, following GitLab's upgrade path.

## Why Deploy GitLab CE + Runner on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying GitLab CE + Runner on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
