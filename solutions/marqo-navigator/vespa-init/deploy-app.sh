#!/bin/sh
# Brings the Vespa application package to the state this template needs, on
# every deploy, whatever state it starts in.
#
# Three cases:
#
#   no application yet   deploy the package in app/ and wait for convergence
#   ours, already right  nothing to do
#   ours, missing the    clone the ACTIVE session, patch services.xml, activate
#   JVM cap              (see "Repairing an existing cluster" below)
#
# The last case is why this is not a plain "run once" job. Marqo rewrites the
# application package on its first start — adding its marqo-custom-searchers
# bundle and index schemas — so redeploying our base package over it fails: the
# live services.xml would reference a bundle our package no longer carries.
# Cloning the active session instead keeps everything Marqo added and changes
# only the one element we care about.
set -e

CONFIG_URL="${VESPA_CONFIG_URL:-http://vespa-admin:19071}"
QUERY_URL="${VESPA_QUERY_URL:-http://vespa-node:8080}"
TENANT="$CONFIG_URL/application/v2/tenant/default"
APP="$TENANT/application/default/environment/prod/region/default/instance/default"

# How many cores each JVM should size its thread pools for. Railway hosts report
# 48, which puts the query container at 957 threads against a 1000-PID ceiling.
CPU_MODEL="${VESPA_JVM_PROCESSOR_COUNT:-4}"
JVM_OPT="-XX:ActiveProcessorCount=$CPU_MODEL"

echo "[vespa-init] config server: $CONFIG_URL"

wait_for() { # url, label, attempts
    i=0
    while [ "$i" -lt "$3" ]; do
        curl -sf -o /dev/null "$1" 2>/dev/null && return 0
        i=$((i + 1)); sleep 5
    done
    echo "[vespa-init] timed out waiting for $2" >&2
    return 1
}

wait_for "$CONFIG_URL/state/v1/health" "config server" 120 || exit 1

# --------------------------------------------------------------------------
# Case 1: nothing deployed yet — lay down our package.
# --------------------------------------------------------------------------
if ! curl -s "$APP" | grep -q '"generation"'; then
    echo "[vespa-init] no application found — deploying package"
    cd /tmp && rm -rf appdir && cp -r /app appdir

    # hosts.xml must name the nodes exactly as they report themselves, and those
    # names differ per platform (bare service names under compose,
    # <service>.railway.internal on Railway).
    ADMIN_HOST="${VESPA_ADMIN_HOST:-vespa-admin}"
    NODE_HOST="${VESPA_NODE_HOST:-vespa-node}"
    echo "[vespa-init] admin host: $ADMIN_HOST | node host: $NODE_HOST"
    sed -i "s|__ADMIN_HOST__|$ADMIN_HOST|g; s|__NODE_HOST__|$NODE_HOST|g" appdir/hosts.xml
    sed -i "s|__JVM_OPTIONS__|$JVM_OPT|g" appdir/services.xml

    tar czf /tmp/app.tgz -C /tmp/appdir .
    curl -sf --header "Content-Type: application/x-gzip" --data-binary @/tmp/app.tgz \
        "$TENANT/prepareandactivate" >/dev/null
    echo "[vespa-init] deployed"

    i=0
    while [ "$i" -lt 120 ]; do
        curl -s "$APP/serviceconverge" | grep -q '"converged":true' && break
        i=$((i + 1)); sleep 5
    done
    echo "[vespa-init] converged"
    wait_for "$QUERY_URL/state/v1/health" "query container" 120 || exit 1
    echo "[vespa-init] cluster ready"
    exit 0
fi

# --------------------------------------------------------------------------
# Case 2/3: an application exists. Repair it if it predates the JVM cap.
# --------------------------------------------------------------------------
if curl -s "$APP/content/services.xml" | grep -q "ActiveProcessorCount"; then
    echo "[vespa-init] application already deployed and tuned — nothing to do"
    exit 0
fi

echo "[vespa-init] application deployed but missing the JVM cap — repairing"

SESSION=$(curl -s -X POST "$TENANT/session?from=$APP" \
    | sed -n 's/.*session-id[^0-9]*\([0-9][0-9]*\).*/\1/p')
if [ -z "$SESSION" ]; then
    echo "[vespa-init] could not create a session from the active application" >&2
    exit 1
fi
echo "[vespa-init] cloned active application into session $SESSION"

curl -s "$APP/content/services.xml" > /tmp/services.xml
# Insert the JVM options before the first <node hostalias=...>, which is the
# container cluster — the content cluster's node comes later and carries a
# distribution-key. awk rather than sed: the natural sed form uses the 0,/re/
# address range, which is a GNU extension that BusyBox sed (this image) lacks,
# and it fails silently by simply not matching.
awk -v jvm="            <jvm options=\"$JVM_OPT\"/>" \
    'inserted != 1 && /<node hostalias=/ { print jvm; inserted = 1 } { print }' \
    /tmp/services.xml > /tmp/services.patched.xml
mv /tmp/services.patched.xml /tmp/services.xml

if ! grep -q "ActiveProcessorCount" /tmp/services.xml; then
    echo "[vespa-init] could not patch services.xml; leaving the cluster untouched" >&2
    exit 1
fi

S="$TENANT/session/$SESSION"
curl -sf -X PUT --data-binary @/tmp/services.xml -H "Content-Type: application/xml" \
    "$S/content/services.xml" >/dev/null
curl -sf -X PUT "$S/prepared" >/dev/null
if curl -s -X PUT "$S/active" | grep -q '"activated"\|activated'; then
    echo "[vespa-init] repaired — the query container JVM will restart with the cap"
else
    echo "[vespa-init] activation did not confirm; check the config server" >&2
    exit 1
fi
