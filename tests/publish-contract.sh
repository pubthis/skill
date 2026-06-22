#!/usr/bin/env sh
set -eu
BASE_URL="${PUBTHIS_BASE_URL:-https://pubthis.net}"
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/assets"
printf '<h1>pubthis skill publish</h1>' >"$TMP/index.html"
printf 'body{color:#111}' >"$TMP/assets/app.css"
OUT="$($ROOT/skills/pubthis/scripts/publish.sh "$TMP" --base-url "$BASE_URL")"
HOST="$(printf '%s' "$OUT" | awk -F/ '{print $3}')"
BODY="$(curl -fsS -H "Host: $HOST" "$BASE_URL/")"
CSS="$(curl -fsS -H "Host: $HOST" "$BASE_URL/assets/app.css")"
test "$BODY" = '<h1>pubthis skill publish</h1>'
test "$CSS" = 'body{color:#111}'
