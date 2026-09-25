# 105: The Gate reads an expired or cancelled copy right

**Status:** done (wave 27, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Lee's rulings at wave 25 triage (2026-09-25, in the terminal).
1. **A cancel is seen before grace is given (87-006, app side only).** The 15-minute renewal grace (`kRenewalGrace`, mp-679) is only for a plan that will renew. At the copy's expiry the app fetches fresh customer info before granting grace; if RevenueCat says it won't renew (or the fetch shows it expired), the Gate closes at the end, not 15 minutes later. The Subscription screen fetches fresh customer info each time it opens, so a plan in its last period reads "Ends on <date>. It won't renew." (mp-558), never "Renews on". Server side: won't fix (the Test Store sends no CANCELLATION for its planned end; the App Store does).
2. **An expired copy is closed from the first answer (87-009).** On a cold launch the Gate's first answer applies the mp-666 rule to the saved copy: more than 15 minutes past its own expiry counts as closed, so the router goes straight to /paywall, never /main first. Startup waits for the Gate at most two seconds (mp-335); an offline fetch that has not answered by then does not hold the launch.

**Findings:** 87-006, 87-009. Retest ticket 107 closes them; this ticket does not.

**Decisions:** mp-335, mp-495, mp-558, mp-666, mp-679, and Lee's rulings above. No page writes.

**Touches:** lib/features/subscription/application/subscription_status_provider.dart, lib/features/subscription/application/pro_gate.dart, lib/features/subscription/domain/entitlement.dart, lib/features/subscription/data/subscription_service.dart, lib/features/subscription/application/subscription_screen_controller.dart, lib/features/subscription/presentation/pro_gate_redirect.dart, the startup wait for the Gate (lib/features/app_startup/)

- [x] Seam test through the real status notifier: a saved copy with `willRenew: true` past its expiry fetches first; a fresh answer of won't-renew closes the Gate at expiry with no grace.
- [x] Seam test: a cold start with a saved copy more than 15 minutes past expiry and a fetch that never answers gives a closed first answer within two seconds.
- [x] Controller test: opening the Subscription screen fetches fresh customer info, and a won't-renew plan reads "Ends on".
- [x] `flutter analyze` clean on touched files, the touched tests green.

Next: /implement-lee testing-wave
