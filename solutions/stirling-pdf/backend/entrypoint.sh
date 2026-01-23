#!/bin/bash
set -e

# Single volume mount point
DATA_DIR="/data"

# Tesseract OCR data path (actual path used by Stirling-PDF)
TESSDATA_SYSTEM_PATH="/usr/share/tesseract-ocr/5/tessdata"

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

# Tessdata - copy defaults if volume is empty, then symlink
if [ -z "$(ls -A $DATA_DIR/tessdata 2>/dev/null)" ]; then
    # Copy default tessdata files if they exist
    if [ -d "$TESSDATA_SYSTEM_PATH" ] && [ "$(ls -A $TESSDATA_SYSTEM_PATH 2>/dev/null)" ]; then
        cp -r "$TESSDATA_SYSTEM_PATH"/* "$DATA_DIR/tessdata/" 2>/dev/null || true
    fi
fi

# Remove existing tessdata and create symlink
rm -rf "$TESSDATA_SYSTEM_PATH"
mkdir -p "$(dirname $TESSDATA_SYSTEM_PATH)"
ln -sf "$DATA_DIR/tessdata" "$TESSDATA_SYSTEM_PATH"

echo "Volume symlinks configured:"
echo "  /configs -> $DATA_DIR/configs"
echo "  /pipeline -> $DATA_DIR/pipeline"
echo "  /logs -> $DATA_DIR/logs"
echo "  $TESSDATA_SYSTEM_PATH -> $DATA_DIR/tessdata"

# Execute the original entrypoint or command
exec "$@"
