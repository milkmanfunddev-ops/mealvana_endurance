# 30: The timeline and the fuelling plan show the week

**Status:** ready-for-agent
**Blocked by:** 03 (touches integration_test/flows/timeline_fuelling_flow_test.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete opens the timeline and a session's fuelling plan and sees the week's sessions and their fuelling as the dev database has them.

**Decisions:** approved as mp-650.

**Touches:** integration_test/flows/timeline_fuelling_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the entitled dev test account from the credentials file; no new account.
- [ ] The week's sessions on screen equal the planned activities by SQL.
- [ ] One session's fuelling numbers are recorded against its stored plan.

Next: /implement-lee testing-wave
