# Docker registry for Trigger.dev task images, with basic auth.
#
# The CLI pushes task images here (after `docker login`) and the supervisor on
# DigitalOcean pulls them, both over the public domain. Without auth, anyone
# could push or pull. Images live on the Railway volume at /var/lib/registry.
ARG REGISTRY_IMAGE_TAG=2
FROM registry:${REGISTRY_IMAGE_TAG}

RUN apk add --no-cache apache2-utils

COPY railway-entrypoint.sh /railway-entrypoint.sh
RUN chmod +x /railway-entrypoint.sh

# Lets `registry garbage-collect` remove deleted images later.
ENV REGISTRY_STORAGE_DELETE_ENABLED=true

EXPOSE 5000
ENTRYPOINT ["/railway-entrypoint.sh"]
CMD ["/etc/docker/registry/config.yml"]
