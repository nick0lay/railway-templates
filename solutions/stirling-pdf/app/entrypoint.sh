#!/bin/bash
set -e

DATA_DIR="/data"

echo "=== Stirling-PDF Volume Setup ==="
echo "Running as user: $(id)"
echo "Volume owner: $(ls -la /data 2>/dev/null | head -2 || echo 'not mounted')"

# Create subdirectories in the single volume with write permissions
# Railway mounts volumes as root, but app runs as non-root user
mkdir -p "$DATA_DIR/configs" "$DATA_DIR/pipeline" "$DATA_DIR/logs" "$DATA_DIR/tessdata"

# Set permissions - must work even if not running as root
chmod 777 "$DATA_DIR/configs" "$DATA_DIR/pipeline" "$DATA_DIR/logs" "$DATA_DIR/tessdata" || true
chmod 777 "$DATA_DIR" || true

echo "Directory permissions after chmod:"
ls -la "$DATA_DIR"

echo "Symlink verification:"
ls -la /configs /logs /pipeline 2>/dev/null || echo "Symlinks not created yet"

echo "Current working directory: $(pwd)"
echo "Relative path ./logs resolves to: $(readlink -f ./logs 2>/dev/null || echo 'does not exist')"

# If working directory is not /, also create symlinks there for relative paths
WORKDIR="$(pwd)"
if [ "$WORKDIR" != "/" ]; then
    echo "Creating symlinks in working directory $WORKDIR"
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
    echo "Initializing tessdata from defaults..."
    if [ -d "/opt/tessdata-default" ] && [ "$(ls -A /opt/tessdata-default 2>/dev/null)" ]; then
        cp -r /opt/tessdata-default/* "$DATA_DIR/tessdata/"
        echo "Copied default tessdata files"
    fi
fi

echo "Ready: $(ls $DATA_DIR/tessdata 2>/dev/null | wc -l) tessdata files"

exec "$@"
