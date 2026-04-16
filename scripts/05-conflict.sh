#!/usr/bin/env bash
# 05-conflict.sh
# A and B both mutate the SAME row — merge stalls with cell-level conflicts.
# Shows: dolt_conflicts_<table> is a real queryable table with base/our/their columns.

set -euo pipefail
source "$(dirname "$0")/lib.sh"

section "SCENARIO 5 — concurrent edits to the SAME row → cell-level conflict"

RUN="$(reset_run_dir 05-conflict)"
REMOTE="$RUN/remote-store"
REPO_A="$RUN/cloneA"
REPO_B="$RUN/cloneB"

mkdir -p "$REMOTE" "$REPO_A"
seed_items_repo "$REPO_A"
(cd "$REPO_A" && dolt remote add origin "file://$REMOTE" && dolt push -u origin main) > /dev/null
dolt clone "file://$REMOTE" "$REPO_B" > /dev/null

step "Both clones see row 1: apple qty=3"
run_sql "$REPO_A" "SELECT * FROM items WHERE id=1;"

step "Clone A changes qty for apple to 99 (commits, does not push yet)"
(
    cd "$REPO_A"
    dolt sql -q "UPDATE items SET qty=99 WHERE id=1;"
    dolt add items
    dolt commit -m "A: bump apple to 99"
) > /dev/null

step "Clone B changes qty for apple to 50; pushes first"
(
    cd "$REPO_B"
    run dolt sql -q "UPDATE items SET qty=50 WHERE id=1;"
    run dolt add items
    run dolt commit -m "B: bump apple to 50"
    run dolt push origin main
)

step "A pulls — merge stops, conflicts reported"
set +e
(cd "$REPO_A" && dolt pull origin main 2>&1)
set -e

step "Conflict is stored as a QUERYABLE SQL TABLE — dolt_conflicts_items"
run_sql "$REPO_A" "SELECT * FROM dolt_conflicts_items;"

step "Columns: base_* (common ancestor), our_* (our branch), their_* (incoming)"
run_sql "$REPO_A" "SHOW COLUMNS FROM dolt_conflicts_items;"

step "Resolve — take 'theirs' (use the value from Clone B's push, qty=50)"
(cd "$REPO_A" && run dolt conflicts resolve --theirs items)

step "After resolve: items row 1 has qty=50; conflicts table is empty"
run_sql "$REPO_A" "SELECT * FROM items WHERE id=1;"
run_sql "$REPO_A" "SELECT COUNT(*) AS remaining_conflicts FROM dolt_conflicts_items;"

step "Commit the merge and push — both clones now agree"
(cd "$REPO_A" && run dolt commit -am "merge: keep B's value")
(cd "$REPO_A" && run dolt push origin main)
(cd "$REPO_B" && run dolt pull origin main)
run_sql "$REPO_B" "SELECT * FROM items WHERE id=1;"

echo ""
echo "=> Conflict resolved via SQL. Run tree: $RUN"
