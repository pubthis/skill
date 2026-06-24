#!/usr/bin/env sh
set -eu

BASE_URL="${PUBTHIS_BASE_URL:-https://pubthis.net}"
AUTH_VALUE="${PUBTHIS_API_KEY:-}"
DRIVE_TOKEN="${PUBTHIS_DRIVE_TOKEN:-}"

usage() {
  cat <<'USAGE'
Usage: drive.sh [global options] <command> [args]

Global options:
  --api-key <key>       Account API key (or $PUBTHIS_API_KEY)
  --token <token>       Drive token (or $PUBTHIS_DRIVE_TOKEN)
  --base-url <url>      API base URL

Commands:
  create [name]
  ls
  ls <drive-id>
  cat <drive-id> <path>
  put <drive-id> <path> --from <local-file>
  rm <drive-id> <path>
  tokens <drive-id>
  share <drive-id> --perms read|write [--prefix path/] [--label text]
USAGE
}

die() { printf 'error: %s\n' "$1" >&2; exit 1; }
require_arg() { [ "$#" -ge 2 ] && [ -n "$2" ] || die "$1 requires a value"; }
need() { command -v "$1" >/dev/null 2>&1 || die "requires $1"; }
need curl
need jq
need awk
need wc

while [ "$#" -gt 0 ]; do
  case "$1" in
    --api-key) require_arg "$1" "${2:-}"; AUTH_VALUE="$2"; shift 2 ;;
    --token) require_arg "$1" "${2:-}"; DRIVE_TOKEN="$2"; shift 2 ;;
    --base-url) require_arg "$1" "${2:-}"; BASE_URL="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    --*) die "unknown global option: $1" ;;
    *) break ;;
  esac
done

CMD="${1:-}"
[ -n "$CMD" ] || { usage >&2; exit 1; }
shift || true
BASE_URL="${BASE_URL%/}"

AUTH_VALUE_SELECTED="$AUTH_VALUE"
[ -n "$DRIVE_TOKEN" ] && AUTH_VALUE_SELECTED="$DRIVE_TOKEN"
[ -n "$AUTH_VALUE_SELECTED" ] || die "missing credentials; set PUBTHIS_API_KEY or PUBTHIS_DRIVE_TOKEN"
AUTH="Authorization: Bearer $AUTH_VALUE_SELECTED"

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else die "requires sha256sum or shasum"; fi
}

urlencode_path() {
  path="${1#/}"
  out=""
  old_ifs="$IFS"
  IFS='/'
  set -- $path
  IFS="$old_ifs"
  for part in "$@"; do
    encoded="$(jq -nr --arg v "$part" '$v|@uri')"
    if [ -z "$out" ]; then out="$encoded"; else out="$out/$encoded"; fi
  done
  printf '%s' "$out"
}

content_type() {
  case "$1" in
    *.html|*.htm) printf 'text/html' ;;
    *.css) printf 'text/css' ;;
    *.js|*.mjs) printf 'text/javascript' ;;
    *.json) printf 'application/json' ;;
    *.svg) printf 'image/svg+xml' ;;
    *.png) printf 'image/png' ;;
    *.jpg|*.jpeg) printf 'image/jpeg' ;;
    *.gif) printf 'image/gif' ;;
    *.webp) printf 'image/webp' ;;
    *.pdf) printf 'application/pdf' ;;
    *.txt|*.md) printf 'text/plain' ;;
    *) if command -v file >/dev/null 2>&1; then file --brief --mime-type "$1"; else printf 'application/octet-stream'; fi ;;
  esac
}

api() {
  method="$1"
  url="$2"
  body_file="${3:-}"
  if [ -n "$body_file" ]; then
    curl -fsS -X "$method" "$url" -H "$AUTH" -H 'content-type: application/json' --data-binary "@$body_file"
  else
    curl -fsS -X "$method" "$url" -H "$AUTH"
  fi
}

api_string_body() {
  tmp_body="$(mktemp)"
  trap 'rm -f "$tmp_body"' EXIT HUP INT TERM
  printf '%s' "$3" > "$tmp_body"
  api "$1" "$2" "$tmp_body"
  rm -f "$tmp_body"
  trap - EXIT HUP INT TERM
}

current_file_etag() {
  drive_id="$1"
  drive_path="$2"
  api GET "$BASE_URL/api/drives/$drive_id/files" \
    | jq -r --arg p "/${drive_path#/}" '.files[]? | select(.path == $p) | .etag' \
    | sed -n '1p'
}

case "$CMD" in
  create)
    NAME="${1:-Agent Files}"
    BODY="$(jq -n --arg name "$NAME" '{name:$name}')"
    api_string_body POST "$BASE_URL/api/drives" "$BODY"
    ;;
  ls)
    if [ "$#" -eq 0 ]; then
      api GET "$BASE_URL/api/drives"
    else
      DRIVE_ID="$1"
      api GET "$BASE_URL/api/drives/$DRIVE_ID/files"
    fi
    ;;
  cat)
    DRIVE_ID="${1:-}"
    PATH_ARG="${2:-}"
    [ -n "$DRIVE_ID" ] && [ -n "$PATH_ARG" ] || die "cat requires drive id and path"
    api GET "$BASE_URL/api/drives/$DRIVE_ID/files/$(urlencode_path "$PATH_ARG")"
    ;;
  put)
    DRIVE_ID="${1:-}"
    PATH_ARG="${2:-}"
    if [ "$#" -ge 2 ]; then shift 2; else shift "$#"; fi
    FROM=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --from) require_arg "$1" "${2:-}"; FROM="$2"; shift 2 ;;
        *) die "unexpected put argument: $1" ;;
      esac
    done
    [ -n "$DRIVE_ID" ] && [ -n "$PATH_ARG" ] && [ -f "$FROM" ] || die "put requires drive id, path, and --from file"
    if ! LC_ALL=C tr -d '\000' < "$FROM" | cmp -s - "$FROM"; then
      die "Drive API currently accepts UTF-8 text content; binary files with NUL bytes are not supported by this helper"
    fi
    SIZE="$(wc -c < "$FROM" | awk '{print $1}')"
    SHA="$(sha256_file "$FROM")"
    TYPE="$(content_type "$FROM")"
    ETAG="$(current_file_etag "$DRIVE_ID" "$PATH_ARG" || true)"
    BODY_FILE="$(mktemp)"
    if [ -n "$ETAG" ]; then
      jq -n --rawfile content "$FROM" --arg type "$TYPE" --arg sha "$SHA" --argjson size "$SIZE" --arg etag "$ETAG" \
        '{content:$content, contentType:$type, sha256:$sha, sizeBytes:$size, baseEtag:$etag}' > "$BODY_FILE"
    else
      jq -n --rawfile content "$FROM" --arg type "$TYPE" --arg sha "$SHA" --argjson size "$SIZE" \
        '{content:$content, contentType:$type, sha256:$sha, sizeBytes:$size}' > "$BODY_FILE"
    fi
    api PUT "$BASE_URL/api/drives/$DRIVE_ID/files/$(urlencode_path "$PATH_ARG")" "$BODY_FILE"
    rm -f "$BODY_FILE"
    ;;
  rm)
    DRIVE_ID="${1:-}"
    PATH_ARG="${2:-}"
    [ -n "$DRIVE_ID" ] && [ -n "$PATH_ARG" ] || die "rm requires drive id and path"
    api DELETE "$BASE_URL/api/drives/$DRIVE_ID/files/$(urlencode_path "$PATH_ARG")" >/dev/null
    ;;
  tokens)
    DRIVE_ID="${1:-}"
    [ -n "$DRIVE_ID" ] || die "tokens requires drive id"
    api GET "$BASE_URL/api/drives/$DRIVE_ID/tokens"
    ;;
  share)
    DRIVE_ID="${1:-}"
    shift || true
    PERMS=""
    PREFIX="/"
    LABEL="agent handoff"
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --perms) require_arg "$1" "${2:-}"; PERMS="$2"; shift 2 ;;
        --prefix) require_arg "$1" "${2:-}"; PREFIX="$2"; shift 2 ;;
        --label) require_arg "$1" "${2:-}"; LABEL="$2"; shift 2 ;;
        *) die "unexpected share argument: $1" ;;
      esac
    done
    [ -n "$DRIVE_ID" ] && [ -n "$PERMS" ] || die "share requires drive id and --perms read|write"
    case "$PERMS" in read) PERMS_JSON='["read"]' ;; write) PERMS_JSON='["read","write"]' ;; *) die "--perms must be read or write" ;; esac
    case "$PREFIX" in /*) ;; *) PREFIX="/$PREFIX" ;; esac
    BODY="$(jq -n --arg label "$LABEL" --arg prefix "$PREFIX" --argjson perms "$PERMS_JSON" '{label:$label, prefix:$prefix, perms:$perms}')"
    api_string_body POST "$BASE_URL/api/drives/$DRIVE_ID/tokens" "$BODY"
    ;;
  *)
    die "unknown command: $CMD"
    ;;
esac
