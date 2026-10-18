#!/bin/sh
# demo-reset.sh — rebuild rflib's public demo account: remove it (and its
# library), add it again with the published password, and fill its library
# with the demo radios (rflib's web/demo/populate.mjs, run in a throwaway
# Node container on the rflib container's network).
#
# Run it on TrueNAS, nightly, from a cron job (see README):
#
#   /mnt/<pool>/Homes/rflib/demo-reset.sh /mnt/<pool>/Homes/rflib/demo-password
#
# The password file holds the demo password, the one the announcement
# publishes. POPULATE names where populate.mjs comes from: a URL (by
# default rflib's main branch) or a local file.

set -eu

PASSWORD_FILE="${1:?usage: demo-reset.sh PASSWORD_FILE}"
CONTAINER="${CONTAINER:-rflib}"
USER_NAME="${DEMO_USER:-demo}"
POPULATE="${POPULATE:-https://raw.githubusercontent.com/rgeyer/rflib/main/web/demo/populate.mjs}"

PASSWORD="$(cat "$PASSWORD_FILE")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ -f "$POPULATE" ]; then
  cp "$POPULATE" "$WORK/populate.mjs"
else
  curl -fsSL -o "$WORK/populate.mjs" "$POPULATE"
fi

# A missing account is fine: the first run, or one removed by hand.
docker exec "$CONTAINER" rflib user remove "$USER_NAME" --yes 2>/dev/null || true
printf '%s\n%s\n' "$PASSWORD" "$PASSWORD" | docker exec -i "$CONTAINER" rflib user add "$USER_NAME" --display "Demo"
docker run --rm --network "container:$CONTAINER" -v "$WORK":/demo:ro node:22-alpine \
  node /demo/populate.mjs --url http://127.0.0.1:8080 --user "$USER_NAME" --password "$PASSWORD"
