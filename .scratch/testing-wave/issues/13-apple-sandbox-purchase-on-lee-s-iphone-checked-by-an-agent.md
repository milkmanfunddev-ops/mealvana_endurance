# 13: Apple sandbox purchase on Lee's iPhone, checked by an agent

**Status:** ready-for-human
**Blocked by:** 05.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Lee installs a build that buys through Apple, not the Test Store, on his iPhone, and buys with a sandbox tester. An agent checks App Store Connect in the browser, RevenueCat by API and the dev database by SQL, and records whether all three agree.

**Decisions:** mp-289.

**Touches:** docs/release/sandbox-trial-runs/

**Follow-up tests that need a real device or store (Lee, 2026-09-25, cap of ten lifted for this pass):** 20-006 (Checked items offline with real airplane mode on a device, where the connectivity check also says offline), 28-003 (Barcode scanning needs a device: scan a product from Log a meal and Build a meal and check the logged row), 07-006 (Restore after a reinstall with a real store receipt, where sign-in does not find Pro on its own), 09-012 (No CANCELLATION event reached the webhook when the Test Store turned auto-renew off at the fourth renewal; check the cancel-then-run-out path with a store that can cancel), 08-003 (Manage subscription for a Test Store subscription opens Safari on Apple's account sign-in page, where the subscription cannot be managed). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md` like the retests.

- [ ] Status ready-for-human: Lee buys; the agent checks.
- [ ] The sandbox tester is added to the credentials file.
- [ ] RevenueCat shows the App Store purchase; the dev webhook's handling of it (dev drops real production events) is recorded; App Store Connect's sandbox view is checked through the browser.
- [ ] The run is written up beside the earlier sandbox trial runs and any disagreement is a Finding.

Next: /implement-lee testing-wave
