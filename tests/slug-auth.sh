#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
printf '<h1>slug auth</h1>\n' >"$TMP/index.html"
OUT="$TMP/out.txt"
ERR="$TMP/err.txt"
if "$ROOT/skills/pubthis/scripts/publish.sh" "$TMP" --slug my-demo >"$OUT" 2>"$ERR"; then
  echo "expected --slug without API key to fail" >&2
  exit 1
fi
grep -F -- "--slug requires PUBTHIS_API_KEY or --api-key" "$ERR" >/dev/null
grep -F -- "omit --slug for anonymous publishing" "$ERR" >/dev/null
