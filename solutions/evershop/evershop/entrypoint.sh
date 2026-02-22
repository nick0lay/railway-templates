#!/bin/sh
set -e

# Set shop.homeUrl in config so EverShop generates correct URLs (not localhost)
# RAILWAY_PUBLIC_DOMAIN is auto-set by Railway when a public domain is assigned
if [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then
  SHOP_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
  echo "[entrypoint] Setting shop.homeUrl to ${SHOP_URL}"
  cat > /app/config/local.json <<EOF
{ "shop": { "homeUrl": "${SHOP_URL}" } }
EOF
elif [ -n "$SHOP_HOME_URL" ]; then
  echo "[entrypoint] Setting shop.homeUrl to ${SHOP_HOME_URL}"
  cat > /app/config/local.json <<EOF
{ "shop": { "homeUrl": "${SHOP_HOME_URL}" } }
EOF
fi

# Start EverShop (runs migrations on first boot, then starts HTTP server)
npx evershop start &
EVERSHOP_PID=$!

# Background task: wait for server ready, then create admin user
(
  echo "[entrypoint] Waiting for EverShop to become ready..."

  # Poll until the server responds
  RETRIES=0
  MAX_RETRIES=120
  until wget -q -O /dev/null "http://127.0.0.1:${PORT:-3000}/" 2>/dev/null; do
    RETRIES=$((RETRIES + 1))
    if [ "$RETRIES" -ge "$MAX_RETRIES" ]; then
      echo "[entrypoint] Timed out waiting for EverShop to start"
      exit 1
    fi
    sleep 2
  done

  echo "[entrypoint] EverShop is ready"

  # Create admin user if credentials are provided
  if [ -n "$ADMIN_EMAIL" ] && [ -n "$ADMIN_PASSWORD" ]; then
    echo "[entrypoint] Creating initial admin user..."
    if node /app/create-admin.mjs; then
      echo "[entrypoint] Admin user created successfully"
    else
      echo "[entrypoint] Admin user creation failed (may already exist)"
    fi
  else
    echo "[entrypoint] ADMIN_EMAIL or ADMIN_PASSWORD not set, skipping admin creation"
  fi

  # Seed demo data if requested (only runs once, tracked by flag file)
  if [ "$SEED_DEMO_DATA" = "true" ]; then
    if [ -f /app/media/.demo_seeded ]; then
      echo "[entrypoint] Demo data already seeded (flag file exists), skipping"
    else
      echo "[entrypoint] Seeding demo data..."
      if npx evershop seed --all; then
        echo "[entrypoint] Demo data seeded successfully"
        touch /app/media/.demo_seeded
      else
        echo "[entrypoint] Demo data seeding failed"
      fi
    fi
  fi
) &

# Wait for the main EverShop process
wait $EVERSHOP_PID
