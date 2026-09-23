# 29: Cold start: every tab renders with a clean console

**Status:** ready-for-agent
**Blocked by:** 03 (touches integration_test/flows/smoke_tabs_flow_test.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The app starts cold, signs in, and every tab and its first screen render with no error or exception in the console.

**Decisions:** approved as mp-649.

**Touches:** integration_test/flows/smoke_tabs_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the entitled dev test account from the credentials file; no new account.
- [ ] Every console error or exception line is a Finding or listed as known noise with a reason.

Next: /implement-lee testing-wave
