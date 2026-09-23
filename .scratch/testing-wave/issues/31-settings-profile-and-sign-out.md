# 31: Settings, profile and sign-out

**Status:** ready-for-agent
**Blocked by:** 03 (touches integration_test/flows/settings_sweep_flow_test.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete opens settings and profile, changes one setting and sees it kept after a relaunch, then signs out.

**Decisions:** approved as mp-651.

**Touches:** integration_test/flows/settings_sweep_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the entitled dev test account from the credentials file; no new account.
- [ ] The changed setting is checked by SQL and put back afterwards.

Next: /implement-lee testing-wave
