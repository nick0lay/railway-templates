# Use the official StarRocks all-in-one image (FE + BE in one container)
# Can be overridden by Railway environment variable `STARROCKS_IMAGE_TAG`
ARG STARROCKS_IMAGE_TAG
FROM starrocks/allin1-ubuntu:${STARROCKS_IMAGE_TAG:-latest}

# Wrapper that adapts the image to Railway (volume, dynamic PORT, root password)
COPY railway-entrypoint.sh /railway-entrypoint.sh
RUN chmod +x /railway-entrypoint.sh

# HTTP surface only: the FE web UI, REST API and Stream Load are proxied by the
# bundled nginx. The MySQL port (9030) is reached through Railway's TCP Proxy,
# which is configured with an explicit port and does not rely on EXPOSE.
EXPOSE 8080

# ENTRYPOINT is inherited on purpose: the image sets it to tini-static, which
# must remain PID 1 to reap the background password job.
CMD ["/railway-entrypoint.sh"]
