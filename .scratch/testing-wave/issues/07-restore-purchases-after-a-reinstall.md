# 07: Restore purchases after a reinstall

**Status:** ready-for-agent
**Blocked by:** 03 (touches integration_test/flows/restore_purchases_flow_test.dart), 05.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete deletes the app, installs it again, signs in, and gets Pro back through Restore purchases if the app does not find it on its own.

**Decisions:** mp-494; approved as mp-627.

**Touches:** integration_test/flows/restore_purchases_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the paid account from ticket 05.
- [ ] After uninstall and reinstall, sign-in either opens the app or offers Restore; Restore opens it; RevenueCat shows no second purchase.

Next: /implement-lee testing-wave
