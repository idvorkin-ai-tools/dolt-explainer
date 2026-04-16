#!/usr/bin/env bash
# run-all.sh — run every scenario in order, tee the combined transcript.
# Does NOT run 06b (live GitHub) by default — pass --live to include it.

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../runs/_transcript.txt"
mkdir -p "$(dirname "$OUT")"

LIVE=0
[[ "${1:-}" == "--live" ]] && LIVE=1

SCRIPTS=(01-bootstrap.sh 02-file-remote.sh 03-roundtrip.sh 04-clean-merge.sh 05-conflict.sh 06-github-illusion.sh)
(( LIVE )) && SCRIPTS+=(06b-github-live.sh)

: > "$OUT"
for s in "${SCRIPTS[@]}"; do
    echo "RUN: $s"
    "$HERE/$s" 2>&1 | tee -a "$OUT"
done

echo ""
echo "Combined transcript: $OUT"
