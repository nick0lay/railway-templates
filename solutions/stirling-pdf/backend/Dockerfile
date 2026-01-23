FROM stirlingtools/stirling-pdf:latest

# Copy custom entrypoint that sets up symlinks for single volume
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Volume mount point /data is configured via Railway platform (not Dockerfile)

ENTRYPOINT ["/entrypoint.sh"]
CMD ["java", "-jar", "/app.jar"]
