# pubthis.net agent skill

Agent skill for publishing to pubthis.net.

pubthis.net lets agents publish static Sites and store private files in Drives.
For normal work, agents should use the bundled scripts instead of writing their
own API clients.

## Install

```sh
npx skills add thispub/skill -g
```

For repo-local installs, omit `-g`.

## How agents use it

Users do not need to run these scripts by hand. They can ask their agent to
configure pubthis, set publish options for a folder, or publish a site. The skill
then gives the agent stable commands to run.

Typical user requests:

- "Configure pubthis with this API key."
- "Use `https://publish.example.com` as my pubthis base URL."
- "Publish `./site` as `launch-notes`, unlisted."
- "Publish this folder again."

The helper commands behind those requests look like this:

```sh
PUBTHIS_API_KEY=ptk_... ./skills/pubthis/scripts/configure.sh global
./skills/pubthis/scripts/configure.sh project ./site --slug launch-notes --unlisted
./skills/pubthis/scripts/publish.sh ./site
```

Inside an installed skill, helper examples are relative to the skill directory,
so the skill text uses `./scripts/...`.

## Configuration

Global config stores account-level settings:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/pubthis/config.json
```

It may contain:

```json
{
  "baseUrl": "https://pubthis.net",
  "apiKey": "ptk_..."
}
```

Agents should prefer environment or stdin for API keys so tokens do not end up
in shell history:

```sh
PUBTHIS_API_KEY=ptk_... ./skills/pubthis/scripts/configure.sh global
printf '%s\n' "$PUBTHIS_API_KEY" | ./skills/pubthis/scripts/configure.sh global --api-key-stdin
```

Project config lives in the folder being published:

```text
<publish-root>/.pubthis/config.json
```

It may contain:

```json
{
  "slug": "launch-notes",
  "visibility": "unlisted"
}
```

The publish helper reads project config only from the explicit publish root. It
does not walk up parent directories. For single-file publishes, project config is
ignored unless the agent passes `--config <path>`.

## Publish

```sh
./skills/pubthis/scripts/publish.sh ./site
PUBTHIS_API_KEY=... ./skills/pubthis/scripts/publish.sh ./site --slug my-demo
./skills/pubthis/scripts/publish.sh ./site --visibility unlisted
```

Base URL and API key priority for publishing:

1. CLI flags: `--base-url <url>` and `--api-key <key>`
2. Environment: `PUBTHIS_BASE_URL` and `PUBTHIS_API_KEY`
3. Global config: `${XDG_CONFIG_HOME:-$HOME/.config}/pubthis/config.json`
4. Defaults: `https://pubthis.net` and anonymous publishing

Self-hosted pubthis deployments work the same way as pubthis.net. Set `baseUrl`
in global config for the usual endpoint, or pass `--base-url`/`PUBTHIS_BASE_URL`
for one publish.

Visibility values currently supported by the API are `public` and `unlisted`.
Unlisted Sites are available to anyone with the URL, but are omitted from public
listing and discovery surfaces. Anonymous unlisted publishes are allowed and get
generated slugs. Custom slugs still require authenticated publishing.

## Drives

```sh
./skills/pubthis/scripts/drive.sh create "Agent Files"
./skills/pubthis/scripts/drive.sh ls
./skills/pubthis/scripts/drive.sh put <drive-id> notes/today.md --from ./notes/today.md
./skills/pubthis/scripts/drive.sh cat <drive-id> notes/today.md
```

Drives are private unless a scoped token is created. Agents should use the
narrowest token that works for handoff.

## Current surfaces

- Sites: static files, apps, reports, dashboards, documents, and generated assets.
- Drives: private file storage and scoped handoff tokens.
- Site Data/proxy, search, analytics, and richer management surfaces are described
  in the skill and live pubthis.net docs as they become available.

## Evaluation prompts

The skill-creator eval prompts live in `evals/evals.json`. They check that
agents use helper scripts for ordinary publishing and Drive work, avoid custom
API clients, and treat planned access-control workflows as reserved until live
support exists.

## License

MIT
