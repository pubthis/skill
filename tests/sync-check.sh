#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp -R "$ROOT/pubthis" "$TMP/pubthis"
rm -rf "$TMP/pubthis/scripts/.gitkeep" "$ROOT/skills/pubthis/scripts/.gitkeep" 2>/dev/null || true
diff -ru "$ROOT/pubthis" "$ROOT/skills/pubthis"
