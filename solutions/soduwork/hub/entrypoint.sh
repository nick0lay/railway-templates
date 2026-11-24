#!/bin/sh
# Links every SoduWork state folder to one volume, closes public self-registration on the
# first boot, then runs the upstream command as the soduwork user (uid 10001).
set -e

DATA="${SODUWORK_VOLUME:-/data}"
APP=/srv/app/hub-backend
export SODUWORK_HUB_VERSION="${SODUWORK_HUB_VERSION:-${SODUWORK_RELEASE_TAG#v}}"
export HOME="$DATA/home"

if [ "$(id -u)" != 0 ]; then
  exec "$@"
fi

mkdir -p "$DATA" "$HOME"
rm -rf "$DATA/lost+found"

# link IMAGE_PATH VOLUME_DIR: move what the image ships into the volume once, then symlink.
link() {
  mkdir -p "$2"
  if [ ! -L "$1" ]; then
    if [ -d "$1" ]; then cp -an "$1"/. "$2"/ 2>/dev/null || true; fi
    rm -rf "$1"
    ln -s "$2" "$1"
  fi
}
link "$APP/uploads" "$DATA/uploads"
link "$APP/downloads" "$DATA/downloads"
link "$APP/client-releases" "$DATA/client-releases"
link "$APP/workspaces" "$DATA/workspaces"
link "$APP/releases" "$DATA/releases"
link /srv/runtime "$DATA/runtime"
link /srv/app/repos "$DATA/repos"

# A new Railway volume is owned by root; hand it to the app user once.
if [ "$(stat -c %u "$DATA")" != 10001 ]; then
  chown -R 10001:10001 "$DATA"
fi
chown 10001:10001 "$DATA"/*
echo "entrypoint: uploads, downloads, client-releases, workspaces, releases, runtime, repos and home on $DATA"

# Self-registration is on by default upstream and is stored in the database, so turn it off
# through the admin API once. The marker keeps a later choice in the admin console.
if [ "${SODUWORK_CLOSE_SIGNUP:-true}" = "true" ] && [ ! -f "$DATA/.signup-closed" ]; then
  setpriv --reuid=10001 --regid=10001 --init-groups python - <<'PY' &
import json, os, time, urllib.request

base = "http://127.0.0.1:8989"
marker = os.path.join(os.environ.get("SODUWORK_VOLUME", "/data"), ".signup-closed")


def call(method, path, body=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(base + path, method=method, headers=headers,
                                 data=json.dumps(body).encode() if body is not None else None)
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.load(r)


for _ in range(180):
    try:
        if call("GET", "/readyz").get("ready"):
            break
    except Exception:
        pass
    time.sleep(5)
try:
    token = call("POST", "/api/v1/admin/login",
                 {"user": os.environ.get("ADMIN_USER", "admin"), "pass": os.environ.get("ADMIN_PASS", "")})["token"]
    policy = call("PUT", "/api/v1/admin/client-auth-policy", {"allowSelfRegistration": False}, token)
    if policy.get("allowSelfRegistration") is False:
        with open(marker, "w") as f:
            f.write("closed by the template on first boot\n")
        print("entrypoint: public self-registration closed", flush=True)
except Exception as exc:
    print("entrypoint: could not close self-registration, will retry on next boot:", exc, flush=True)
PY
fi

exec setpriv --reuid=10001 --regid=10001 --init-groups "$@"
