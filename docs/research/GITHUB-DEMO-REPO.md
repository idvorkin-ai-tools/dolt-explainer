# Reference GitHub repo — kept as history

The research session created `idvorkin-ai-tools/dolt-sync-test` to validate
that dolt syncs through GitHub. Igor opted to **keep it as permanent
reference history** rather than delete.

URL: https://github.com/idvorkin-ai-tools/dolt-sync-test

What it demonstrates, visible in the GitHub UI and via the API:

- The file browser shows only `README.md` — GitHub renders what's on
  `refs/heads/main`, and that only holds the seed commit.
- `git ls-remote https://github.com/idvorkin-ai-tools/dolt-sync-test.git`
  reveals the hidden ref: `refs/dolt/data` (where all Dolt's chunks,
  archives, and manifest actually live).
- `gh api repos/idvorkin-ai-tools/dolt-sync-test/git/refs` enumerates
  both refs.
- `dolt clone https://github.com/idvorkin-ai-tools/dolt-sync-test.git`
  round-trips the full database.

Scenario `06b-github-live.sh` uses this repo as the "it really works
through GitHub" demo. Scenario `06-github-illusion.sh` reproduces the
same illusion offline with a local bare git repo — use that as the
default; 06b is opt-in and requires `gh auth`.
