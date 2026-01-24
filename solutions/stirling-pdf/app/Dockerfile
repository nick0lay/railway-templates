FROM stirlingtools/stirling-pdf:latest

# Copy custom entrypoint that sets up symlinks for single volume
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Backup default tessdata files before we modify anything
# (Volume mount will overlay /data, so we need defaults elsewhere)
RUN mkdir -p /opt/tessdata-default && \
    cp -r /usr/share/tesseract-ocr/5/tessdata/* /opt/tessdata-default/ 2>/dev/null || true

# Configure Stirling-PDF to use writable tessdata directory
# TESSDATA_PREFIX is for Tesseract CLI, system.tessdataDir is for Stirling-PDF
ENV TESSDATA_PREFIX=/data/tessdata

# Run as root to avoid volume permission issues (Railway recommendation)
ENV RAILWAY_RUN_UID=0

ENTRYPOINT ["/entrypoint.sh"]
# Pass system.tessdataDir as JVM arg (highest precedence in Spring Boot)
CMD ["java", "-Dsystem.tessdataDir=/data/tessdata", "-jar", "/app.jar"]
