# 07: Restore purchases after a reinstall

**Status:** in-progress (wave 6, 2026-09-24)
**Blocked by:** 03 (touches integration_test/flows/restore_purchases_flow_test.dart), 05.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete deletes the app, installs it again, signs in, and gets Pro back through Restore purchases if the app does not find it on its own.

**Decisions:** mp-494; approved as mp-627.

**Touches:** integration_test/flows/restore_purchases_flow_test.dart

- [x] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [x] Signs up its own account at a new plus address, logs it in the credentials file, and buys Pro Monthly through the Test Store at the start, the way ticket 05 did (its run notes have the steps). The Test Store monthly renews every 5 minutes and lapses about 25 minutes after purchase (05-003), so the paid checks are done within 20 minutes of buying; a lapse before they finish is written down in the run notes, not worked around. The account is deleted in the app at the end (a failed delete is a Finding).
- [x] After uninstall and reinstall, sign-in either opens the app or offers Restore; Restore opens it; RevenueCat shows no second purchase.

Next: /implement-lee testing-wave
