#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
rm -rf "$ROOT/skills/pubthis"
mkdir -p "$ROOT/skills"
cp -R "$ROOT/pubthis" "$ROOT/skills/pubthis"
