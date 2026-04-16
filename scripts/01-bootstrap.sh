#!/usr/bin/env bash
# 01-bootstrap.sh
# Single dolt repo: init, create table, insert rows, commit.
# Shows: dolt's basic "it's git for tables" loop.

set -euo pipefail
source "$(dirname "$0")/lib.sh"

section "SCENARIO 1 — bootstrap a dolt repo with one table"

RUN="$(reset_run_dir 01-bootstrap)"
cd "$RUN"

step "Initialize an empty dolt database (like 'git init')"
run dolt init --initial-branch main --name "Demo" --email demo@example.com

step "Create a table — this is SQL, stored in dolt's own chunk format"
run dolt sql -q "CREATE TABLE items (id INT PRIMARY KEY, name VARCHAR(64), qty INT);"

step "Insert three rows"
run dolt sql -q "INSERT INTO items VALUES (1,'apple',3),(2,'bread',1),(3,'cheese',2);"

step "dolt status — uncommitted rows show as a staged/unstaged SQL-level diff"
run dolt status

step "Stage and commit the table (same two-phase model as git)"
run dolt add items
run dolt commit -m "seed items"

step "Inspect the history — one commit, with the same shape as git log"
run dolt log --oneline

step "Query it — this is just SQL, the table round-trips through the commit"
run dolt sql -q "SELECT * FROM items;"

echo ""
echo "=> Repo lives at $RUN"
