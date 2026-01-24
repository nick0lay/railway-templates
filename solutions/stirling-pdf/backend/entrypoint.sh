#!/bin/bash
set -e

# Single volume mount point
DATA_DIR="/data"
TESSDATA_SYSTEM_PATH="/usr/share/tesseract-ocr/5/tessdata"

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

# CRITICAL: Use bind mount instead of symlink for tessdata
# This makes the system path directly point to the volume directory
echo "Setting up tessdata bind mount..."
mkdir -p "$TESSDATA_SYSTEM_PATH"

# Try bind mount first (requires privileges)
if mount --bind "$DATA_DIR/tessdata" "$TESSDATA_SYSTEM_PATH" 2>/dev/null; then
    echo "  Bind mount: SUCCESS"
else
    echo "  Bind mount failed, falling back to symlink..."
    rm -rf "$TESSDATA_SYSTEM_PATH"
    mkdir -p "$(dirname $TESSDATA_SYSTEM_PATH)"
    ln -sf "$DATA_DIR/tessdata" "$TESSDATA_SYSTEM_PATH"
    echo "  Symlink created"
fi

# Verify tessdata setup
echo "Verifying tessdata..."
echo "  Path: $TESSDATA_SYSTEM_PATH"
echo "  Type: $(stat -c %F "$TESSDATA_SYSTEM_PATH" 2>/dev/null || file "$TESSDATA_SYSTEM_PATH")"
echo "  Contents: $(ls "$TESSDATA_SYSTEM_PATH" 2>/dev/null | wc -l) files"

# Test write directly to the system path
TEST_FILE="$TESSDATA_SYSTEM_PATH/.write_test_$$"
if touch "$TEST_FILE" 2>/dev/null; then
    rm -f "$TEST_FILE"
    echo "  Write test on system path: PASSED"
else
    echo "  Write test on system path: FAILED"
    # Try to fix permissions
    chmod 777 "$TESSDATA_SYSTEM_PATH" 2>/dev/null || true
    chmod 777 "$DATA_DIR/tessdata" 2>/dev/null || true
fi

echo ""
echo "Volume configuration complete:"
echo "  /configs -> $DATA_DIR/configs"
echo "  /pipeline -> $DATA_DIR/pipeline"
echo "  /logs -> $DATA_DIR/logs"
echo "  $TESSDATA_SYSTEM_PATH -> $DATA_DIR/tessdata"
echo ""

# Execute the original entrypoint or command
exec "$@"
