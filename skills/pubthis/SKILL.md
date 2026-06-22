---
name: pubthis
description: >
  pubthis.net lets agents publish static Sites and store private files in
  Drives. Use this skill whenever the user asks to publish, host, deploy,
  share, put files online, create a static website/app/report/dashboard, save
  private files, preserve context, or hand files to another agent. Prefer the
  bundled helper scripts for ordinary publishing and Drive work; do not generate
  custom Python or Node API clients for routine pubthis.net tasks.
---

# pubthis.net

**Skill version: 0.1.0**

pubthis.net gives agents two primary capabilities:

- **Sites**: publish static websites, apps, files, documents, dashboards,
  reports, media, and generated assets to live URLs.
- **Drives**: store private agent files for context, memory, plans, research,
  assets, media, and handoff.

## Golden rule

For ordinary work, use the bundled helper scripts. Do not write a custom Python,
Node, or ad hoc API client just to publish a Site or use a Drive.

Use live docs only when freshness matters or the task goes beyond this skill:

- Agent context: `https://pubthis.net/llms.txt`
- API schema: `https://pubthis.net/openapi.json`

## Requirements

Required binaries: `sh`, `curl`, `awk`, `wc`, `find`, `sort`, `jq`, and one SHA-256
utility (`sha256sum` or `shasum`).

Optional binaries: `file` for better content type detection.

Environment variables:

- `PUBTHIS_BASE_URL`: API base URL. Default: `https://pubthis.net`.
- `PUBTHIS_API_KEY`: account/API bearer token for authenticated calls.
- `PUBTHIS_DRIVE_TOKEN`: scoped Drive token for Drive reads/writes.

Base URL priority:

1. `--base-url <url>`
2. `PUBTHIS_BASE_URL`
3. `https://pubthis.net`

Anonymous publishing may use a self-hosted base URL directly. Sending
`PUBTHIS_API_KEY`, `--api-key`, or `PUBTHIS_DRIVE_TOKEN` to a non-default base
URL requires `--allow-non-pubthis-base-url`.

## Publish a Site

Run:

```sh
./scripts/publish.sh <file-or-dir>
```

With a chosen DNS-safe slug:

```sh
PUBTHIS_API_KEY=... ./scripts/publish.sh <file-or-dir> --slug my-demo
```

To set the API base URL explicitly:

```sh
PUBTHIS_BASE_URL=https://pubthis.net ./scripts/publish.sh <file-or-dir>
```

The script prints the canonical share URL to stdout. Share that URL with the
user. It also prints `publish_result.*` lines to stderr for machine-readable
status.

Path rules:

- Directory publishes preserve relative paths.
- Bundled app assets under `assets/...` stay under `assets/...`.
- Use the returned URL as the root for links.
- Do not rewrite share links onto the service apex.

Slug rules:

- Anonymous publishing must omit `--slug`; pubthis.net chooses a human-readable slug.
- Custom slugs require `PUBTHIS_API_KEY` or `--api-key` and use authenticated API-key publishing.
- Slugs must be one lowercase DNS-safe label.
- Allowed characters: `a-z`, `0-9`, and hyphen.
- No dots, underscores, spaces, uppercase, leading hyphen, or trailing hyphen.
- If unsure, omit `--slug` and let pubthis.net choose one.

## Use a Drive

Use Drives for private files, durable context, plans, research, and agent-to-agent
handoff.

```sh
./scripts/drive.sh create "Agent Files"
./scripts/drive.sh ls
./scripts/drive.sh ls <drive-id>
./scripts/drive.sh put <drive-id> notes/today.md --from ./notes/today.md
./scripts/drive.sh cat <drive-id> notes/today.md
./scripts/drive.sh share <drive-id> --perms read --prefix notes/
```

Drive files are private unless a scoped token is created. When sharing with
another agent, prefer the narrowest prefix and permission set that works.

## Reserved planned workflows

The following workflows are reserved for near-future pubthis.net support. Do not
claim they work unless live docs or API responses confirm support:

- account API-key onboarding
- password-protected Sites
- restricted invite-only Sites
- Site access-policy updates
- custom domains
- profile and Site visibility
- richer owner Site management

`publish.sh` may expose reserved flags such as `--access`, `--password`, `--ttl`,
and `--spa`. Until support is live, these flags fail before network calls with a
clear planned-feature message.

## Stable errors

pubthis.net API errors use stable JSON fields:

```json
{
  "error": "short_error",
  "code": "stable_code",
  "message": "Human-readable message",
  "retry_after": null,
  "docs_url": null
}
```

Branch on `code`, not message text.

Common recovery:

- `invalid_share_slug`: omit slug or choose a DNS-safe lowercase label.
- `custom_slug_requires_auth`: retry with `PUBTHIS_API_KEY`/`--api-key`, or omit `--slug` for anonymous publishing.
- `invalid_request`: compare the request to this skill or `/llms.txt`.
- `upload_rejected`: recompute file bytes, size, content type, and SHA-256.
- `unauthorized`: send a valid bearer token or use anonymous mode where allowed.
- `forbidden`: the token cannot access this resource.
- `not_found`: confirm the Site, Drive, session, token, or path.
- `conflict`: refresh state and retry with the latest slug or ETag.
- `rate_limited` or `rate_limit_exceeded`: honor retry timing.

## Fallback publish contract

If `publish.sh` is unavailable, use the exact create, upload, complete, and
finalize flow described in `https://pubthis.net/llms.txt`. Do not infer request
bodies from memory.
