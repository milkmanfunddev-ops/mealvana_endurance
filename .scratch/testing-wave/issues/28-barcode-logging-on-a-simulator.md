# 28: Barcode logging on a simulator

**Status:** in-progress (wave 15, 2026-09-24)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete opens barcode logging; the run finds out whether the simulator can scan anything, and either logs a product or records that the path needs a device.

**Decisions:** none.

**Touches:** the dev test account's meal logs

- [x] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [x] Uses the entitled dev test account from the credentials file; no new account.
- [x] If scanning cannot work on a simulator, one followup-test Finding marks it for a device.

Next: /implement-lee testing-wave
