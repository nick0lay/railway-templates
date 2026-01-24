#!/bin/bash
set -e

DATA_DIR="/data"

echo "=== Stirling-PDF Volume Setup ==="

# Create subdirectories in the single volume with write permissions
# Railway mounts volumes as root, but app runs as non-root user
mkdir -p "$DATA_DIR/configs" "$DATA_DIR/pipeline" "$DATA_DIR/logs" "$DATA_DIR/tessdata"
chmod 777 "$DATA_DIR/configs" "$DATA_DIR/pipeline" "$DATA_DIR/logs" "$DATA_DIR/tessdata"

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
