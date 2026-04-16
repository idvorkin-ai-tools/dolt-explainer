#!/usr/bin/env bash
# 06b-github-live.sh — same as 06 but against the REAL GitHub reference repo.
# Requires: gh auth status success, network.
# Uses the preserved reference repo at idvorkin-ai-tools/dolt-sync-test.

set -euo pipefail
source "$(dirname "$0")/lib.sh"

REPO="idvorkin-ai-tools/dolt-sync-test"
URL="https://github.com/$REPO.git"

section "SCENARIO 6b — same illusion, against the real GitHub repo ($REPO)"

if ! command -v gh > /dev/null 2>&1; then
    echo "ERROR: gh CLI not installed — skip."; exit 1
fi
if ! gh auth status > /dev/null 2>&1; then
    echo "ERROR: not authenticated to GitHub — run 'gh auth login' then retry."; exit 1
fi

RUN="$(reset_run_dir 06b-github-live)"

step "What GitHub's REST API reports about the repo's refs"
run gh api "repos/$REPO/git/refs" --jq '.[] | {ref, sha: .object.sha, type: .object.type}'

step "What git ls-remote sees — includes the hidden refs/dolt/data"
run git ls-remote "$URL"

step "What the GitHub file browser renders (refs/heads/main only)"
run gh api "repos/$REPO/contents" --jq '.[] | .name'
echo "(only README.md — repo looks empty to humans)"

step "dolt clone round-trips the database — pulls refs/dolt/data automatically"
run dolt clone "$URL" "$RUN/restored" 2>&1 | tail -3
run_sql "$RUN/restored" "SHOW TABLES;"
run_sql "$RUN/restored" "SELECT COUNT(*) FROM items;" || true

echo ""
echo "=> Live reproduction done. Clone: $RUN/restored"
echo "=> The repo is preserved at https://github.com/$REPO — open it in a browser"
echo "   and compare what you see to what 'git ls-remote' prints above."
