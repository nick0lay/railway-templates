#!/bin/bash
set -e

# Single volume mount point
DATA_DIR="/data"

# Create subdirectories in the single volume with full permissions
mkdir -p "$DATA_DIR/configs"
mkdir -p "$DATA_DIR/pipeline"
mkdir -p "$DATA_DIR/logs"
mkdir -p "$DATA_DIR/tessdata"

# Ensure tessdata is writable
chmod 777 "$DATA_DIR/tessdata"

# Remove existing directories/symlinks if they exist
rm -rf /configs /pipeline /logs

# Create symlinks from expected paths to volume subdirectories
ln -sf "$DATA_DIR/configs" /configs
ln -sf "$DATA_DIR/pipeline" /pipeline
ln -sf "$DATA_DIR/logs" /logs

# Handle tessdata - symlink both possible paths to our writable volume
# Path 1: /usr/share/tesseract-ocr/5/tessdata (newer Tesseract)
TESSDATA_PATH_1="/usr/share/tesseract-ocr/5/tessdata"
# Path 2: /usr/share/tessdata (legacy/alternate path)
TESSDATA_PATH_2="/usr/share/tessdata"

# Copy default tessdata files if volume is empty
if [ -z "$(ls -A $DATA_DIR/tessdata 2>/dev/null)" ]; then
    if [ -d "$TESSDATA_PATH_1" ] && [ "$(ls -A $TESSDATA_PATH_1 2>/dev/null)" ]; then
        cp -r "$TESSDATA_PATH_1"/* "$DATA_DIR/tessdata/" 2>/dev/null || true
    elif [ -d "$TESSDATA_PATH_2" ] && [ "$(ls -A $TESSDATA_PATH_2 2>/dev/null)" ]; then
        cp -r "$TESSDATA_PATH_2"/* "$DATA_DIR/tessdata/" 2>/dev/null || true
    fi
fi

# Remove and symlink tessdata paths
rm -rf "$TESSDATA_PATH_1" "$TESSDATA_PATH_2"
mkdir -p "$(dirname $TESSDATA_PATH_1)"
ln -sf "$DATA_DIR/tessdata" "$TESSDATA_PATH_1"
ln -sf "$DATA_DIR/tessdata" "$TESSDATA_PATH_2"

# Set TESSDATA_PREFIX environment variable for Tesseract
export TESSDATA_PREFIX="$DATA_DIR"

echo "Volume symlinks configured:"
echo "  /configs -> $DATA_DIR/configs"
echo "  /pipeline -> $DATA_DIR/pipeline"
echo "  /logs -> $DATA_DIR/logs"
echo "  $TESSDATA_PATH_1 -> $DATA_DIR/tessdata"
echo "  $TESSDATA_PATH_2 -> $DATA_DIR/tessdata"
echo "  TESSDATA_PREFIX=$TESSDATA_PREFIX"

# Execute the original entrypoint or command
exec "$@"
