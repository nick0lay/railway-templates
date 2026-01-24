#!/bin/bash
set -e

DATA_DIR="/data"

# Create subdirectories in the single volume
mkdir -p "$DATA_DIR/configs" "$DATA_DIR/pipeline" "$DATA_DIR/logs" "$DATA_DIR/tessdata"

# Set ownership to stirlingpdfuser so Java app can write
# (init.sh may change permissions to 755, but owner still has write access)
chown -R stirlingpdfuser:stirlingpdfgroup "$DATA_DIR/configs" "$DATA_DIR/pipeline" "$DATA_DIR/logs" "$DATA_DIR/tessdata"

# If working directory is not /, create symlinks there for relative paths
WORKDIR="$(pwd)"
if [ "$WORKDIR" != "/" ]; then
    rm -rf "$WORKDIR/configs" "$WORKDIR/pipeline" "$WORKDIR/logs" 2>/dev/null || true
    ln -sf "$DATA_DIR/configs" "$WORKDIR/configs"
    ln -sf "$DATA_DIR/pipeline" "$WORKDIR/pipeline"
    ln -sf "$DATA_DIR/logs" "$WORKDIR/logs"
fi

# Create symlinks for expected paths (matching official split deployment volumes)
rm -rf /configs /pipeline /logs /usr/share/tessdata
ln -sf "$DATA_DIR/configs" /configs
ln -sf "$DATA_DIR/pipeline" /pipeline
ln -sf "$DATA_DIR/logs" /logs
ln -sf "$DATA_DIR/tessdata" /usr/share/tessdata

# Copy default tessdata files to volume if empty
if [ -z "$(ls -A $DATA_DIR/tessdata 2>/dev/null)" ]; then
    if [ -d "/opt/tessdata-default" ] && [ "$(ls -A /opt/tessdata-default 2>/dev/null)" ]; then
        cp -r /opt/tessdata-default/* "$DATA_DIR/tessdata/"
    fi
fi

exec "$@"
