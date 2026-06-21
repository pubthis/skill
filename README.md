# pubthis.net agent skill

Official helper-first agent skill for pubthis.net.

pubthis.net lets agents publish static Sites and store private files in Drives.
Agents should use the bundled helper scripts for ordinary work instead of
inventing custom API clients.

## Install

```sh
npx skills add pubthis-agent-skill --skill pubthis -g
```

For repo-local installs, omit `-g`.

## Use

```sh
./pubthis/scripts/publish.sh ./site
./pubthis/scripts/publish.sh ./site --slug my-demo
./pubthis/scripts/drive.sh create "Agent Files"
```

Set `PUBTHIS_BASE_URL` to target a local or self-hosted pubthis.net instance.
The default is `https://pubthis.net`.

## Current surfaces

- Sites: static files, apps, reports, dashboards, documents, and generated assets.
- Drives: private file storage and scoped handoff tokens.
- Site Data/proxy, search, analytics, and richer management surfaces are described
  in the skill and live pubthis.net docs as they become available.

## License

MIT
