#!/bin/bash
set -e

# Single volume mount point
DATA_DIR="/data"

# Create subdirectories in the single volume
mkdir -p "$DATA_DIR/configs"
mkdir -p "$DATA_DIR/pipeline"
mkdir -p "$DATA_DIR/logs"
mkdir -p "$DATA_DIR/tessdata"

# Remove existing directories/symlinks if they exist
rm -rf /configs /pipeline /logs

# Create symlinks from expected paths to volume subdirectories
ln -sf "$DATA_DIR/configs" /configs
ln -sf "$DATA_DIR/pipeline" /pipeline
ln -sf "$DATA_DIR/logs" /logs

# Tessdata is special - copy defaults if volume is empty, then symlink
if [ -z "$(ls -A $DATA_DIR/tessdata 2>/dev/null)" ]; then
    # Copy default tessdata files if they exist
    if [ -d "/usr/share/tessdata" ] && [ "$(ls -A /usr/share/tessdata 2>/dev/null)" ]; then
        cp -r /usr/share/tessdata/* "$DATA_DIR/tessdata/" 2>/dev/null || true
    fi
fi
rm -rf /usr/share/tessdata
ln -sf "$DATA_DIR/tessdata" /usr/share/tessdata

echo "Volume symlinks configured:"
echo "  /configs -> $DATA_DIR/configs"
echo "  /pipeline -> $DATA_DIR/pipeline"
echo "  /logs -> $DATA_DIR/logs"
echo "  /usr/share/tessdata -> $DATA_DIR/tessdata"

# Execute the original entrypoint or command
exec "$@"
