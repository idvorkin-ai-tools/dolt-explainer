# Beads + Git sync — explainer

How a beads task database (`refs/dolt/data`) and a code repo (`refs/heads/main`)
share one GitHub fork without colliding, and why the fork-workflow code
pattern (`idvorkin/*` upstream, `idvorkin-ai-tools/*` fork) does not and
should not apply to task state.

**Live page:** https://idvorkin-ai-tools.github.io/dolt-explainer/

## The problem

Agents on multiple machines need to share task state in near-real-time
(beads), while the blog stays on a human-reviewed fork + PR workflow for
code. Two data classes with opposite cadences, one repo, one CLAUDE.md
ritual: `git pull --rebase && bd dolt push && git push`.

## The trick

Dolt writes its database to `refs/dolt/data`, a sibling of `refs/heads/*`.
Git workflows never see it (GitHub UI renders only `refs/heads/*`,
`git clone` fetches only `refs/heads/*`). `bd dolt push/pull` speaks plain
git Smart HTTP to the same GitHub repo using the git credential helper.
Code and beads cohabit because they write disjoint refs.

## Layout

```
index.html                   the single-page explainer (embeds transcripts)
diagrams/*.puml + *.svg      five PlantUML diagrams:
                               dual-sync          one repo, two refs
                               refs-topology      the two-ref layout on a repo
                               push-flow          dolt push via git Smart HTTP
                               fork-workflow      why fork->upstream PR breaks for beads
                               beads-multi-writer why agents don't collide
docs/research/               underlying Dolt-through-Git research
scripts/                     seven reproducible scenario scripts + run-all
transcripts/                 pre-rendered scenario output (embedded in index.html)
runs/                        materialized scenario state (gitignored)
```

## Prereqs

- `dolt` on PATH (`brew install dolt` or the user-local installer)
- `git` on PATH
- `plantuml` on PATH (for rebuilding diagrams)

## Running

```bash
./scripts/run-all.sh           # ~20s, offline, all 7 scenarios
./scripts/run-all.sh --live    # also hits the real GitHub ref repo
./scripts/clean.sh             # wipe runs/
just rebuild-transcripts       # re-render transcripts/ from a fresh run
just build-diagrams            # re-render diagrams/*.svg from .puml sources
```

## Hosting

GitHub Pages, legacy mode, served from `main` branch root. `.nojekyll`
keeps Pages from running Jekyll over plain HTML.
