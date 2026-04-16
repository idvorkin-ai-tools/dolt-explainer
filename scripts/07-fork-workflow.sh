#!/usr/bin/env bash
# 07-fork-workflow.sh
# Simulate Igor's fork workflow (idvorkin=upstream authoritative,
# idvorkin-ai-tools=fork can push/pull only to fork) with dolt-backed repos.
# Answers: where does merging happen; can the GitHub PR model see data diffs;
# what does a fork-only push reveal about upstream/refs-dolt-data?
#
# Everything runs locally with two bare git repos standing in for the
# two GitHub repos.

set -euo pipefail
source "$(dirname "$0")/lib.sh"

section "SCENARIO 7 — fork workflow (upstream authoritative + fork push/pull)"

RUN="$(reset_run_dir 07-fork-workflow)"
UPSTREAM="$RUN/upstream.git"   # stands in for github.com/idvorkin/dolt-thing.git
FORK="$RUN/fork.git"           # stands in for github.com/idvorkin-ai-tools/dolt-thing.git
DEV="$RUN/dev-clone"           # the working copy on the AI-tools dev box
ADMIN="$RUN/admin-clone"       # the working copy on the canonical owner's box

step "Bootstrap upstream — bare git repo seeded with a README commit"
git init --bare --initial-branch=main "$UPSTREAM" > /dev/null
SEED="$RUN/_seed"
git clone "$UPSTREAM" "$SEED" > /dev/null 2>&1
(
    cd "$SEED"
    echo "# Dolt thing (authoritative upstream)" > README.md
    git add README.md
    git -c user.name=igor -c user.email=igor@example.com commit -m "initial" > /dev/null
    git push -u origin main > /dev/null
)
rm -rf "$SEED"

step "Bootstrap fork — mirror of upstream (what a GitHub 'Fork' button creates)"
git clone --mirror "$UPSTREAM" "$FORK" > /dev/null 2>&1

step "Upstream owner seeds the dolt database first, pushes to upstream"
ADMIN="$RUN/admin-clone"
mkdir -p "$ADMIN"
seed_items_repo "$ADMIN"
(
    cd "$ADMIN"
    dolt remote add origin "file://$UPSTREAM"
    dolt push -u origin main > /dev/null 2>&1
)
echo "(upstream now has refs/heads/main AND refs/dolt/data with the seed database)"

step "Inspect upstream — what refs exist"
echo "\$ git ls-remote file://$UPSTREAM"
git ls-remote "file://$UPSTREAM"

step "Fork is stale — still only has the pre-dolt seed README"
echo "\$ git ls-remote file://$FORK"
git ls-remote "file://$FORK"

step "Sync the fork from upstream (what GitHub does on 'Fork: Sync')"
git --git-dir="$FORK" fetch --all > /dev/null 2>&1
# A bare --mirror auto-updates refs/* from origin via fetch. Now fork mirrors upstream.
echo "\$ git ls-remote file://$FORK   (after fork sync)"
git ls-remote "file://$FORK"

step "===== DEV BOX (simulating idvorkin-ai-tools) ====="
step "Dev clones from upstream but will PUSH only to fork"
dolt clone "file://$UPSTREAM" "$DEV" > /dev/null 2>&1
(
    cd "$DEV"
    # origin = fork (write access), upstream = canonical (read access)
    dolt remote remove origin  # was set to upstream URL by clone
    dolt remote add origin "file://$FORK"
    dolt remote add upstream "file://$UPSTREAM"
    run dolt remote -v
)

step "Dev makes a data change — inserts a row, commits"
(
    cd "$DEV"
    run dolt sql -q "INSERT INTO items VALUES (42,'ai-row',1);"
    run dolt add items
    run dolt commit -m "ai-tools: add row 42"
)

step "Dev pushes to fork (origin). This updates fork's refs/dolt/data."
(
    cd "$DEV"
    run dolt push origin main 2>&1 | tail -3
)

step "===== OBSERVE: the fork now has new data; upstream does not ====="
step "Compare refs/dolt/data SHAs between fork and upstream"
FORK_DOLT=$(git ls-remote "file://$FORK" | awk '/refs\/dolt\/data/ {print $1}')
UP_DOLT=$(git ls-remote "file://$UPSTREAM" | awk '/refs\/dolt\/data/ {print $1}')
echo "fork     refs/dolt/data = $FORK_DOLT"
echo "upstream refs/dolt/data = $UP_DOLT"
[[ "$FORK_DOLT" != "$UP_DOLT" ]] && echo "(different — the database change landed on fork but NOT upstream)"

step "===== THE GITHUB PR PROBLEM ====="
step "If you opened a PR from fork->upstream, GitHub would compute the diff"
step "of refs/heads/main on both sides. Let's compute that diff."
FORK_MAIN=$(git --git-dir="$FORK" rev-parse refs/heads/main)
UP_MAIN=$(git --git-dir="$UPSTREAM" rev-parse refs/heads/main)
echo "fork     refs/heads/main = $FORK_MAIN"
echo "upstream refs/heads/main = $UP_MAIN"
if [[ "$FORK_MAIN" == "$UP_MAIN" ]]; then
    echo ""
    echo ">>> GitHub would show: 'There isn't anything to compare.' <<<"
    echo ">>> The diff view for the PR would be empty. <<<"
    echo ">>> The actual data change is invisible to GitHub's PR UI. <<<"
fi

step "===== WHAT CAN A GITHUB 'MERGE PR' BUTTON ACTUALLY DO? ====="
step "Simulate the merge: fast-forward upstream's refs/heads/main from fork's"
git --git-dir="$UPSTREAM" fetch "file://$FORK" refs/heads/main:refs/heads/main 2>&1 | tail -3 || true
echo "After GitHub-style merge:"
echo "\$ git ls-remote file://$UPSTREAM"
git ls-remote "file://$UPSTREAM"
echo ""
echo "Note: refs/dolt/data on upstream is STILL $UP_DOLT"
echo "      fork's refs/dolt/data is STILL $FORK_DOLT"
echo "      GitHub's merge operation only moved refs/heads/main."

step "===== WHAT WOULD IT LOOK LIKE IF ADMIN PULLED DATA LOCALLY? ====="
step "Upstream owner fetches from fork + merges + pushes back"
(
    cd "$ADMIN"
    dolt remote add fork "file://$FORK" 2>/dev/null || true
    run dolt fetch fork main
    run dolt merge fork/main --no-edit 2>&1 | tail -3 || true
    run dolt push origin main 2>&1 | tail -3
)
step "Now upstream has the AI-tools commit on BOTH refs"
UP_DOLT_NEW=$(git ls-remote "file://$UPSTREAM" | awk '/refs\/dolt\/data/ {print $1}')
echo "upstream refs/dolt/data was: $UP_DOLT"
echo "upstream refs/dolt/data now: $UP_DOLT_NEW"

step "Verify upstream has row 42"
(cd "$ADMIN" && dolt pull origin main > /dev/null 2>&1 || true)
run_sql "$ADMIN" "SELECT * FROM items WHERE id = 42;"

section "CONCLUSION"
echo "1. dolt remote add + fetch + push with multiple remotes works like git."
echo "2. A GitHub PR from fork -> upstream shows an EMPTY diff, because the"
echo "   web UI only looks at refs/heads/* which are typically identical."
echo "3. The GitHub 'Merge PR' button only fast-forwards refs/heads/main."
echo "   refs/dolt/data on upstream stays stale — the data change is LOST"
echo "   from upstream's perspective unless someone with upstream-write pulls"
echo "   locally and pushes refs/dolt/data up."
echo "4. For Igor's case (ai-tools has fork-write only), the admin (idvorkin)"
echo "   must pull from fork + dolt merge + dolt push upstream. No pure-"
echo "   GitHub workflow exists on vanilla refs. DoltHub solves this by"
echo "   making PRs dolt-aware."

echo ""
echo "=> Run tree: $RUN"
