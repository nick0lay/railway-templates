#!/bin/sh
# Start script for both the Medusa server and the worker (same image).
# MEDUSA_WORKER_MODE=server|shared: migrate, bootstrap, create the admin user, start.
# MEDUSA_WORKER_MODE=worker: wait until the server is healthy (so migrations are done), start.
set -e
cd /app

if [ "$MEDUSA_WORKER_MODE" = "worker" ]; then
  if [ -n "$MEDUSA_SERVER_URL" ]; then
    echo "worker: waiting for $MEDUSA_SERVER_URL/health"
    node -e '
      const url = process.env.MEDUSA_SERVER_URL + "/health";
      const end = Date.now() + 30 * 60 * 1000;
      (async function wait() {
        try { const r = await fetch(url); if (r.ok) process.exit(0); } catch {}
        if (Date.now() > end) { console.error("worker: server not healthy after 30 min"); process.exit(1); }
        setTimeout(wait, 5000);
      })();'
  fi
  exec npx medusa start
fi

npx medusa db:migrate
npx medusa exec ./src/scripts/bootstrap.js

if [ -n "$MEDUSA_ADMIN_EMAIL" ] && [ -n "$MEDUSA_ADMIN_PASSWORD" ]; then
  if npx medusa user -e "$MEDUSA_ADMIN_EMAIL" -p "$MEDUSA_ADMIN_PASSWORD" >/tmp/admin-user.log 2>&1; then
    echo "admin user $MEDUSA_ADMIN_EMAIL created"
  else
    if grep -qi "already exists" /tmp/admin-user.log; then
      echo "admin user $MEDUSA_ADMIN_EMAIL already exists"
    else
      echo "admin user $MEDUSA_ADMIN_EMAIL could not be created:"; tail -n 20 /tmp/admin-user.log
    fi
  fi
fi

exec npx medusa start
