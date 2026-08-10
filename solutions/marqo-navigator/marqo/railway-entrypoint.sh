#!/bin/bash
# Wait for the vector store before starting Marqo.
#
# Railway starts every service at once and has no dependency ordering, so on a
# cold deploy Marqo comes up before the Vespa cluster exists, fails bootstrap
# with VespaNotConvergedError, exits 1, and sits in CRASHED until one of
# Railway's restarts happens to land after the cluster converged. It gets there
# eventually, but it looks like a broken deploy for several minutes.
#
# Waiting on the dependency rather than a fixed sleep matters in both
# directions: when the cluster is already up — every redeploy after the first —
# the first probe succeeds and nothing is wasted, and when a cold cluster takes
# longer than expected it gets as long as it needs. A fixed delay would have to
# guess, and would be wrong either way.
#
# If the wait times out we start Marqo anyway rather than exiting here: its own
# error is more informative than ours, and Railway will restart it.
set -e

if [ -n "$VESPA_QUERY_URL" ]; then
    ATTEMPTS="${VESPA_WAIT_ATTEMPTS:-90}"   # 90 x 10s = 15 minutes
    echo "[marqo-entrypoint] waiting for vector store at $VESPA_QUERY_URL"

    i=0
    while [ "$i" -lt "$ATTEMPTS" ]; do
        if curl -sf -o /dev/null "$VESPA_QUERY_URL/state/v1/health" 2>/dev/null; then
            echo "[marqo-entrypoint] vector store ready after $((i * 10))s"
            break
        fi
        i=$((i + 1))
        # Only log occasionally; this can run for minutes on a first deploy.
        [ $((i % 6)) -eq 0 ] && echo "[marqo-entrypoint] still waiting ($((i * 10))s elapsed)"
        sleep 10
    done

    if [ "$i" -ge "$ATTEMPTS" ]; then
        echo "[marqo-entrypoint] vector store did not become ready; starting anyway" >&2
    fi
fi

exec ./run_marqo.sh
