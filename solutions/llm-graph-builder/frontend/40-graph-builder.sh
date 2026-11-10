#!/bin/sh
# Writes the nginx login file and site config from environment variables.
#   BASIC_AUTH_USER / BASIC_AUTH_PASSWORD  login for the whole site (required)
#   BACKEND_HOST / BACKEND_PORT            private address of the Backend service
#   PORT                                   listen port (default 8080)
#   NGINX_WORKERS                          nginx worker processes (default 2)
set -eu

: "${BASIC_AUTH_USER:?BASIC_AUTH_USER is not set}"
: "${BASIC_AUTH_PASSWORD:?BASIC_AUTH_PASSWORD is not set}"
: "${BACKEND_HOST:?BACKEND_HOST is not set}"
BACKEND_PORT="${BACKEND_PORT:-8000}"
PORT="${PORT:-8080}"

# nginx's "auto" starts one worker per host CPU (dozens on Railway); a static UI needs two.
sed -i "s/^worker_processes .*/worker_processes ${NGINX_WORKERS:-2};/" /etc/nginx/nginx.conf

# SHA-512 crypt hash, so the password never sits in the config in plain text.
printf '%s:%s\n' "$BASIC_AUTH_USER" "$(openssl passwd -6 "$BASIC_AUTH_PASSWORD")" > /etc/nginx/.htpasswd
chown root:nginx /etc/nginx/.htpasswd
chmod 640 /etc/nginx/.htpasswd

# Resolve the backend at request time with the container's DNS server: Railway gives a
# service a new private address on every redeploy, and nginx would otherwise keep the old one.
NS=$(awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf)
case "$NS" in *:*) NS="[$NS]" ;; esac

cat > /etc/nginx/conf.d/graph-builder.conf <<CONF
server {
  listen [::]:${PORT} ipv6only=off;
  server_tokens off;

  resolver ${NS} valid=10s ipv6=on;
  set \$backend "http://${BACKEND_HOST}:${BACKEND_PORT}";

  auth_basic "LLM Graph Builder";
  auth_basic_user_file /etc/nginx/.htpasswd;

  add_header X-Frame-Options "DENY" always;
  add_header X-Content-Type-Options "nosniff" always;

  # Railway healthcheck, no login.
  location = /healthz {
    auth_basic off;
    default_type text/plain;
    return 200 "ok\n";
  }

  # API calls and server-sent events, forwarded to the private backend.
  location /api/ {
    client_max_body_size 50m;
    # Upstream's upload and extract calls put the API URL in front of a path that axios
    # prefixes again, giving /api/api/... with a relative API URL. Strip one or two prefixes
    # (no backend route starts with /api).
    rewrite ^/api(?:/api)?/(.*)\$ /\$1 break;
    proxy_pass \$backend;
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    # Do not pass the site login on to the backend.
    proxy_set_header Authorization "";
    proxy_buffering off;
    proxy_cache off;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
  }

  location ~* ^/assets/ {
    root /usr/share/nginx/html;
    try_files \$uri =404;
  }

  location / {
    root /usr/share/nginx/html;
    index index.html;
    try_files \$uri \$uri/ /index.html;
    add_header Cache-Control "no-cache" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
  }
}
CONF
echo "graph-builder: login user ${BASIC_AUTH_USER}, backend ${BACKEND_HOST}:${BACKEND_PORT}, resolver ${NS}"
