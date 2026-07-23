# Local Edge Function Test Harness

This directory exists because CI and deploy workflows run edge-function tests
from `test/local_edge_functions`.

The actual tests live next to the Supabase functions and run with Deno:

```bash
npm test          # local tests only
npm run test:e2e  # local + remote E2E (needs env, see below)
```

Both delegate to `../../supabase/functions/run-algorithm-tests.sh`.

## Auto-discovery — no test list to maintain

The runner discovers **every** `*.test.ts` under `supabase/functions/`
(including `supabase/functions/tests/parity/`) with `find`. A new test file is
picked up with zero script edits — there is no hand-curated list, so a test
cannot be silently orphaned. The summary prints discovered vs run counts and
the script refuses to run if the buckets don't add up.

All local tests run with one permission superset:
`--allow-read --allow-write --allow-env --node-modules-dir=none`.
No local test needs `--allow-net` (AI-function tests stub `globalThis.fetch`);
if one ever does, add it to the `NET_ALLOWED` array at the top of the script
with a comment saying why.

The script exits non-zero if **any** discovered test fails.

## Remote / E2E classification

A test is classified REMOTE (mechanically, see `is_remote()` in the script) iff:

- its filename matches `*e2e*` or `*integration*`, **or**
- it reads `SUPABASE_ANON_KEY` via `Deno.env.get(...)` to hit a deployed
  `functions/v1` endpoint.

Remote tests run **only** under `--e2e` and require:

```bash
export SUPABASE_URL=https://<project-ref>.supabase.co
export SUPABASE_ANON_KEY=<anon-key>
```

Point these at **dev** unless you deliberately intend to exercise prod
(project refs are in `docs/deployment/README.md`). If `--e2e` is passed
without both env vars set, the run **fails** — a requested-but-not-run E2E
section is treated as a failure, not a skip.

## Quarantine

Known-broken tests live in the `QUARANTINE` array at the top of the runner,
one `"path|reason"` entry each. Quarantined files are excluded from the run
but are counted and printed on every invocation ("N quarantined: ..."), so the
debt stays visible. To un-quarantine: fix the test, delete its entry — the
auto-discovery picks it up again automatically.
