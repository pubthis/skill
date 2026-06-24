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

Base URL and API key priority for `publish.sh`:

1. CLI flags: `--base-url <url>` and `--api-key <key>`
2. Environment: `PUBTHIS_BASE_URL` and `PUBTHIS_API_KEY`
3. Global config: `${XDG_CONFIG_HOME:-$HOME/.config}/pubthis/config.json`
4. Defaults: `https://pubthis.net` and anonymous publishing

Global config is read unless `--no-global-config` is passed. It may provide:

```json
{"baseUrl":"https://pubthis.net","apiKey":"..."}
```

Anonymous publishing may use a self-hosted base URL directly. Sending
`PUBTHIS_API_KEY`, `--api-key`, a global config `apiKey`, or `PUBTHIS_DRIVE_TOKEN`
to a non-default base URL requires `--allow-non-pubthis-base-url`.

## Configure pubthis

Use `configure.sh` when the user asks the agent to remember pubthis settings for
future publishes. Prefer environment or stdin for API keys so tokens do not land
in shell history.

One-time global account config:

```sh
PUBTHIS_API_KEY=ptk_... ./scripts/configure.sh global
printf '%s\n' "$PUBTHIS_API_KEY" | ./scripts/configure.sh global --api-key-stdin
./scripts/configure.sh global --base-url https://pubthis.net
```

This writes `${XDG_CONFIG_HOME:-$HOME/.config}/pubthis/config.json` with file
mode `0600`. The helper never prints the API key.

Per-directory publish config:

```sh
./scripts/configure.sh project ./site --slug launch-notes --unlisted
./scripts/configure.sh project ./site --visibility public
```

This writes `./site/.pubthis/config.json`. Existing configured keys are not
changed unless `--force` is passed. `configure.sh` validates slug and visibility
before writing. Writing a custom slug config does not require an API key, but
publishing with that slug still requires authenticated publishing.

## Publish a Site

Run:

```sh
./scripts/publish.sh <file-or-dir>
```

With a chosen DNS-safe slug:

```sh
PUBTHIS_API_KEY=... ./scripts/publish.sh <file-or-dir> --slug my-demo
```

With unlisted visibility:

```sh
./scripts/publish.sh <file-or-dir> --visibility unlisted
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
- For directory publishes, `.pubthis/config.json` is local control-plane metadata and is not uploaded. Other `.pubthis/*` files are not skipped by this rule.

Project publish config is read from `<publish-root>/.pubthis/config.json` unless
`--no-project-config` is passed. It applies only to the explicit target directory
root; the helper does not walk upward. Single-file publishes ignore project
config unless `--config <path>` is supplied. Project config may provide:

```json
{"slug":"my-demo","visibility":"unlisted"}
```

`--config <path>` supplies an explicit config for either file or directory
targets. It may provide `slug` and `visibility`, and may also provide `baseUrl`
or `apiKey`; CLI flags and environment variables still take precedence for
`baseUrl` and `apiKey`.

Publish field precedence:

1. CLI flags: `--slug` and `--visibility`
2. Explicit `--config <path>` or directory project config
3. Defaults: generated slug and public visibility

Visibility rules:

- Supported values are `public` and `unlisted`.
- `public` is the default.
- `unlisted` Sites are accessible to anyone with the URL but omitted from public discovery/listing surfaces.
- Anonymous `--visibility unlisted` publishes are allowed and receive generated slugs.
- Custom slugs still require `PUBTHIS_API_KEY`, `--api-key`, or global/explicit config `apiKey`.

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
