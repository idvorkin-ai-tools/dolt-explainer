#!/usr/bin/env bash
# 06-github-illusion.sh
# The killer demo: push a dolt database to a bare-git repo.
# GitHub's UI only renders refs/heads/main — which just holds the seed README.
# The actual database lives on refs/dolt/data, invisible to the web UI but
# fully fetchable via `dolt clone`.
# This scenario reproduces that illusion offline with a local bare git repo.

set -euo pipefail
source "$(dirname "$0")/lib.sh"

section "SCENARIO 6 — the 'empty GitHub repo' illusion (offline, bare-git)"

RUN="$(reset_run_dir 06-github-illusion)"
FAKE_GH="$RUN/fake-github.git"       # the 'GitHub' — a bare git repo
SEED_CLONE="$RUN/seed-clone"          # where we make the initial README commit
DOLT_REPO="$RUN/dolt-repo"            # our dolt working copy
RESTORED="$RUN/dolt-restored"         # proof dolt can round-trip the data

step "Create a bare git repo — this stands in for github.com/owner/repo.git"
run git init --bare --initial-branch=main "$FAKE_GH" 2>&1 | tail -2

step "Dolt REQUIRES at least one git commit on the remote before it will push."
step "Seed the 'GitHub' repo with a README (exactly what 'gh repo create --add-readme' does)"
run git clone "$FAKE_GH" "$SEED_CLONE" 2>&1 | tail -2
(
    cd "$SEED_CLONE"
    echo "# Dolt-backed repo" > README.md
    git add README.md
    git -c user.name=seed -c user.email=seed@example.com commit -m "initial" > /dev/null
    git push -u origin main > /dev/null
)
echo "(fake-github now has a single commit holding README.md)"

step "Build a dolt repo with our items table"
mkdir -p "$DOLT_REPO"
seed_items_repo "$DOLT_REPO"

step "Point dolt at the bare git repo. The .git suffix triggers dolt's git-mode."
cd "$DOLT_REPO"
run dolt remote add origin "file://$FAKE_GH"
run dolt remote -v
# Note: dolt rewrites file://...git as git+file://...git

step "Push the dolt database through git"
run dolt push -u origin main 2>&1 | tail -3

step "===== THE ILLUSION ====="
step "What 'GitHub UI' would show — only refs/heads/* counts for the file browser"
echo "\$ git --git-dir=$FAKE_GH log --oneline refs/heads/main"
git --git-dir="$FAKE_GH" log --oneline refs/heads/main
echo ""
echo "\$ git --git-dir=$FAKE_GH ls-tree refs/heads/main"
git --git-dir="$FAKE_GH" ls-tree refs/heads/main
echo "(GitHub users see: ONE file, README.md — the repo looks 'empty')"

step "But 'git ls-remote' (and GitHub's API) reveals the hidden ref"
echo "\$ git ls-remote $FAKE_GH"
git ls-remote "$FAKE_GH"
echo "(there it is — refs/dolt/data, same SHA family that dolt pushed)"

step "Peek inside refs/dolt/data — it's a commit whose tree is dolt's chunk store"
DOLT_REF=$(git --git-dir="$FAKE_GH" rev-parse refs/dolt/data)
echo "\$ git --git-dir=$FAKE_GH ls-tree $DOLT_REF"
git --git-dir="$FAKE_GH" ls-tree "$DOLT_REF"
echo "(manifest + .darc archive + content-addressed Noms chunks — opaque to git)"

step "===== PROVING IT ROUND-TRIPS ====="
step "Clone the bare-git URL with DOLT — it fetches refs/dolt/data and rebuilds the DB"
run dolt clone "file://$FAKE_GH" "$RESTORED" 2>&1 | tail -3
run_sql "$RESTORED" "SELECT * FROM items;"

step "Contrast: a vanilla 'git clone' fetches only refs/heads/main — README only"
VANILLA="$RUN/vanilla-git-clone"
run git clone "$FAKE_GH" "$VANILLA" 2>&1 | tail -2
run ls "$VANILLA"

echo ""
echo "=> The illusion is real. Run tree: $RUN"
echo "=> To see the same thing against the real GitHub repo, run 06b-github-live.sh"
