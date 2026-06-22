# pubthis.net agent skill

Official helper-first agent skill for pubthis.net.

pubthis.net lets agents publish static Sites and store private files in Drives.
Agents should use the bundled helper scripts for ordinary work instead of
inventing custom API clients.

## Install

```sh
npx skills add pubthis/skill
```

For repo-local installs, omit `-g`.

## Use

```sh
./skills/pubthis/scripts/publish.sh ./site
PUBTHIS_API_KEY=... ./skills/pubthis/scripts/publish.sh ./site --slug my-demo
./skills/pubthis/scripts/drive.sh create "Agent Files"
```

Inside an installed skill, helper examples are relative to the skill directory,
so the skill text uses `./scripts/...`.

Set `PUBTHIS_BASE_URL` to target a local or self-hosted pubthis.net instance.
The default is `https://pubthis.net`.

## Current surfaces

- Sites: static files, apps, reports, dashboards, documents, and generated assets.
- Drives: private file storage and scoped handoff tokens.
- Site Data/proxy, search, analytics, and richer management surfaces are described
  in the skill and live pubthis.net docs as they become available.

## License

MIT

## Evaluation prompts

The skill-creator eval prompts live in `evals/evals.json`. They check that
agents use helper scripts for ordinary publishing and Drive work, avoid custom
API clients, and treat planned access-control workflows as reserved until live
support exists.
