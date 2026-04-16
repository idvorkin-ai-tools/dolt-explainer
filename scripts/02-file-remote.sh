#!/usr/bin/env bash
# 02-file-remote.sh
# Two dolt clones synced through a shared file:// remote.
# Shows: dolt remote add / push / clone — the "one remote, two clones" loop.

set -euo pipefail
source "$(dirname "$0")/lib.sh"

section "SCENARIO 2 — one remote, two clones (file:// transport)"

RUN="$(reset_run_dir 02-file-remote)"
REMOTE="$RUN/remote-store"
REPO_A="$RUN/cloneA"
REPO_B="$RUN/cloneB"

step "Create the 'remote' — a dolt remote is actually a directory of chunks"
mkdir -p "$REMOTE"
echo "(the remote is just $REMOTE — no server, just a filesystem path)"

step "Clone A: initialize, seed, add the file:// remote"
mkdir -p "$REPO_A"; cd "$REPO_A"
seed_items_repo "$REPO_A"
run dolt remote add origin "file://$REMOTE"
run dolt remote -v

step "Push from Clone A — this materializes chunk files under $REMOTE"
run dolt push -u origin main

step "What does the remote look like on disk?"
run ls "$REMOTE"
# expect: manifest + a bunch of content-addressed files/dirs

step "Clone B: pull the whole database from file://$REMOTE"
run dolt clone "file://$REMOTE" "$REPO_B"

step "Verify Clone B sees the same table"
run_sql "$REPO_B" "SELECT * FROM items;"

echo ""
echo "=> Remote:  $REMOTE"
echo "=> Clone A: $REPO_A"
echo "=> Clone B: $REPO_B"
