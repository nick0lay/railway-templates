#!/bin/bash
set -e

# Single volume mount point
DATA_DIR="/data"

# Create subdirectories in the single volume
mkdir -p "$DATA_DIR/configs"
mkdir -p "$DATA_DIR/pipeline"
mkdir -p "$DATA_DIR/logs"
mkdir -p "$DATA_DIR/tessdata"

# Ensure directories are writable
chmod -R 777 "$DATA_DIR"

# Remove existing directories/symlinks if they exist
rm -rf /configs /pipeline /logs

# Create symlinks from expected paths to volume subdirectories
ln -sf "$DATA_DIR/configs" /configs
ln -sf "$DATA_DIR/pipeline" /pipeline
ln -sf "$DATA_DIR/logs" /logs

# Copy default tessdata files to volume if empty (from backup location)
if [ -z "$(ls -A $DATA_DIR/tessdata 2>/dev/null)" ]; then
    echo "Initializing tessdata from defaults..."
    if [ -d "/opt/tessdata-default" ] && [ "$(ls -A /opt/tessdata-default 2>/dev/null)" ]; then
        cp -r /opt/tessdata-default/* "$DATA_DIR/tessdata/"
        echo "Copied default tessdata files"
    fi
fi

echo "Volume configuration complete:"
echo "  /configs -> $DATA_DIR/configs"
echo "  /pipeline -> $DATA_DIR/pipeline"
echo "  /logs -> $DATA_DIR/logs"
echo "  /usr/share/tesseract-ocr/5/tessdata -> $DATA_DIR/tessdata (symlink from Dockerfile)"
echo "  tessdata files: $(ls $DATA_DIR/tessdata 2>/dev/null | wc -l) files"

# Execute the original entrypoint or command
exec "$@"
