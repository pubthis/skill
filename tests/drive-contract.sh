#!/usr/bin/env sh
set -eu
: "${PUBTHIS_BASE_URL:=https://pubthis.net}"
if [ -z "${PUBTHIS_API_KEY:-}" ]; then
	echo "skip: PUBTHIS_API_KEY is required for drive contract" >&2
	exit 0
fi
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
printf 'private report\n' >"$TMP/report.txt"
CREATE="$($ROOT/pubthis/scripts/drive.sh --base-url "$PUBTHIS_BASE_URL" --allow-non-pubthis-base-url create "Skill Test $(date +%s)-$$")"
DRIVE_ID="$(printf '%s' "$CREATE" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | sed -n '1p')"
[ -n "$DRIVE_ID" ] || {
	echo "$CREATE" >&2
	exit 1
}
$ROOT/pubthis/scripts/drive.sh --base-url "$PUBTHIS_BASE_URL" --allow-non-pubthis-base-url put "$DRIVE_ID" report.txt --from "$TMP/report.txt" >/dev/null
BODY="$($ROOT/pubthis/scripts/drive.sh --base-url "$PUBTHIS_BASE_URL" --allow-non-pubthis-base-url cat "$DRIVE_ID" report.txt)"
test "$BODY" = 'private report'
printf 'private report updated\n' >"$TMP/report.txt"
$ROOT/pubthis/scripts/drive.sh --base-url "$PUBTHIS_BASE_URL" --allow-non-pubthis-base-url put "$DRIVE_ID" report.txt --from "$TMP/report.txt" >/dev/null
UPDATED="$($ROOT/pubthis/scripts/drive.sh --base-url "$PUBTHIS_BASE_URL" --allow-non-pubthis-base-url cat "$DRIVE_ID" report.txt)"
test "$UPDATED" = 'private report updated'
printf 'space path\n' >"$TMP/space path.txt"
$ROOT/pubthis/scripts/drive.sh --base-url "$PUBTHIS_BASE_URL" --allow-non-pubthis-base-url put "$DRIVE_ID" "folder/space path.txt" --from "$TMP/space path.txt" >/dev/null
SPACE_BODY="$($ROOT/pubthis/scripts/drive.sh --base-url "$PUBTHIS_BASE_URL" --allow-non-pubthis-base-url cat "$DRIVE_ID" "folder/space path.txt")"
test "$SPACE_BODY" = 'space path'
$ROOT/pubthis/scripts/drive.sh --base-url "$PUBTHIS_BASE_URL" --allow-non-pubthis-base-url share "$DRIVE_ID" --perms read --prefix report.txt >/dev/null
