#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SCRIPT="$ROOT/skills/pubthis/scripts/configure.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/home" "$TMP/site"

PUBTHIS_API_KEY="env-token" XDG_CONFIG_HOME="$TMP/config" HOME="$TMP/home" "$SCRIPT" global --base-url https://pubthis.net >"$TMP/global.out" 2>"$TMP/global.err"
GLOBAL="$TMP/config/pubthis/config.json"
[ -f "$GLOBAL" ] || { echo "global config was not written" >&2; exit 1; }
jq -e '.baseUrl == "https://pubthis.net" and .apiKey == "env-token"' "$GLOBAL" >/dev/null
[ "$(stat -c '%a' "$GLOBAL" 2>/dev/null || stat -f '%Lp' "$GLOBAL")" = "600" ]
if grep -R 'env-token' "$TMP/global.out" "$TMP/global.err" >/dev/null 2>&1; then
  echo "global configure printed API key" >&2
  exit 1
fi

printf '%s\n' 'stdin-token' | XDG_CONFIG_HOME="$TMP/config2" HOME="$TMP/home" "$SCRIPT" global --api-key-stdin >"$TMP/stdin.out"
jq -e '.baseUrl == "https://pubthis.net" and .apiKey == "stdin-token"' "$TMP/config2/pubthis/config.json" >/dev/null

XDG_CONFIG_HOME="$TMP/config" HOME="$TMP/home" "$SCRIPT" project "$TMP/site" --slug launch-notes --unlisted >"$TMP/project.out" 2>"$TMP/project.err"
PROJECT="$TMP/site/.pubthis/config.json"
[ -f "$PROJECT" ] || { echo "project config was not written" >&2; exit 1; }
jq -e '.slug == "launch-notes" and .visibility == "unlisted"' "$PROJECT" >/dev/null
grep -F 'custom slugs require authenticated publishing' "$TMP/project.err" >/dev/null

if XDG_CONFIG_HOME="$TMP/config" HOME="$TMP/home" "$SCRIPT" project "$TMP/site" --slug Other >"$TMP/bad.out" 2>"$TMP/bad.err"; then
  echo "invalid slug unexpectedly succeeded" >&2
  exit 1
fi
grep -F 'slug must be lowercase DNS-safe' "$TMP/bad.err" >/dev/null

if XDG_CONFIG_HOME="$TMP/config" HOME="$TMP/home" "$SCRIPT" project "$TMP/site" --visibility private >"$TMP/bad-vis.out" 2>"$TMP/bad-vis.err"; then
  echo "invalid visibility unexpectedly succeeded" >&2
  exit 1
fi
grep -F 'visibility must be public or unlisted' "$TMP/bad-vis.err" >/dev/null

if XDG_CONFIG_HOME="$TMP/config" HOME="$TMP/home" "$SCRIPT" project "$TMP/site" --slug other-slug >"$TMP/overwrite.out" 2>"$TMP/overwrite.err"; then
  echo "overwrite without --force unexpectedly succeeded" >&2
  exit 1
fi
grep -F 'slug already exists' "$TMP/overwrite.err" >/dev/null

XDG_CONFIG_HOME="$TMP/config" HOME="$TMP/home" "$SCRIPT" project "$TMP/site" --slug other-slug --public --force >/dev/null
jq -e '.slug == "other-slug" and .visibility == "public"' "$PROJECT" >/dev/null

XDG_CONFIG_HOME="$TMP/config3" HOME="$TMP/home" "$SCRIPT" global --api-key flag-token >"$TMP/flag.out" 2>"$TMP/flag.err"
jq -e '.apiKey == "flag-token" and .baseUrl == "https://pubthis.net"' "$TMP/config3/pubthis/config.json" >/dev/null
if grep -R 'flag-token' "$TMP/flag.out" "$TMP/flag.err" >/dev/null 2>&1; then
  echo "flag API key was printed" >&2
  exit 1
fi
