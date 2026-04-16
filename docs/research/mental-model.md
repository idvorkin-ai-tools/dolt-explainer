# Dolt Remote Sync — Mental Model for Git Users

## The 30-second version

Dolt is **git for tables**. Same push/pull/fetch/clone/merge/commit verbs. The
object graph is the same shape. The differences are four:

1. **Unit of diff is a row, not a line.** `dolt diff` shows you
   `| < | 1 | Alice | NYC | → | > | 1 | Alice | Boston |`.
2. **Unit of merge is a cell, not a hunk.** Edits to different columns of the
   same row auto-merge. Only same-cell writes produce conflicts.
3. **Conflicts are queryable.** No `<<<<<<<` markers; instead a system table
   `dolt_conflicts_<table>` with `base_*`, `our_*`, `their_*` columns you
   can SELECT and UPDATE like any other data.
4. **GitHub can be the remote.** No DoltHub needed. Dolt piggybacks on
   git's Smart-HTTP protocol, stuffing chunk files into a custom ref
   (`refs/dolt/data`) that the GitHub UI doesn't know about.

## How GitHub hosting actually works

| Git view                                   | Dolt view                          |
| ------------------------------------------ | ---------------------------------- |
| `refs/heads/main` — your README, static    | Ignored by dolt                    |
| `refs/dolt/data` — one git commit          | The entire dolt database           |
| tree of that commit: `manifest`, `*.darc`, chunk files | Dolt's native chunk store |

A vanilla `git clone` fetches only `refs/heads/*` — it silently omits the
data. A `dolt clone` speaks the same git protocol but fetches `refs/dolt/data`,
then reconstructs the database locally. GitHub is a **dumb blob store** in
this design.

## Workflow isomorphism

| Git | Dolt | Notes |
|-----|------|-------|
| `git init` | `dolt init` | creates `.dolt/` instead of `.git/` |
| `git add .` | `dolt add .` | stages whole tables, not files |
| `git commit -m` | `dolt commit -m` | writes a versioned snapshot of all tables |
| `git diff` | `dolt diff` | shows row-level +/</> markers |
| `git log` | `dolt log` | same hash-based history |
| `git remote add` | `dolt remote add` | `.git` suffix triggers git-transport mode |
| `git push / pull / fetch / clone` | identical verbs | identical semantics |
| `git merge` (auto) | `dolt merge` (cell-wise auto) | stricter 2-parent cap |
| `<<<<<<<` conflict markers | `dolt_conflicts_<table>` | SQL-queryable |
| `git checkout --ours/--theirs` | `dolt conflicts resolve --ours/--theirs` | per-table granularity |
| `git merge --abort` | `dolt merge --abort` | identical |

## One gotcha

Dolt branches are NOT git branches. Your Dolt repo can have
`main`, `dev`, `feature-x` branches — and when you push to GitHub,
they all live inside the tree pointed at by the single `refs/dolt/data`
commit. The only thing you'll see in the GitHub branch dropdown is
`main` (and any other regular git branches you created). To see dolt
branches you must `dolt clone` and run `dolt branch -a`.

## What Dolt inherits unchanged

- non-fast-forward push rejection
- fetch-then-merge-vs-pull choice
- distinct local vs remote-tracking branches (`origin/main`)
- the push-rejection hint text (word-for-word from git, including "hint:")
- exit codes and status-line shape
