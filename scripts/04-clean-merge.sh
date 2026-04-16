#!/usr/bin/env bash
# 04-clean-merge.sh
# A and B each insert a different row. First push wins; second gets non-fast-forward.
# Shows: dolt's three-way merge for non-conflicting row-level edits.

set -euo pipefail
source "$(dirname "$0")/lib.sh"

section "SCENARIO 4 — concurrent inserts on DIFFERENT rows → clean three-way merge"

RUN="$(reset_run_dir 04-clean-merge)"
REMOTE="$RUN/remote-store"
REPO_A="$RUN/cloneA"
REPO_B="$RUN/cloneB"

mkdir -p "$REMOTE" "$REPO_A"
seed_items_repo "$REPO_A"
(cd "$REPO_A" && dolt remote add origin "file://$REMOTE" && dolt push -u origin main) > /dev/null
dolt clone "file://$REMOTE" "$REPO_B" > /dev/null

step "Clone A adds row id=10; commits locally; does NOT push yet"
(
    cd "$REPO_A"
    dolt sql -q "INSERT INTO items VALUES (10,'apricot',7);"
    dolt add items
    dolt commit -m "A: add apricot"
) > /dev/null
echo "(A has its own commit; remote unchanged)"

step "Clone B adds row id=20; commits; pushes first — wins the race"
(
    cd "$REPO_B"
    run dolt sql -q "INSERT INTO items VALUES (20,'banana',4);"
    run dolt add items
    run dolt commit -m "B: add banana"
    run dolt push origin main
)

step "Now A tries to push — rejected as non-fast-forward"
set +e
(cd "$REPO_A" && dolt push origin main 2>&1)
set -e

step "A pulls — dolt runs a three-way merge because the inserts don't overlap"
(cd "$REPO_A" && run dolt pull origin main)

step "A's table now has both new rows AND the original three"
run_sql "$REPO_A" "SELECT * FROM items ORDER BY id;"

step "A's history has a merge commit joining its branch and origin/main"
(cd "$REPO_A" && run dolt log --oneline --graph -n 6)

step "A pushes the merge; B pulls — both converge"
(cd "$REPO_A" && run dolt push origin main)
(cd "$REPO_B" && run dolt pull origin main)
run_sql "$REPO_B" "SELECT * FROM items ORDER BY id;"

echo ""
echo "=> Merge resolved without human input. Run tree: $RUN"
