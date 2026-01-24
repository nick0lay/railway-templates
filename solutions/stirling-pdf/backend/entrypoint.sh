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

# Debug: permissions before chmod
echo "Before chmod:"
ls -la "$DATA_DIR" | grep tessdata
stat "$DATA_DIR/tessdata" 2>/dev/null || echo "stat failed"

# Ensure tessdata is fully writable
chmod 777 "$DATA_DIR/tessdata" && echo "chmod 777 succeeded" || echo "chmod 777 FAILED"
chmod 666 "$DATA_DIR/tessdata"/*.traineddata 2>/dev/null || true

# Debug: permissions after chmod
echo "After chmod:"
ls -la "$DATA_DIR" | grep tessdata
stat "$DATA_DIR/tessdata" 2>/dev/null || echo "stat failed"

# Verification
echo ""
echo "Configuration:"
echo "  TESSDATA_PREFIX=$TESSDATA_PREFIX"
echo "  Contents: $(ls $DATA_DIR/tessdata 2>/dev/null | wc -l) files"
echo ""
ls -la "$DATA_DIR/tessdata" | head -3
echo ""

# Write test with Java-like temp file pattern
TEST_FILE="$DATA_DIR/tessdata/tessdata-write-test$$.tmp"
if touch "$TEST_FILE" 2>/dev/null; then
    rm -f "$TEST_FILE"
    echo "Write test: PASSED"
else
    echo "Write test: FAILED (touch failed)"
fi

# Test with mktemp (closer to Java's createTempFile)
TEMP_TEST=$(mktemp -p "$DATA_DIR/tessdata" tessdata-write-test.XXXXXX.tmp 2>&1) && {
    rm -f "$TEMP_TEST"
    echo "mktemp test: PASSED"
} || echo "mktemp test: FAILED - $TEMP_TEST"

# Python test (mimics Java's Files.isWritable and createTempFile)
echo ""
echo "Python test (mimics Java behavior):"
/opt/venv/bin/python3 << 'PYEOF'
import os
import tempfile
import sys

path = "/data/tessdata"
print(f"  Path: {path}")
print(f"  Exists: {os.path.exists(path)}")
print(f"  Is dir: {os.path.isdir(path)}")
print(f"  os.access(W_OK): {os.access(path, os.W_OK)}")
print(f"  os.access(R_OK): {os.access(path, os.R_OK)}")
print(f"  os.access(X_OK): {os.access(path, os.X_OK)}")
print(f"  UID: {os.getuid()}, EUID: {os.geteuid()}")
print(f"  GID: {os.getgid()}, EGID: {os.getegid()}")

# Try to create temp file like Java does
try:
    fd, tmp_path = tempfile.mkstemp(prefix="tessdata-write-test", suffix=".tmp", dir=path)
    os.close(fd)
    os.unlink(tmp_path)
    print(f"  tempfile.mkstemp: PASSED")
except Exception as e:
    print(f"  tempfile.mkstemp: FAILED - {e}")
PYEOF
echo ""

# Execute the original entrypoint or command
exec "$@"
