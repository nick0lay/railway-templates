FROM stirlingtools/stirling-pdf:latest

# Copy custom entrypoint that sets up symlinks for single volume
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Backup default tessdata files before volume mount overlays paths
RUN mkdir -p /opt/tessdata-default && \
    cp -r /usr/share/tessdata/* /opt/tessdata-default/ 2>/dev/null || \
    cp -r /usr/share/tesseract-ocr/5/tessdata/* /opt/tessdata-default/ 2>/dev/null || true

# Run as root to avoid volume permission issues (Railway recommendation)
ENV RAILWAY_RUN_UID=0

ENTRYPOINT ["/entrypoint.sh"]
CMD ["tini", "--", "/scripts/init.sh"]
