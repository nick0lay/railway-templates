FROM stirlingtools/stirling-pdf:latest

# Copy custom entrypoint that sets up symlinks for single volume
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Backup default tessdata files before creating symlink
# (Volume mount will overlay /data, so we need defaults elsewhere)
RUN mkdir -p /opt/tessdata-default && \
    cp -r /usr/share/tesseract-ocr/5/tessdata/* /opt/tessdata-default/ 2>/dev/null || true

# Replace system tessdata with symlink to volume mount point
RUN rm -rf /usr/share/tesseract-ocr/5/tessdata && \
    mkdir -p /usr/share/tesseract-ocr/5 && \
    ln -sf /data/tessdata /usr/share/tesseract-ocr/5/tessdata

# Configure Stirling-PDF to use writable tessdata directory
ENV SYSTEM_TESSDATADIR=/data/tessdata
ENV TESSDATA_PREFIX=/data

# Run as root to avoid volume permission issues (Railway recommendation)
ENV RAILWAY_RUN_UID=0

ENTRYPOINT ["/entrypoint.sh"]
CMD ["java", "-jar", "/app.jar"]
