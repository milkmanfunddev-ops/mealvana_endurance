# 106: The paywall locks after a redeem, one Manage for both screens, no ended state

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Lee's rulings at wave 25 triage (2026-09-25, in the terminal).
1. **Redeem locks the paywall (87-001).** Ticket 45's purchase rule applies to a redeemed code: from the code's success until the app leaves the paywall, nothing on the paywall can start a purchase (Continue busy or disabled, plan tiles inert). Today Continue stays live for about 4 s under the "Code redeemed" snackbar.
2. **One Manage subscription (87-007).** The lapsed paywall's ⋯ → Manage subscription calls the same store-aware Manage as the Subscription screen (ticket 66): Apple's or Google's page when RevenueCat gives a management URL, the message for the store the plan came from otherwise. The paywall's fixed "App Store or Google Play" line (`paywall.manage_unavailable`) goes if nothing else uses it. Grep every Manage call site (Settings too) and list them in the report.
3. **No ended state (87-008).** mp-457 keeps a lapsed athlete on the full-screen paywall, so the Subscription screen's ended state (`PlanStatus.ended`, "It ended on <date>…", Upgrade) is unreachable. Remove it and its content keys. The SSOT pass later notes mp-495/mp-558's ended wording as superseded; no page writes now.

**Findings:** 87-001, 87-007, 87-008. Retest ticket 107 closes them; this ticket does not.

**Decisions:** mp-457, mp-495, mp-558, ticket 45 (05-004), ticket 66, and Lee's rulings above. No page writes.

**Touches:** lib/features/subscription/presentation/screens/paywall_screen.dart, lib/features/subscription/application/pro_paywall_controller.dart, lib/features/subscription/application/code_entry_controller.dart, lib/features/subscription/presentation/widgets/redeem_code_sheet.dart, lib/features/subscription/presentation/screens/subscription_screen.dart, lib/features/subscription/application/subscription_screen_controller.dart, lib/features/settings/presentation/screens/settings_screen.dart, lib/features/content/domain/content_keys.dart, assets/config/content_defaults.json

- [ ] Widget or seam test: after a successful redeem on the paywall, Continue cannot start a purchase until the route changes.
- [ ] Widget test: the lapsed paywall's Manage and the Subscription screen's Manage show the same result for the same plan's store.
- [ ] No `PlanStatus.ended` branch or ended-state content key remains; the Subscription screen's tests updated.
- [ ] `flutter analyze` clean on touched files, the touched tests green.

Next: /implement-lee testing-wave
