#!/bin/sh
# Turns on htpasswd auth from REGISTRY_USERNAME and REGISTRY_PASSWORD, then
# starts the registry with the image's own entrypoint.
set -e

if [ -n "$REGISTRY_USERNAME" ] && [ -n "$REGISTRY_PASSWORD" ]; then
  mkdir -p /auth
  htpasswd -Bbn -C 10 "$REGISTRY_USERNAME" "$REGISTRY_PASSWORD" > /auth/htpasswd
  export REGISTRY_AUTH=htpasswd
  export REGISTRY_AUTH_HTPASSWD_REALM="Registry"
  export REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd
  echo "Registry auth enabled for user $REGISTRY_USERNAME"
else
  echo "WARNING: REGISTRY_USERNAME or REGISTRY_PASSWORD not set; registry has no auth"
fi

exec /entrypoint.sh "$@"
