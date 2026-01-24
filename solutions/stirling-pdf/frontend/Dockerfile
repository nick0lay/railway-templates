FROM stirlingtools/stirling-pdf:latest

# Create writable tessdata directory for Frontend mode
# Note: Frontend has no volume, so downloads are ephemeral (lost on redeploy)
# For persistent OCR languages, access the Backend directly or use shared volume
RUN mkdir -p /data/tessdata && \
    cp -r /usr/share/tesseract-ocr/5/tessdata/* /data/tessdata/ 2>/dev/null || true && \
    chmod -R 777 /data/tessdata

# Configure Stirling-PDF to use writable tessdata directory
ENV TESSDATA_PREFIX=/data/tessdata

# Pass system.tessdataDir as JVM arg (highest precedence in Spring Boot)
CMD ["java", "-Dsystem.tessdataDir=/data/tessdata", "-jar", "/app.jar"]
