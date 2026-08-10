#!/bin/sh
# Deploys the Vespa application package, then waits for the cluster to converge.
#
# Runs exactly once per cluster. Marqo rewrites the application package on its
# first start (adding its marqo-custom-searchers bundle and index schemas), so
# redeploying our base package afterwards fails: the live services.xml would
# reference a bundle our package does not carry. The guard below makes every
# subsequent run a no-op, which is what makes this safe to leave attached to a
# platform that restarts services.
set -e

CONFIG_URL="${VESPA_CONFIG_URL:-http://vespa-admin:19071}"
QUERY_URL="${VESPA_QUERY_URL:-http://vespa-node:8080}"
APP="$CONFIG_URL/application/v2/tenant/default/application/default/environment/prod/region/default/instance/default"

echo "[vespa-init] config server: $CONFIG_URL"

# Wait for the config server to answer at all.
i=0
while [ "$i" -lt 120 ]; do
    curl -sf -o /dev/null "$CONFIG_URL/state/v1/health" && break
    i=$((i + 1)); sleep 5
done

# --- the guard -------------------------------------------------------------
if curl -s "$APP" | grep -q '"generation"'; then
    echo "[vespa-init] application already deployed - nothing to do"
    exit 0
fi

echo "[vespa-init] deploying application package..."
cd /tmp && rm -rf appdir && cp -r /app appdir

# hosts.xml must name the two Vespa nodes exactly as they report themselves.
# Those names differ per platform (bare service names under compose,
# <service>.railway.internal on Railway), so they are substituted here rather
# than baked into the package.
ADMIN_HOST="${VESPA_ADMIN_HOST:-vespa-admin}"
NODE_HOST="${VESPA_NODE_HOST:-vespa-node}"
echo "[vespa-init] admin host: $ADMIN_HOST | node host: $NODE_HOST"
sed -i "s|__ADMIN_HOST__|$ADMIN_HOST|g; s|__NODE_HOST__|$NODE_HOST|g" appdir/hosts.xml

tar czf /tmp/app.tgz -C /tmp/appdir .

curl -sf --header "Content-Type: application/x-gzip" --data-binary @/tmp/app.tgz \
    "$CONFIG_URL/application/v2/tenant/default/prepareandactivate" >/dev/null
echo "[vespa-init] deployed"

echo "[vespa-init] waiting for convergence..."
i=0
while [ "$i" -lt 120 ]; do
    curl -s "$APP/serviceconverge" | grep -q '"converged":true' && { echo "[vespa-init] converged"; break; }
    i=$((i + 1)); sleep 5
done

# Marqo refuses to start until the query container answers, so hold the
# dependency open until it does rather than handing it a half-built cluster.
echo "[vespa-init] waiting for query container..."
i=0
while [ "$i" -lt 120 ]; do
    if curl -sf -o /dev/null "$QUERY_URL/state/v1/health"; then
        echo "[vespa-init] cluster ready"
        exit 0
    fi
    i=$((i + 1)); sleep 5
done

echo "[vespa-init] timed out waiting for the query container" >&2
exit 1
