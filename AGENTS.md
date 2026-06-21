# pubthis.net Skill Repo Agent Guide

Use this guide when editing the public pubthis.net skill repository.

## Source of truth

- Canonical skill bundle: `pubthis/`
- Compatibility mirror: `skills/pubthis/`
- Agent context: `https://pubthis.net/llms.txt`
- API schema: `https://pubthis.net/openapi.json`

For ordinary publishing and Drive work, the local skill text and helper scripts
must be sufficient. Use live docs for freshness and advanced API work, not as a
replacement for the helper-script golden path.

## Editing rules

- Keep `pubthis/` and `skills/pubthis/` synchronized with `scripts/sync-mirror.sh`.
- Public copy uses lowercase `pubthis.net`.
- Do not add claims for OAuth, MCP, billing, custom-domain automation, or
  server-side compute unless those surfaces are live.
- Planned flags must fail clearly before network calls until support is live.
- Never commit credentials, API keys, Drive tokens, or local state.

## Verification

Run:

```sh
tests/sync-check.sh
tests/planned-flags.sh
PUBTHIS_BASE_URL=https://pubthis.net tests/publish-contract.sh
```

Run `tests/drive-contract.sh` only with a valid local API key or Drive token.
