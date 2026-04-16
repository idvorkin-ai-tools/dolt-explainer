#!/usr/bin/env bash
# clean.sh — wipe all materialized runs, leave scripts intact.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RUNS="$HERE/../runs"
echo "Removing $RUNS/*"
rm -rf "$RUNS"
mkdir -p "$RUNS"
