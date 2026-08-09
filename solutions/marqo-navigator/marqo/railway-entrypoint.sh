#!/bin/bash
# Railway allows one volume per service, but Marqo needs two paths to survive a
# redeploy:
#
#   /opt/vespa/var           Vespa state — indexes, documents, vectors.
#                            Lost = every index gone.
#   /root/.cache/huggingface Embedding model weights (~420MB for e5-base-v2).
#                            Not baked into the image; they download on first
#                            boot. Lost = re-downloaded on every deploy, which
#                            delays the healthcheck and can trip a restart loop.
#
# The obvious approach — mount one volume elsewhere and symlink both paths into
# it — does not work here. The upstream image declares `VOLUME /opt/vespa/var`,
# so that path is always a live mountpoint and `rm` on it fails with "Device or
# resource busy".
#
# So the volume mounts AT /opt/vespa/var (which is also what Marqo's own docs
# recommend) and the model cache is symlinked into a subdirectory of it.
set -e

VESPA_VAR="/opt/vespa/var"
MODEL_CACHE="$VESPA_VAR/hf-cache"

# Seed a fresh volume with the skeleton Vespa expects. Docker copies image
# content into an empty named volume automatically; Railway volumes start truly
# empty, so without this the config server starts against missing directories
# and never converges — /health never returns 200 and Railway restart-loops the
# container.
if [ -z "$(ls -A "$VESPA_VAR" 2>/dev/null)" ]; then
    echo "[railway-entrypoint] empty volume — seeding Vespa directory skeleton"
    cp -a /opt/vespa-var-default/. "$VESPA_VAR/" 2>/dev/null || true
fi

# Park the HuggingFace cache inside the same volume. `ln -sfn` avoids nesting a
# second symlink inside an existing one when the container restarts.
mkdir -p "$MODEL_CACHE" /root/.cache
rm -rf /root/.cache/huggingface
ln -sfn "$MODEL_CACHE" /root/.cache/huggingface

exec "$@"
