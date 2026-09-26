# 06: Delete the old eval system

**What to build:** The discard half of the redesign, done only once every Scenario has been
converted (ticket 04): delete the old trace harness (the server-side evals directory with its
runner and athlete profiles) and the repo-root evals directory (corpus JSON, load/dump/sample
scripts, generated review app); drop the dev-only `eval_traces` table with a migration; keep
the `onTrace` hook in the chat pipeline untouched — the deno test suite depends on it. The
Vana deno suite must be green after deletion, proving nothing depended on what was removed.

**Blocked by:** 04 (all twenty-two Scenarios converted — the JSON is the conversion source until then).

**Status:** ready-for-agent

- [ ] Old harness directories are gone; nothing in the repo references them
- [ ] A migration drops `eval_traces`; applied to dev
- [ ] The `onTrace` hook in the chat pipeline is untouched
- [ ] The full Vana deno test suite is green after the deletion
