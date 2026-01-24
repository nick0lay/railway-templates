#!/bin/bash
set -e

# Single volume mount point
DATA_DIR="/data"

echo "=== Stirling-PDF Volume Setup ==="

# Create subdirectories in the single volume
mkdir -p "$DATA_DIR/configs" "$DATA_DIR/pipeline" "$DATA_DIR/logs" "$DATA_DIR/tessdata"

# Create symlinks for expected paths (not tessdata - handled by TESSDATA_PREFIX)
rm -rf /configs /pipeline /logs
ln -sf "$DATA_DIR/configs" /configs
ln -sf "$DATA_DIR/pipeline" /pipeline
ln -sf "$DATA_DIR/logs" /logs

# Copy default tessdata files to volume if empty
if [ -z "$(ls -A $DATA_DIR/tessdata 2>/dev/null)" ]; then
    echo "Initializing tessdata from defaults..."
    if [ -d "/opt/tessdata-default" ] && [ "$(ls -A /opt/tessdata-default 2>/dev/null)" ]; then
        cp -r /opt/tessdata-default/* "$DATA_DIR/tessdata/"
        echo "Copied default tessdata files"
    fi
fi

# Ensure tessdata is fully writable (777 for Java Files.isWritable() compatibility)
chmod 777 "$DATA_DIR/tessdata"
chmod 666 "$DATA_DIR/tessdata"/*.traineddata 2>/dev/null || true

# Verification
echo "Configuration:"
echo "  TESSDATA_PREFIX=$TESSDATA_PREFIX"
echo "  Contents: $(ls $DATA_DIR/tessdata 2>/dev/null | wc -l) files"
echo "  Permissions: $(stat -c '%a' $DATA_DIR/tessdata 2>/dev/null || stat -f '%Lp' $DATA_DIR/tessdata 2>/dev/null)"
echo ""

# Execute the original entrypoint or command
exec "$@"
