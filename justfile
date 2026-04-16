# dolt-explainer tasks

default:
    @just --list

# Run all scenarios end-to-end (offline)
run-all:
    ./scripts/run-all.sh

# Wipe materialized run state
clean:
    ./scripts/clean.sh

# Regenerate transcripts/ from a fresh scenario run (strips ANSI codes)
rebuild-transcripts:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p transcripts
    for s in 01-bootstrap 02-file-remote 03-roundtrip 04-clean-merge 05-conflict 06-github-illusion; do
        echo "--- $s ---"
        ./scripts/$s.sh 2>&1 | sed -r 's/\x1b\[[0-9;]*[mGKH]//g' > transcripts/$s.txt
    done

# Re-render all PlantUML diagrams/*.puml -> diagrams/*.svg
build-diagrams:
    plantuml -tsvg diagrams/*.puml

# Serve index.html locally for preview (port 8000)
serve:
    python3 -m http.server 8000

# Open the deployed Pages URL
open-live:
    open https://idvorkin-ai-tools.github.io/dolt-explainer/
