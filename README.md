# Dolt sync explainer

How [Dolt](https://github.com/dolthub/dolt) — a SQL database that versions like
Git — syncs through a remote, especially a plain GitHub repo, demonstrated with
six reproducible shell-script scenarios.

**Live page:** https://idvorkin-ai-tools.github.io/dolt-explainer/

## The one-line version

Dolt pushes to a hidden ref `refs/dolt/data`. GitHub's web UI only renders
`refs/heads/*`, so a Dolt-backed GitHub repo looks empty in the file browser
but round-trips a full database via `dolt clone`. See the live reference repo
[idvorkin-ai-tools/dolt-sync-test](https://github.com/idvorkin-ai-tools/dolt-sync-test).

## Layout

```
index.html                   single-page walkthrough (embeds transcripts)
docs/research/               research notes that preceded the explainer
  findings.md                full writeup
  mental-model.md            git-user's cheat sheet for dolt
  archetype-recommendation.md
  GITHUB-DEMO-REPO.md
scripts/                     the six reproducible scenarios
  lib.sh                     shared helpers
  01-bootstrap.sh            ...
  06-github-illusion.sh      the killer demo (offline, bare git)
  06b-github-live.sh         same against real GitHub (opt-in, needs gh auth)
  run-all.sh / clean.sh
transcripts/                 pre-rendered output from each scenario (embedded in index.html)
runs/                        materialized state from scenario runs (gitignored)
```

## Prereqs

- `dolt` on PATH (`brew install dolt` or the user-local installer)
- `git` on PATH

## Running

```bash
./scripts/run-all.sh          # ~20s, offline
./scripts/run-all.sh --live   # also runs 06b against real GitHub (needs gh auth)
./scripts/clean.sh            # wipe runs/
```

Re-regenerate `transcripts/` after editing scripts:

```bash
just rebuild-transcripts
```

## Hosting

GitHub Pages, legacy mode, served from `main` branch root. `.nojekyll` keeps
Pages from running Jekyll over plain HTML.
