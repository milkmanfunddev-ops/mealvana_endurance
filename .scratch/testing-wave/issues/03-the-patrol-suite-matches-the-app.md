# 03: The Patrol suite matches the app

**Status:** done (wave 3, 2026-09-24)
**Blocked by:** 01, 02 (touches integration_test/flows/).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Every existing Patrol flow is run on a simulator, outdated flows are brought up to the app as it is today, flows that hang are fixed or marked with a Finding, and the README and the self-hosted runner describe the suite correctly. The runner picks up every flow in the flows folder except a named list that spends on AI, so later tickets add a flow without editing the runner.

**Decisions:** none.

**Touches:** integration_test/flows/, integration_test/helpers/, integration_test/README.md, .github/workflows/tests-selfhosted.yml, docs/test/README.md

- [x] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [x] Each of the 25 flows is run once; each result (pass, fixed, Finding) is listed in the run folder.
- [x] Test code only: a flow that fails because the app changed is updated; a flow that fails because the app is wrong gets a Finding and stays red.
- [x] The README lists the real flows and helpers and the Patrol 4.10.0 / CLI 4.8.0 pair; the runner's install note says the same.
- [x] The runner globs the flows folder minus an AI-spend exclusion list and derives the expected count from it.
- [x] The old bug lists in the test docs are marked superseded by the Findings folder.

Next: /implement-lee testing-wave
