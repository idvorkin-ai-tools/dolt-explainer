#!/usr/bin/env bash
# 03-roundtrip.sh
# Push from Clone B, pull in Clone A, see the change land.
# Shows: edits flow A → remote → B and back, via dolt push/pull.

set -euo pipefail
source "$(dirname "$0")/lib.sh"

section "SCENARIO 3 — edit in B, pull in A (round-trip through remote)"

RUN="$(reset_run_dir 03-roundtrip)"
REMOTE="$RUN/remote-store"
REPO_A="$RUN/cloneA"
REPO_B="$RUN/cloneB"

# Bootstrap: two clones sharing a file:// remote, seeded with items.
mkdir -p "$REMOTE" "$REPO_A"
seed_items_repo "$REPO_A"
(cd "$REPO_A" && dolt remote add origin "file://$REMOTE" && dolt push -u origin main) > /dev/null
dolt clone "file://$REMOTE" "$REPO_B" > /dev/null

step "Baseline: both clones see 3 rows"
run_sql "$REPO_A" "SELECT COUNT(*) FROM items;"
run_sql "$REPO_B" "SELECT COUNT(*) FROM items;"

step "In Clone B: insert a new row, commit, push"
(
    cd "$REPO_B"
    run dolt sql -q "INSERT INTO items VALUES (4,'dates',5);"
    run dolt add items
    run dolt commit -m "add dates"
    run dolt push origin main
)

step "In Clone A: still 3 rows (hasn't pulled yet)"
run_sql "$REPO_A" "SELECT COUNT(*) FROM items;"

step "In Clone A: pull — change arrives via the shared remote"
(cd "$REPO_A" && run dolt pull origin main)

step "Now Clone A sees 4 rows, including the row added in Clone B"
run_sql "$REPO_A" "SELECT * FROM items;"

step "dolt log in A shows Clone B's commit — with the SAME author metadata as on B"
(cd "$REPO_A" && run dolt log --oneline -n 3)

echo ""
echo "=> Round-trip complete. Run tree: $RUN"
