#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
printf '<h1>base url</h1>\n' >"$TMP/index.html"
ERR="$TMP/err.txt"
OUT="$TMP/out.txt"

if PUBTHIS_BASE_URL="http://127.0.0.1:9" "$ROOT/skills/pubthis/scripts/publish.sh" "$TMP" >"$OUT" 2>"$ERR"; then
  echo "unexpected success against closed local port" >&2
  exit 1
fi
if grep -F "refusing to send API key to non-default base URL" "$ERR" >/dev/null; then
  echo "anonymous self-hosted publish should not require allow flag" >&2
  exit 1
fi

if PUBTHIS_BASE_URL="http://127.0.0.1:9" PUBTHIS_API_KEY="test-key" "$ROOT/skills/pubthis/scripts/publish.sh" "$TMP" >"$OUT" 2>"$ERR"; then
  echo "expected credentialed non-default base URL to fail" >&2
  exit 1
fi
grep -F "refusing to send API key to non-default base URL" "$ERR" >/dev/null
