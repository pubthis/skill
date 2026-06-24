#!/usr/bin/env sh
set -eu

MODE=""
TARGET=""
BASE_URL=""
API_KEY=""
API_KEY_STDIN=0
SLUG=""
VISIBILITY=""
FORCE=0

usage() {
  cat <<'USAGE'
Usage:
  configure.sh global [options]
  configure.sh project <publish-root> [options]

Global options:
  --base-url <url>      API base URL (default: https://pubthis.net)
  --api-key <key>       API key (prefer PUBTHIS_API_KEY or --api-key-stdin)
  --api-key-stdin       Read API key from stdin

Project options:
  --slug <slug>         DNS-safe share slug
  --visibility <mode>   public|unlisted
  --public              Alias for --visibility public
  --unlisted            Alias for --visibility unlisted

Common options:
  --force               Overwrite existing configured keys
  --help, -h            Show this help
USAGE
}

die() { printf 'error: %s\n' "$1" >&2; exit 1; }
require_arg() { [ "$#" -ge 2 ] && [ -n "$2" ] || die "$1 requires a value"; }
need() { command -v "$1" >/dev/null 2>&1 || die "requires $1"; }

json_escape() {
  awk 'BEGIN{for(i=1;i<ARGC;i++){s=ARGV[i]; gsub(/\\/,"\\\\",s); gsub(/"/,"\\\"",s); gsub(/\t/,"\\t",s); gsub(/\r/,"\\r",s); gsub(/\n/,"\\n",s); printf "%s",s}}' "$1"
}

config_value() {
  file="$1"
  key="$2"
  [ -f "$file" ] || return 0
  jq -r --arg key "$key" 'if type == "object" and has($key) and .[$key] != null then .[$key] else empty end' "$file"
}

validate_slug() {
  slug="$1"
  case "$slug" in
    "") return 0 ;;
    -*|*-) die "slug must not start or end with hyphen" ;;
    *[!abcdefghijklmnopqrstuvwxyz0123456789-]*) die "slug must be lowercase DNS-safe a-z, 0-9, or hyphen" ;;
  esac
  [ "${#slug}" -le 63 ] || die "slug must be 63 characters or fewer"
}

validate_visibility() {
  case "$1" in
    ""|public|unlisted) ;;
    *) die "visibility must be public or unlisted" ;;
  esac
}

set_field() {
  file="$1"
  key="$2"
  value="$3"
  tmp="$4"
  [ -n "$value" ] || return 0
  current="$(config_value "$file" "$key")"
  if [ -n "$current" ] && [ "$current" != "$value" ] && [ "$FORCE" -ne 1 ]; then
    die "$key already exists in $file; pass --force to overwrite"
  fi
  jq --arg key "$key" --arg value "$value" '. + {($key): $value}' "$tmp" > "$tmp.next"
  mv "$tmp.next" "$tmp"
}

write_config() {
  file="$1"
  dir="$(dirname "$file")"
  umask 077
  mkdir -p "$dir"
  chmod 700 "$dir" 2>/dev/null || true
  tmp="$(mktemp "$dir/.config.tmp.XXXXXX")"
  trap 'rm -f "$tmp" "$tmp.next"' EXIT HUP INT TERM
  if [ -f "$file" ]; then
    jq 'if type == "object" then . else error("config must be a JSON object") end' "$file" > "$tmp"
  else
    printf '{}\n' > "$tmp"
  fi

  case "$MODE" in
    global)
      set_field "$file" baseUrl "$BASE_URL" "$tmp"
      set_field "$file" apiKey "$API_KEY" "$tmp"
      ;;
    project)
      set_field "$file" slug "$SLUG" "$tmp"
      set_field "$file" visibility "$VISIBILITY" "$tmp"
      ;;
  esac

  chmod 600 "$tmp"
  mv "$tmp" "$file"
  trap - EXIT HUP INT TERM
}

[ "$#" -gt 0 ] || { usage >&2; exit 1; }
MODE="$1"
shift
case "$MODE" in
  global|project) ;;
  --help|-h) usage; exit 0 ;;
  *) die "expected mode: global or project" ;;
esac

if [ "$MODE" = "project" ]; then
  [ "$#" -gt 0 ] || die "project mode requires <publish-root>"
  case "$1" in -*) die "project mode requires <publish-root> before options" ;; esac
  TARGET="$1"
  shift
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --base-url) require_arg "$1" "${2:-}"; BASE_URL="$2"; shift 2 ;;
    --api-key) require_arg "$1" "${2:-}"; API_KEY="$2"; shift 2 ;;
    --api-key-stdin) API_KEY_STDIN=1; shift ;;
    --slug) require_arg "$1" "${2:-}"; SLUG="$2"; shift 2 ;;
    --visibility) require_arg "$1" "${2:-}"; VISIBILITY="$2"; shift 2 ;;
    --public) VISIBILITY="public"; shift ;;
    --unlisted) VISIBILITY="unlisted"; shift ;;
    --force) FORCE=1; shift ;;
    --help|-h) usage; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *) die "unexpected argument: $1" ;;
  esac
done

need jq

if [ "$API_KEY_STDIN" -eq 1 ]; then
  [ -z "$API_KEY" ] || die "use either --api-key or --api-key-stdin, not both"
  IFS= read -r API_KEY || true
fi
if [ "$MODE" = "global" ] && [ -z "$API_KEY" ] && [ -n "${PUBTHIS_API_KEY:-}" ]; then
  API_KEY="$PUBTHIS_API_KEY"
fi
if [ "$MODE" = "global" ] && [ -z "$BASE_URL" ] && [ -n "${PUBTHIS_BASE_URL:-}" ]; then
  BASE_URL="$PUBTHIS_BASE_URL"
fi

case "$MODE" in
  global)
    [ -n "$BASE_URL" ] || BASE_URL="https://pubthis.net"
    CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
    [ -n "$CONFIG_HOME" ] || die "XDG_CONFIG_HOME or HOME is required"
    CONFIG_FILE="$CONFIG_HOME/pubthis/config.json"
    write_config "$CONFIG_FILE"
    printf 'pubthis global config written: %s\n' "$CONFIG_FILE"
    ;;
  project)
    [ -d "$TARGET" ] || die "publish root must be an existing directory: $TARGET"
    validate_slug "$SLUG"
    validate_visibility "$VISIBILITY"
    [ -n "$SLUG" ] || [ -n "$VISIBILITY" ] || die "project mode requires --slug, --visibility, --public, or --unlisted"
    CONFIG_FILE="$TARGET/.pubthis/config.json"
    write_config "$CONFIG_FILE"
    printf 'pubthis project config written: %s\n' "$CONFIG_FILE"
    if [ -n "$SLUG" ]; then
      printf 'note: custom slugs require authenticated publishing via API key.\n' >&2
    fi
    ;;
esac
