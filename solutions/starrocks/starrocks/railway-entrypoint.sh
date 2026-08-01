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
if [ -n "$STARROCKS_PASSWORD" ]; then
    if [ -f "$PASSWORD_MARKER" ]; then
        # Already applied on an earlier boot. The image's own bootstrap client
        # reads MYSQL_PWD, so it needs the password to authenticate.
        export MYSQL_PWD="$STARROCKS_PASSWORD"
        log "root password already applied; MYSQL_PWD exported for the bootstrap client"
    else
        # First boot: MYSQL_PWD must stay unset, because sending a password to
        # an account that has none fails with error 1045 and the image's
        # director treats that as fatal. Wait for bootstrap_done — director
        # touches it after its last SQL statement — then set the password.
        (
            set +e
            while [ ! -f "$SR_HOME/bootstrap_done" ]; do sleep 2; done
            escaped=${STARROCKS_PASSWORD//\\/\\\\}
            escaped=${escaped//\'/\\\'}
            for _ in $(seq 1 30); do
                if mysql -h 127.0.0.1 -P "$FE_QUERY_PORT" -u root --batch \
                        -e "SET PASSWORD FOR 'root'@'%' = PASSWORD('$escaped');"; then
                    touch "$PASSWORD_MARKER"
                    log "root password applied"
                    exit 0
                fi
                sleep 2
            done
            log "ERROR: could not set the root password; root is still passwordless"
        ) &
    fi
else
    log "STARROCKS_PASSWORD is empty; leaving the root account passwordless"
fi

# 5. Hand over to the image's own entrypoint (WORKDIR is /data/deploy).
exec ./entrypoint.sh
