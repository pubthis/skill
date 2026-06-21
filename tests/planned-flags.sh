#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP="$(mktemp -d)"
OUT="$TMP/out"
ERR="$TMP/err"
trap 'rm -rf "$TMP"' EXIT
printf '<h1>planned</h1>' > "$TMP/index.html"
for flag in --access --password --ttl --spa; do
  if [ "$flag" = "--spa" ]; then
    if "$ROOT/pubthis/scripts/publish.sh" "$TMP" "$flag" >"$OUT" 2>"$ERR"; then
      echo "expected $flag to fail" >&2
      exit 1
    fi
  else
    if "$ROOT/pubthis/scripts/publish.sh" "$TMP" "$flag" value >"$OUT" 2>"$ERR"; then
      echo "expected $flag to fail" >&2
      exit 1
    fi
  fi
  grep 'planned but not supported' "$ERR" >/dev/null
done
