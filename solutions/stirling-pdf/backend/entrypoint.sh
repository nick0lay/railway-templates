#!/bin/bash
set -e

# Single volume mount point
DATA_DIR="/data"

# Create subdirectories in the single volume
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

# Copy default tessdata files to volume if empty (for OCR to work out of the box)
if [ -z "$(ls -A $DATA_DIR/tessdata 2>/dev/null)" ]; then
    echo "Copying default tessdata files to volume..."
    # Try multiple possible source locations
    for src in "/usr/share/tesseract-ocr/5/tessdata" "/usr/share/tessdata"; do
        if [ -d "$src" ] && [ "$(ls -A $src 2>/dev/null)" ]; then
            cp -r "$src"/* "$DATA_DIR/tessdata/" 2>/dev/null || true
            echo "Copied from $src"
            break
        fi
    done
fi

echo "Volume configuration:"
echo "  /configs -> $DATA_DIR/configs"
echo "  /pipeline -> $DATA_DIR/pipeline"
echo "  /logs -> $DATA_DIR/logs"
echo "  SYSTEM_TESSDATADIR -> $DATA_DIR/tessdata"
echo "  tessdata contents: $(ls $DATA_DIR/tessdata 2>/dev/null | head -5)..."

# Execute the original entrypoint or command
exec "$@"
