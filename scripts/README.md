# Dolt sync scenarios

Reproducible, re-runnable demonstrations of how Dolt syncs through a
remote — especially what happens when that remote is a GitHub repo.

Each script is standalone: `./NN-*.sh` wipes its own run directory under
`../runs/NN-*/`, sets up fresh state, runs its scenario, and leaves the
artifacts for you to poke at. Re-running is always safe.

## Layout

```
scenarios/
  lib.sh                  shared helpers (seed_items_repo, run, step, section)
  01-bootstrap.sh         single dolt repo, table, commit
  02-file-remote.sh       push → file:// remote → clone into second dir
  03-roundtrip.sh         edit in clone B, pull in clone A
  04-clean-merge.sh       concurrent inserts on different rows → three-way merge
  05-conflict.sh          concurrent edits on same row → dolt_conflicts_<table>
  06-github-illusion.sh   offline: bare git as fake GitHub, the "empty repo" demo
  06b-github-live.sh      same against real idvorkin-ai-tools/dolt-sync-test
  run-all.sh              runs 01–06, tees transcript (--live adds 06b)
  clean.sh                wipes ../runs/

runs/                     materialized state (gitignored equivalent)
```

## Prereqs

- `dolt` on PATH (`brew install dolt` or the user-local installer)
- `git` on PATH
- 06b only: `gh auth status` must succeed and network must reach github.com

## The six scenes, summarized

1. **Bootstrap** — dolt's basic "git for tables" loop: init, table, insert, commit, log, query.
2. **File remote** — a dolt remote is a directory of chunks on a filesystem. `dolt push` materializes them; `dolt clone` pulls them into a new working copy.
3. **Roundtrip** — clone B adds a row, pushes; clone A pulls and sees the row. History shows B's commit with B's author on A's side.
4. **Clean merge** — A and B insert different rows concurrently. First push wins; second is rejected non-fast-forward; `dolt pull` runs a three-way merge without human input; resulting history has a merge commit.
5. **Conflict** — A and B edit the SAME row. `dolt pull` stalls with a cell-level conflict stored as rows in `dolt_conflicts_items` (base_*, our_*, their_* columns). Resolve with `dolt conflicts resolve --theirs items` or by SQL; commit the merge.
6. **GitHub illusion** — push a dolt database to a bare git repo (stand-in for GitHub). `git log refs/heads/main` shows only the seed README (what the GitHub web UI would render). `git ls-remote` reveals the hidden `refs/dolt/data` ref where the database actually lives. `dolt clone` fetches it. A vanilla `git clone` does not.

## How to use

```bash
# run one scenario
./02-file-remote.sh

# run everything (offline, ~20 seconds)
./run-all.sh

# include the live-GitHub version (hits network)
./run-all.sh --live

# start fresh
./clean.sh
```

After any run, poke at the materialized state:

```bash
cd ../runs/04-clean-merge/cloneA
dolt log --graph --oneline
dolt sql -q 'SELECT * FROM items;'
```
