# Dolt Remote Sync — Research Findings

**Environment:** dolt 1.85.0, Ubuntu aarch64, gh as idvorkin-ai-tools.
**Test repo:** idvorkin-ai-tools/dolt-sync-test (deleted at end of research).
All transcripts in /tmp/dolt-research/transcripts/.

---

## 1. What remote types does Dolt support?

Confirmed from `dolt remote --help` and docs:

| Scheme                   | Backend                                                                  |
| ------------------------ | ------------------------------------------------------------------------ |
| `file://`                | Local filesystem directory (dedicated — NOT a dolt working dir)          |
| `https://` (bare)        | DoltHub GRPC — or, if URL ends `.git`, auto-upgraded to a Git remote     |
| `ssh://`                 | SSH                                                                      |
| `aws://[dynamo:bucket]/` | S3 + DynamoDB (DynamoDB holds the manifest; S3 holds the chunks)         |
| `gs://BUCKET/path`       | Google Cloud Storage                                                     |
| `oci://BUCKET/path`      | Oracle Cloud                                                             |
| `git+https://`, `git+ssh://`, `git+file://` | Explicit Git transport; auto-selected when URL ends `.git` |
| `<org>/<repo>` shorthand | Expanded to `https://doltremoteapi.dolthub.com/<org>/<repo>`             |

The **default data ref** for git remotes is `refs/dolt/data`, overridable with `--ref`.

---

## 2. Can you sync a Dolt database through a GitHub repo?

**Yes — natively, with zero helper scripts.** This is the big finding.

When you run `dolt remote add origin https://github.com/org/repo.git`, Dolt:

1. Detects the `.git` suffix and stores the remote URL internally as `git+https://...` (visible in `dolt remote -v`).
2. Treats the remote as a Git Smart-HTTP server.
3. Uses the standard Git credential helper chain, so `gh auth login` (which installs a helper) makes push/pull work over HTTPS.

### What lands on GitHub

After `dolt push -u origin main`:

```
$ git ls-remote https://github.com/idvorkin-ai-tools/dolt-sync-test.git
5ecb69b...    HEAD
166d805...    refs/dolt/data        <-- all dolt data lives here
5ecb69b...    refs/heads/main       <-- untouched seed branch
```

`refs/dolt/data` is an ordinary **git commit** whose tree is:

```
manifest                              (text — dolt's chunk store manifest)
sofumu2e77qt2fbq0dgimcgsco4rmpe3.darc (binary — Dolt archive of chunks)
jh41qp3l6gg46as38mdmqf0d5nb1n2eh      (binary — a single Noms chunk)
```

The commit message is literally `"gitblobstore: checkandput manifest"` (observed in `git cat-file -p refs/dolt/data`).

### Why the GitHub UI shows an "empty" repo

GitHub's web file browser and contents API only inspect `refs/heads/<branch>`. `refs/dolt/data` is fetched by `git ls-remote` and `git fetch '+refs/dolt/data:refs/dolt/data'`, but it is **invisible** to the normal GitHub UI. A vanilla `git clone` also ignores it because git's default refspec is `+refs/heads/*:refs/remotes/origin/*`.

### Prerequisite

**The GitHub repo must already have at least one branch/commit.** Pushing to a freshly-created, empty GitHub repo fails with:

```
git remote has no branches: cannot push to "..."; initialize the repository
with an initial branch/commit first
```

So the minimal bootstrap is: `gh repo create --private`, then a seed `README.md` + initial commit + git push, **then** `dolt remote add` and `dolt push`.

### Round-trip verified

- `dolt clone https://github.com/.../repo.git newDir` pulls down `refs/dolt/data`, reconstructs the chunk store, and replays the history: all tables, rows, commits present.
- `dolt push` from the clone advances `refs/dolt/data` on GitHub without touching `refs/heads/main`.
- Concurrent pushes from two clones produce the same non-fast-forward / pull-then-merge / conflict cycle as the local file remote (verified).

---

## 3. The "second clone sees a change" workflow

Exactly the git cadence. The only visible difference is the diff format.

```bash
# in clone B
dolt sql -q "INSERT INTO people VALUES (4,'Dave','Seattle');"
dolt sql -q "UPDATE people SET city='Boston' WHERE id=1;"
dolt diff                        # row-level preview:
#   | < | 1 | Alice | NYC    |   <-- old
#   | > | 1 | Alice | Boston |   <-- new
#   | + | 4 | Dave  | Seattle|   <-- inserted
dolt add . && dolt commit -m "..."
dolt push

# in clone A
dolt fetch
dolt log --oneline --all         # sees remotes/origin/main ahead
dolt diff main origin/main       # same row-level diff, BEFORE merging
dolt pull                        # Fast-forward
dolt sql -q "SELECT * FROM people;"
```

The row-level diff surfaces in four places:

1. `dolt diff` (working-tree vs HEAD)
2. `dolt diff <ref1> <ref2>` (any two commits)
3. `dolt diff --summary` (one-line stats per table: `people | 1 *`)
4. The `dolt_diff_<table>` system table — queryable via SQL.

---

## 4. What merges look like

### Fast-forward
When the local branch has no new commits, `dolt pull` updates without a merge commit — identical to git. Output: `Fast-forward / Updating <old>..<new>`.

### Three-way (clean)
Concurrent edits to **different** rows merge automatically. Dolt creates a merge commit with the standard two parents. Observed:

```
*   Merge branch 'main' of file://... into main
|\
| * B: add Frank in Denver        (origin/main)
* | A: add Eve in Austin          (local)
|/
* ...earlier shared history
```

Merge summary: `1 tables changed, 0 rows added(+), 0 rows modified(*), 1 rows deleted(-)` — a per-table row-delta summary, not a file-level one.

**Git constraint carried over:** from the docs, Dolt merges are strictly 2-parent (git allows N). Not observed as a practical limitation.

### Conflict
Same-row same-column edits produce a conflict. The resolution surface is radically different from git's `<<<<<<<` text markers.

`dolt status` looks nearly identical to git:

```
Your branch and 'origin/main' have diverged, and have 1 and 1 different commits each.
    You have unmerged tables.
  (fix conflicts and run "dolt commit")
  (use "dolt merge --abort" to abort the merge)
Unmerged paths:
    both modified:    people
```

But then:

```
$ dolt conflicts cat people
+---+--------+----+------+----------+
|   |        | id | name | city     |
+---+--------+----+------+----------+
|   | base   | 2  | Bob  | SF       |   <-- common ancestor
| * | ours   | 2  | Bob  | Portland |
| * | theirs | 2  | Bob  | Miami    |
+---+--------+----+------+----------+
```

Conflicts are **rows in a system table**:

```sql
SELECT * FROM dolt_conflicts;             -- summary: table | num_conflicts
SELECT * FROM dolt_conflicts_people;      -- one row per conflicting PK
-- columns: from_root_ish, base_*, our_*, their_*, our_diff_type, their_diff_type,
--          dolt_conflict_id
```

`our_diff_type` / `their_diff_type` values observed: `modified` (both updated same cell) and `+` (both inserted same PK with different non-PK values — the `base` row is absent in that case).

**Resolution**, three paths:

1. **Side-picking:** `dolt conflicts resolve --ours <table>` or `--theirs <table>`. Observed: populates the working table with the chosen side and clears the conflicts. Then `dolt commit -m "..."` finalizes the merge.
2. **Manual via SQL:** `UPDATE` the target table to the desired state, then `DELETE FROM dolt_conflicts_<table> WHERE dolt_conflict_id = '...';`. Docs-confirmed, schema supports it.
3. **Abort:** `dolt merge --abort` returns to the pre-pull state.

Conflict level: **cell**, not row. If two branches modify different columns of the same row, Dolt auto-merges cell-wise. Conflicts only appear when the same cell is written to different values (or when a primary key collides as above).

---

## 5. "Aha" moments for a git user

- **The GitHub repo looks empty but isn't.** Data lives in `refs/dolt/data`, which GitHub's UI and default `git clone` both ignore. Opening the repo in a browser shows only the seed README — and yet `dolt clone` pulls megabytes of real table data out of it.
- **`dolt diff` shows rows, not lines.** `| < | old | ... |` / `| > | new | ... |` is the unit. This alone is the explainer's money shot.
- **Conflicts are a queryable table, not `<<<<<<<` markers.** You can write a SQL `SELECT` to find every conflicted cell, filter by column, or apply bulk resolution by `UPDATE`/`DELETE` on `dolt_conflicts_<table>`. Unthinkable in git.
- **Auto-merge is cell-wise.** If A edits row 5 column X and B edits row 5 column Y, there's no conflict. Git would treat the line as a conflict.
- **GitHub becomes a free Dolt host.** No DoltHub account needed. The tradeoff: the GitHub UI shows nothing useful; you need a Dolt client to read the data.
- **The `.darc` naming is content-addressed.** File names like `sofumu2e77qt2fbq0dgimcgsco4rmpe3.darc` are chunk hashes — git's content-addressing wraps dolt's content-addressing. Two levels of dedup.
- **The remote bootstrap requires a git commit first.** Empty GitHub repos reject the push with a confusing error. Seeded repos work instantly.
- **`dolt remote -v` rewrites your URL.** You enter `https://github.com/org/repo.git`, it stores `git+https://github.com/org/repo.git`.
- **Authentication is free.** Because dolt hands off to the git credential helper, `gh auth login` or a configured SSH key is all you need. No dolt-specific token setup.
- **Merge summary is row-count-based.** `people | 1 *` (one modified row) not `people.sql | +12 -3` (line delta). Much more meaningful for data.
- **The default `refs/dolt/data` is a single ref.** All branches of your Dolt DB live inside the tree pointed to by that one git commit. Dolt branches are not git branches.

---

## 6. Recommended explainer archetype

**Timeline-explorer with side-by-side A/B panes.** Details in `archetype-recommendation.md`. Short version: the narrative is inherently about two repos ticking forward together, and the single best visual is the `dolt conflicts cat` three-way table appearing mid-timeline. A linear narrative-chapters format underserves the "two clones evolve in parallel" geometry; a pure tracker has nothing to track. Side-by-side lets you show the GitHub `refs/dolt/data` state as a third column that advances whenever either side pushes — the "aha" the explainer most needs to land.
