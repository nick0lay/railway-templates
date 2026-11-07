#!/bin/sh
# Railway start wrapper around upstream's scripts/docker-start.sh.
# The worker waits until the API is healthy: the API runs the database migrations
# on start, and a worker that starts first would fail on missing tables.
set -e
if [ "${TRACELY_ROLE:-api}" = "worker" ] && [ -n "${INTERNAL_API_URL:-}" ]; then
  echo "waiting for ${INTERNAL_API_URL}/health"
  python - <<'PY'
import os, sys, time, urllib.request
url = os.environ["INTERNAL_API_URL"].rstrip("/") + "/health"
deadline = time.time() + int(os.environ.get("WAIT_FOR_API_SECONDS", "900"))
while time.time() < deadline:
    try:
        if urllib.request.urlopen(url, timeout=5).status == 200:
            print("API is up"); sys.exit(0)
    except Exception:
        pass
    time.sleep(5)
print("API not healthy in time; starting the worker anyway")
PY
fi
exec sh /app/scripts/docker-start.sh
