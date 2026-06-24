#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SCRIPT="$ROOT/skills/pubthis/scripts/publish.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin" "$TMP/home/.config/pubthis" "$TMP/site/.pubthis"
printf '<h1>hello</h1>' > "$TMP/site/index.html"
printf 'keep me' > "$TMP/site/.pubthis/keep.txt"
cat > "$TMP/home/.config/pubthis/config.json" <<'JSON'
{"baseUrl":"https://pubthis.net","apiKey":"global-token"}
JSON
cat > "$TMP/site/.pubthis/config.json" <<'JSON'
{"slug":"configured-site","visibility":"unlisted"}
JSON
cat > "$TMP/explicit.json" <<'JSON'
{"slug":"explicit-file","visibility":"unlisted","baseUrl":"https://explicit.example","apiKey":"explicit-token"}
JSON
cat > "$TMP/bin/curl" <<'SH'
#!/usr/bin/env sh
set -eu
if [ "$1" = "-fsS" ] && [ "$2" = "-X" ] && [ "$3" = "POST" ]; then
  url="$4"
  shift 4
  body=""
  auth=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -d) body="$2"; shift 2 ;;
      -H) case "$2" in Authorization:*) auth="$2" ;; esac; shift 2 ;;
      *) shift ;;
    esac
  done
  case "$url" in
    */api/publish)
      printf '%s' "$body" > "$PUBTHIS_CAPTURE/create.json"
      printf '%s' "$url" > "$PUBTHIS_CAPTURE/url.txt"
      printf '%s' "$auth" > "$PUBTHIS_CAPTURE/auth.txt"
      printf '{"siteId":"00000000-0000-0000-0000-000000000001","publishSessionId":"00000000-0000-0000-0000-000000000002","uploadTargets":[{"path":"index.html","method":"PUT","url":"https://upload.example/index.html","requiredHeaders":{"content-type":"text/html"}},{"path":".pubthis/keep.txt","method":"PUT","url":"https://upload.example/keep.txt","requiredHeaders":{"content-type":"text/plain"}}]}'
      ;;
    */api/publish/*/uploads) printf '{}' ;;
    */api/publish/*/finalize) printf '{"siteId":"00000000-0000-0000-0000-000000000001","versionId":"00000000-0000-0000-0000-000000000003","versionNumber":1,"url":"https://configured-site.pubthis.net"}' ;;
  esac
elif [ "$1" = "-fsS" ] && [ "$2" = "-X" ] && [ "$3" = "PUT" ]; then
  exit 0
else
  echo "unexpected curl $*" >&2
  exit 1
fi
SH
chmod +x "$TMP/bin/curl"

PUBTHIS_CAPTURE="$TMP" HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home/.config" PATH="$TMP/bin:$PATH" "$SCRIPT" "$TMP/site" >/dev/null
jq -e '.slug == "configured-site" and .visibility == "unlisted" and .authMode == "api_key" and (.files | length == 2) and ([.files[].path] | index(".pubthis/config.json") | not) and ([.files[].path] | index(".pubthis/keep.txt") != null)' "$TMP/create.json" >/dev/null
grep -F 'Authorization: Bearer global-token' "$TMP/auth.txt" >/dev/null

PUBTHIS_CAPTURE="$TMP" HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home/.config" PATH="$TMP/bin:$PATH" "$SCRIPT" "$TMP/site" --slug cli-site --visibility public >/dev/null
jq -e '.slug == "cli-site" and .visibility == "public"' "$TMP/create.json" >/dev/null

PUBTHIS_CAPTURE="$TMP" HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home/.config" PATH="$TMP/bin:$PATH" "$SCRIPT" "$TMP/site/index.html" --no-global-config >/dev/null
if jq -e 'has("slug") or has("visibility")' "$TMP/create.json" >/dev/null 2>&1; then
  echo "single-file publish unexpectedly used project config" >&2
  exit 1
fi

PUBTHIS_CAPTURE="$TMP" HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home/.config" PATH="$TMP/bin:$PATH" "$SCRIPT" "$TMP/site" --no-global-config --no-project-config >/dev/null
if jq -e 'has("slug") or has("visibility") or .authMode != "anonymous"' "$TMP/create.json" >/dev/null 2>&1; then
  echo "disabled config unexpectedly affected directory publish" >&2
  exit 1
fi

PUBTHIS_CAPTURE="$TMP" HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home/.config" PATH="$TMP/bin:$PATH" "$SCRIPT" "$TMP/site/index.html" --config "$TMP/explicit.json" --allow-non-pubthis-base-url >/dev/null
jq -e '.slug == "explicit-file" and .visibility == "unlisted" and .authMode == "api_key"' "$TMP/create.json" >/dev/null
grep -F 'https://explicit.example/api/publish' "$TMP/url.txt" >/dev/null
grep -F 'Authorization: Bearer explicit-token' "$TMP/auth.txt" >/dev/null

if PUBTHIS_CAPTURE="$TMP" HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home/.config" PATH="$TMP/bin:$PATH" "$SCRIPT" "$TMP/site" --visibility private >"$TMP/out" 2>"$TMP/err"; then
  echo "invalid visibility unexpectedly succeeded" >&2
  exit 1
fi
grep -F 'visibility must be public or unlisted' "$TMP/err" >/dev/null
