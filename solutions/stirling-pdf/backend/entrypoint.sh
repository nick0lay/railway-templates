#!/bin/bash
set -e

# Single volume mount point
DATA_DIR="/data"

echo "=== Stirling-PDF Volume Setup ==="

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

# CRITICAL: Recreate tessdata symlink at runtime (after volume is mounted)
# This ensures the system tessdata path points to our writable volume
TESSDATA_SYSTEM_PATH="/usr/share/tesseract-ocr/5/tessdata"
echo "Setting up tessdata symlink..."
rm -rf "$TESSDATA_SYSTEM_PATH"
mkdir -p "$(dirname $TESSDATA_SYSTEM_PATH)"
ln -sf "$DATA_DIR/tessdata" "$TESSDATA_SYSTEM_PATH"

# Verify symlink is working
echo "Verifying tessdata symlink..."
if [ -L "$TESSDATA_SYSTEM_PATH" ]; then
    LINK_TARGET=$(readlink -f "$TESSDATA_SYSTEM_PATH")
    echo "  Symlink: $TESSDATA_SYSTEM_PATH -> $LINK_TARGET"
    if [ -w "$TESSDATA_SYSTEM_PATH" ]; then
        echo "  Writable: YES"
    else
        echo "  Writable: NO - attempting fix..."
        chmod 777 "$DATA_DIR/tessdata"
    fi
else
    echo "  ERROR: Symlink not created!"
fi

# Test write to tessdata directory
TEST_FILE="$DATA_DIR/tessdata/.write_test"
if touch "$TEST_FILE" 2>/dev/null; then
    rm -f "$TEST_FILE"
    echo "  Write test: PASSED"
else
    echo "  Write test: FAILED"
fi

echo ""
echo "Volume configuration complete:"
echo "  /configs -> $DATA_DIR/configs"
echo "  /pipeline -> $DATA_DIR/pipeline"
echo "  /logs -> $DATA_DIR/logs"
echo "  $TESSDATA_SYSTEM_PATH -> $DATA_DIR/tessdata"
echo "  tessdata files: $(ls $DATA_DIR/tessdata 2>/dev/null | wc -l) files"
ls -la "$TESSDATA_SYSTEM_PATH" 2>/dev/null | head -3
echo ""

# Execute the original entrypoint or command
exec "$@"
