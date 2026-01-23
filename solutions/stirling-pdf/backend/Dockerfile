FROM stirlingtools/stirling-pdf:latest

# Copy custom entrypoint that sets up symlinks for single volume
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Single volume mount point
VOLUME ["/data"]

ENTRYPOINT ["/entrypoint.sh"]
CMD ["java", "-jar", "/app.jar"]
