#!/bin/bash
# Railway wrapper around the StarRocks allin1 entrypoint.
#
# Adapts the official image to Railway: a single mounted volume, a dynamic
# $PORT for the public HTTP surface, and a root password taken from the
# Railway-generated STARROCKS_PASSWORD variable.
set -e

SR_HOME="${SR_HOME:-/data/deploy/starrocks}"
DATA_DIR="${STARROCKS_DATA_DIR:-/var/lib/starrocks}"
PASSWORD_MARKER="$DATA_DIR/.root_password_set"
SUPERVISORD_CONF="$SR_HOME/supervisor/supervisord.conf"
FE_QUERY_PORT=9030

log() { echo "$(date --rfc-3339=seconds) [railway] $*" >&2; }

# 1. Point FE metadata and BE storage at the Railway volume.
#    Railway mounts a single, empty volume, so the image's install directory
#    cannot itself be the mount point — symlink the two stateful directories
#    into the volume instead. Upstream's entrypoint.sh and director/run.sh read
#    $SR_HOME/fe/meta/image/{VERSION,ROLE} by literal path, so those paths must
#    keep working; repointing meta_dir/storage_root_path would break them.
mkdir -p "$DATA_DIR/fe-meta" "$DATA_DIR/be-storage"
rm -rf "$SR_HOME/fe/meta" "$SR_HOME/be/storage"
ln -sfT "$DATA_DIR/fe-meta" "$SR_HOME/fe/meta"
ln -sfT "$DATA_DIR/be-storage" "$SR_HOME/be/storage"
log "FE meta -> $DATA_DIR/fe-meta, BE storage -> $DATA_DIR/be-storage"

# 2. Bind the bundled nginx proxy to Railway's dynamic port. The image
#    regenerates feproxy.conf from this template on every boot, so patching the
#    template is what sticks. The substitution matches any port number, which
#    keeps it safe to re-run against an already-patched file.
sed -i -E "s/^([[:space:]]*)listen[[:space:]]+[0-9]+;/\1listen ${PORT:-8080};/" \
    "$SR_HOME/feproxy/feproxy.conf.template"
log "feproxy will listen on ${PORT:-8080}"

# 3. Cap BE memory. Left alone, the BE sizes itself from memory it may not
#    actually be allowed to use, and gets OOM-killed into a restart loop.
if ! grep -Eq '^[[:space:]]*mem_limit[[:space:]]*=' "$SR_HOME/be/conf/be.conf"; then
    echo "mem_limit = ${STARROCKS_BE_MEM_LIMIT:-80%}" >> "$SR_HOME/be/conf/be.conf"
    log "BE mem_limit set to ${STARROCKS_BE_MEM_LIMIT:-80%}"
fi

# 4. Root password. StarRocks always boots with a passwordless root account, so
#    the Railway-generated password has to be applied over SQL once.
if [ -z "$STARROCKS_PASSWORD" ]; then
    log "WARNING: STARROCKS_PASSWORD is empty — the root account will accept"
    log "WARNING: connections with no password. Set it and redeploy before"
    log "WARNING: exposing this service."
elif [ -f "$PASSWORD_MARKER" ]; then
    # Applied on an earlier boot. The image's own bootstrap client reads
    # MYSQL_PWD, so it needs the password to authenticate.
    export MYSQL_PWD="$STARROCKS_PASSWORD"
    log "root password already applied; MYSQL_PWD exported for the bootstrap client"
else
    # First boot. Two constraints pull against each other: the image's director
    # registers the BE over a passwordless connection and dies if that fails
    # with 1045, so the password cannot be set until it is finished — yet until
    # the password exists, the FE web UI accepts root with an empty one.
    #
    # So hold the public HTTP surface down until the password is in place:
    # disable feproxy's autostart here and start it from the job below. Railway
    # simply sees the service as not yet healthy while that happens.
    awk '/^\[program:feproxy\]/ { in_feproxy = 1 }
         in_feproxy && /^autostart[[:space:]]*=/ { sub(/=.*/, "=false"); in_feproxy = 0 }
         { print }' "$SUPERVISORD_CONF" > "$SUPERVISORD_CONF.railway" \
        && mv "$SUPERVISORD_CONF.railway" "$SUPERVISORD_CONF"
    log "public HTTP deferred until the root password is applied"

    (
        # MYSQL_PWD stays unset in here: sending a password to an account that
        # has none is itself a 1045. bootstrap_done is touched by director
        # after its last SQL statement.
        while [ ! -f "$SR_HOME/bootstrap_done" ]; do sleep 2; done

        escaped=${STARROCKS_PASSWORD//\\/\\\\}
        escaped=${escaped//\'/\\\'}
        applied=0
        for _ in $(seq 1 30); do
            # Piped rather than passed with -e: argv is world-readable in /proc.
            if printf "SET PASSWORD FOR 'root'@'%%' = PASSWORD('%s');\n" "$escaped" \
                    | mysql -h 127.0.0.1 -P "$FE_QUERY_PORT" -u root --batch; then
                applied=1
                break
            fi
            sleep 2
        done

        if [ "$applied" = "1" ]; then
            touch "$PASSWORD_MARKER"
            log "root password applied"
            supervisorctl start feproxy >/dev/null 2>&1 \
                && log "public HTTP enabled" \
                || log "ERROR: could not start feproxy; check supervisor logs"
            exit 0
        fi

        # Fail closed. Staying up would leave a passwordless root reachable over
        # the MySQL port; exiting makes Railway restart and try again, and the
        # failure is visible in the deploy logs.
        log "ERROR: could not set the root password after 30 attempts; stopping"
        kill 1
    ) &
fi

# 5. Hand over to the image's own entrypoint (WORKDIR is /data/deploy).
exec ./entrypoint.sh
