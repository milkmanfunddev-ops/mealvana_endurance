# 12: The admin skips the paywall and the server still checks

**Status:** in-progress (wave 4, 2026-09-24)
**Blocked by:** 03 (touches integration_test/flows/admin_bypass_flow_test.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** test@test.com signs in on a fresh simulator and goes straight into the app with no paywall. When it tries an AI action, the server refuses it unless the account has a Pro subscription or a Grant, as mp-416 says, and the run records exactly what the athlete sees.

**Decisions:** mp-416; approved as mp-632.

**Touches:** integration_test/flows/admin_bypass_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Signs in as the admin from the credentials file on a freshly claimed simulator.
- [ ] No paywall at sign-in or on relaunch; `users.is_admin` is true by SQL; RevenueCat shows no active `pro` (or its current Grant, recorded).
- [ ] One AI action (a Vana message) is tried; the server's answer and the screen are recorded; anything other than mp-416 is a Finding.

Next: /implement-lee testing-wave
