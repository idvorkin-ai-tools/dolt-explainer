# lib.sh — shared helpers for dolt scenario scripts
# sourced by each NN-*.sh scenario

set -euo pipefail

SCENARIOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNS_DIR="$(cd "$SCENARIOS_DIR/.." && pwd)/runs"

# pretty section header
section() {
    echo ""
    echo "================================================================"
    echo "  $*"
    echo "================================================================"
}

step() {
    echo ""
    echo "---- $* ----"
}

# echo command, then run it — so transcripts show intent + output
run() {
    echo "\$ $*"
    "$@"
}

# same but capture output through SQL pretty-print
run_sql() {
    local dir="$1"; shift
    echo "\$ (cd $dir && dolt sql -q \"$*\")"
    (cd "$dir" && dolt sql -q "$*")
}

# reset a scenario's run dir (idempotent re-runs)
reset_run_dir() {
    local name="$1"
    local dir="$RUNS_DIR/$name"
    rm -rf "$dir"
    mkdir -p "$dir"
    echo "$dir"
}

# scaffold a dolt repo with a sample `items` table + 3 rows.
# arg 1 = directory to init into (must already exist and be empty)
seed_items_repo() {
    local dir="$1"
    (
        cd "$dir"
        dolt init --initial-branch main --name "Demo" --email demo@example.com > /dev/null
        dolt sql -q "CREATE TABLE items (id INT PRIMARY KEY, name VARCHAR(64), qty INT);"
        dolt sql -q "INSERT INTO items VALUES (1,'apple',3),(2,'bread',1),(3,'cheese',2);"
        dolt add items
        dolt commit -m "seed items"
    ) > /dev/null
}
