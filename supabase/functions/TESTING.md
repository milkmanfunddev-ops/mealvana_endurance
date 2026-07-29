# Edge Function Testing

The tests live next to the Supabase functions (`*.test.ts`, Deno) and run via
the auto-discovery runner:

```bash
bash supabase/functions/run-algorithm-tests.sh          # local tests only
bash supabase/functions/run-algorithm-tests.sh --e2e    # + remote E2E (needs env, see below)
```

This is what CI runs (the `run_algorithm_tests` step in `codemagic.yaml`
pr-validation and the self-hosted GitHub workflow). An old npm shim at
`test/local_edge_functions/` used to wrap this script; it was never wired into
CI and now lives in `_archived/test/local_edge_functions/`.

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
