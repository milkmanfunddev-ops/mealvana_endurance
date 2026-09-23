# 20: Checked items stay checked after a restart and offline

**Status:** ready-for-agent
**Blocked by:** 03 (touches integration_test/flows/shopping_check_persist_flow_test.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete checks items off, restarts the app and goes offline, and the items stay checked; when the network comes back the dev database agrees.

**Decisions:** mp-244; approved as mp-640.

**Touches:** integration_test/flows/shopping_check_persist_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the entitled dev test account from the credentials file; no new account.
- [ ] Network is cut on the simulator for the offline part; the method is written in the run notes.
- [ ] SQL shows the checked state once back online; nothing is lost or doubled.

Next: /implement-lee testing-wave
