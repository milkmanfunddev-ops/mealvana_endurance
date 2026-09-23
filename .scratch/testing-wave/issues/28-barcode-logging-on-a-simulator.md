# 28: Barcode logging on a simulator

**Status:** ready-for-agent
**Blocked by:** 03 (touches integration_test/flows/barcode_scanner_entry_flow_test.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete opens barcode logging; the run finds out whether the simulator can scan anything, and either logs a product or records that the path needs a device.

**Decisions:** approved as mp-648.

**Touches:** integration_test/flows/barcode_scanner_entry_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the entitled dev test account from the credentials file; no new account.
- [ ] The existing barcode flow is run first.
- [ ] If scanning cannot work on a simulator, one followup-test Finding marks it for a device.

Next: /implement-lee testing-wave
