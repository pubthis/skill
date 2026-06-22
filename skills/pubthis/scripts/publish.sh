#!/usr/bin/env sh
set -eu

BASE_URL="${PUBTHIS_BASE_URL:-https://pubthis.net}"
AUTH_VALUE="${PUBTHIS_API_KEY:-}"
ALLOW_NON_PUBTHIS_BASE_URL=0
SLUG=""
CLIENT="pubthis-skill/publish-sh"
TARGET=""

usage() {
  cat <<'USAGE'
Usage: publish.sh <file-or-dir> [options]

Options:
  --slug <slug>             DNS-safe share slug
  --base-url <url>          API base URL (default: https://pubthis.net or $PUBTHIS_BASE_URL)
  --api-key <key>           API key (prefer $PUBTHIS_API_KEY)
  --client <name>           Agent/client name for diagnostics
  --allow-non-pubthis-base-url
                            Allow credentials to non-default base URL
  --access <mode>           Planned: public|password|restricted
  --password <value>        Planned: password-protected Sites
  --ttl <seconds>           Planned: authenticated expiry control
  --spa                     Planned: SPA fallback routing
USAGE
}

die() { printf 'error: %s\n' "$1" >&2; exit 1; }
planned() { die "$1 is planned but not supported by this pubthis.net deployment yet"; }
require_arg() { [ "$#" -ge 2 ] && [ -n "$2" ] || die "$1 requires a value"; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --slug) require_arg "$1" "${2:-}"; SLUG="$2"; shift 2 ;;
    --base-url) require_arg "$1" "${2:-}"; BASE_URL="$2"; shift 2 ;;
    --api-key) require_arg "$1" "${2:-}"; AUTH_VALUE="$2"; shift 2 ;;
    --client) require_arg "$1" "${2:-}"; CLIENT="$2"; shift 2 ;;
    --allow-non-pubthis-base-url) ALLOW_NON_PUBTHIS_BASE_URL=1; shift ;;
    --access) planned "--access" ;;
    --password) planned "--password" ;;
    --ttl) planned "--ttl" ;;
    --spa) planned "--spa" ;;
    --help|-h) usage; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *) if [ -z "$TARGET" ]; then TARGET="$1"; shift; else die "unexpected argument: $1"; fi ;;
  esac
done

[ -n "$TARGET" ] || { usage >&2; exit 1; }
[ -e "$TARGET" ] || die "path does not exist: $TARGET"
BASE_URL="${BASE_URL%/}"

case "$SLUG" in
  "") ;;
  -*|*-) die "slug must not start or end with hyphen" ;;
  *[!abcdefghijklmnopqrstuvwxyz0123456789-]*) die "slug must be lowercase DNS-safe a-z, 0-9, or hyphen" ;;
esac
if [ -n "$SLUG" ] && [ "${#SLUG}" -gt 63 ]; then die "slug must be 63 characters or fewer"; fi
if [ -n "$SLUG" ] && [ -z "$AUTH_VALUE" ]; then
  die "--slug requires PUBTHIS_API_KEY or --api-key; omit --slug for anonymous publishing"
fi

if [ -n "$AUTH_VALUE" ] && [ "$BASE_URL" != "https://pubthis.net" ] && [ "$ALLOW_NON_PUBTHIS_BASE_URL" -ne 1 ]; then
  die "refusing to send API key to non-default base URL; pass --allow-non-pubthis-base-url"
fi

need() { command -v "$1" >/dev/null 2>&1 || die "requires $1"; }
need curl
need awk
need wc
need find
need sort

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else die "requires sha256sum or shasum"; fi
}

json_escape() {
  awk 'BEGIN{for(i=1;i<ARGC;i++){s=ARGV[i]; gsub(/\\/,"\\\\",s); gsub(/"/,"\\\"",s); gsub(/\t/,"\\t",s); gsub(/\r/,"\\r",s); gsub(/\n/,"\\n",s); printf "%s",s}}' "$1"
}

sed_escape_basic() {
  printf '%s' "$1" | sed 's/[.[\*^$(){}+?|\/&]/\\&/g'
}

json_string_field() {
  field="$1"
  file="$2"
  sed -n 's/.*"'"$field"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | sed -n '1p'
}

upload_url_for_path() {
  rel="$1"
  escaped_rel="$(sed_escape_basic "$rel")"
  tr '\n' ' ' < "$CREATE_RESPONSE" \
    | sed 's/},{/}\
{/g' \
    | sed -n '/"path"[[:space:]]*:[[:space:]]*"'"$escaped_rel"'"/ { s/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p; q; }'
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

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
MANIFEST="$TMP/manifest.tsv"
: > "$MANIFEST"

add_file() {
  file_path="$1"
  rel_path="$2"
  case "$rel_path" in /*|*\\*|..|../*|*/../*|*/..) die "unsafe publish path: $rel_path" ;; esac
  size="$(wc -c < "$file_path" | awk '{print $1}')"
  sha="$(sha256_file "$file_path")"
  type="$(content_type "$file_path")"
  printf '%s\t%s\t%s\t%s\t%s\n' "$rel_path" "$file_path" "$size" "$sha" "$type" >> "$MANIFEST"
}

if [ -f "$TARGET" ]; then
  add_file "$TARGET" "$(basename "$TARGET")"
elif [ -d "$TARGET" ]; then
  find "$TARGET" -type f | sort | while IFS= read -r file_path; do
    rel="${file_path#$TARGET/}"
    [ "$rel" = ".DS_Store" ] && continue
    add_file "$file_path" "$rel"
  done
else
  die "not a file or directory: $TARGET"
fi

[ -s "$MANIFEST" ] || die "no files found"

FILES_JSON=""
while IFS="$(printf '\t')" read -r rel abs size sha type; do
  item="{\"path\":\"$(json_escape "$rel")\",\"contentType\":\"$(json_escape "$type")\",\"sizeBytes\":$size,\"sha256\":\"$sha\"}"
  if [ -z "$FILES_JSON" ]; then FILES_JSON="$item"; else FILES_JSON="$FILES_JSON,$item"; fi
done < "$MANIFEST"

AUTH_MODE="anonymous"
AUTH_HEADER=""
if [ -n "$AUTH_VALUE" ]; then
  AUTH_MODE="api_key"
  AUTH_HEADER="Authorization: Bearer $AUTH_VALUE"
fi

CREATE_BODY="{\"mode\":\"create\",\"authMode\":\"$AUTH_MODE\",\"files\":[$FILES_JSON]"
[ -n "$SLUG" ] && CREATE_BODY="$CREATE_BODY,\"slug\":\"$(json_escape "$SLUG")\""
CREATE_BODY="$CREATE_BODY}"

CREATE_RESPONSE="$TMP/create.json"
if [ -n "$AUTH_HEADER" ]; then
  curl -fsS -X POST "$BASE_URL/api/publish" -H 'content-type: application/json' -H "$AUTH_HEADER" -H "x-pubthis-client: $CLIENT" -d "$CREATE_BODY" > "$CREATE_RESPONSE"
else
  curl -fsS -X POST "$BASE_URL/api/publish" -H 'content-type: application/json' -H "x-pubthis-client: $CLIENT" -d "$CREATE_BODY" > "$CREATE_RESPONSE"
fi

SESSION="$(json_string_field publishSessionId "$CREATE_RESPONSE")"
[ -n "$SESSION" ] || die "create response missing publishSessionId"

while IFS="$(printf '\t')" read -r rel abs size sha type; do
  upload_url="$(upload_url_for_path "$rel")"
  [ -n "$upload_url" ] || die "missing upload URL for $rel"
  curl -fsS -X PUT "$upload_url" -H "content-type: $type" --data-binary "@$abs" >/dev/null
  COMPLETE_BODY="{\"publishSessionId\":\"$SESSION\",\"path\":\"$(json_escape "$rel")\",\"objectKey\":\"uploads/$SESSION/$(json_escape "$rel")\",\"sha256\":\"$sha\",\"sizeBytes\":$size}"
  if [ -n "$AUTH_HEADER" ]; then
    curl -fsS -X POST "$BASE_URL/api/publish/$SESSION/uploads" -H 'content-type: application/json' -H "$AUTH_HEADER" -d "$COMPLETE_BODY" >/dev/null
  else
    curl -fsS -X POST "$BASE_URL/api/publish/$SESSION/uploads" -H 'content-type: application/json' -d "$COMPLETE_BODY" >/dev/null
  fi
done < "$MANIFEST"

FINAL_FILES=""
while IFS="$(printf '\t')" read -r rel abs size sha type; do
  item="{\"path\":\"$(json_escape "$rel")\",\"sha256\":\"$sha\"}"
  if [ -z "$FINAL_FILES" ]; then FINAL_FILES="$item"; else FINAL_FILES="$FINAL_FILES,$item"; fi
done < "$MANIFEST"
FINAL_BODY="{\"publishSessionId\":\"$SESSION\",\"files\":[$FINAL_FILES]}"
FINAL_RESPONSE="$TMP/final.json"
if [ -n "$AUTH_HEADER" ]; then
  curl -fsS -X POST "$BASE_URL/api/publish/$SESSION/finalize" -H 'content-type: application/json' -H "$AUTH_HEADER" -d "$FINAL_BODY" > "$FINAL_RESPONSE"
else
  curl -fsS -X POST "$BASE_URL/api/publish/$SESSION/finalize" -H 'content-type: application/json' -d "$FINAL_BODY" > "$FINAL_RESPONSE"
fi
URL="$(json_string_field url "$FINAL_RESPONSE")"
[ -n "$URL" ] || die "finalize response missing url"

printf '%s\n' "$URL"
printf 'publish_result.url=%s\n' "$URL" >&2
printf 'publish_result.auth_mode=%s\n' "$AUTH_MODE" >&2
printf 'publish_result.base_url=%s\n' "$BASE_URL" >&2
printf 'publish_result.file_count=%s\n' "$(wc -l < "$MANIFEST" | awk '{print $1}')" >&2
[ -n "$SLUG" ] && printf 'publish_result.slug=%s\n' "$SLUG" >&2
