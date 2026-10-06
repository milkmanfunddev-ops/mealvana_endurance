# 09 part A: credits, subscription, push — sites

Scope: `lib/features/ai_credits/**`, `lib/features/subscription/**`,
`lib/shared/services/notification_service.dart`, `notification_intent_routes.dart`
(no catch blocks in the last one). 33 baseline lines deleted from
`test/shared/source_guard/allow_list.md`; no `## reasoned` entry added.

Areas: `credits` for wallet/ledger accounting, `payments` for RevenueCat and
purchase paths (Notes promote to warnings, intended), `subscription` for the
entitlements row and status resolve, `push` for OneSignal.

Legend: `Fault` auto-downgrades expected failures (offline, cancelled purchase,
store network) on its own. `Legacy` marks a non-catch call that moved from the
`sentryReporterProvider` / `AppLogger` aliases ticket 10 deletes.

## Sites

### lib/features/ai_credits/application/credits_controller.dart
- credits_controller.dart:72 — Fault (`credits`) — build fell through both repository guards; the zero shown is a stand-in. Asserted via RecordingReport in `credits_controller_test` ("a throwing repository degrades to zero").
- credits_controller.dart:108 — Legacy → `report.debug` — remote wallet update narrative, was a bare `debugPrint` outside any catch.

### lib/features/ai_credits/application/purchase_controller.dart
- purchase_controller.dart:144 — Legacy → Fault (`payments`) — purchase attempted with no signed-in user. Asserted via RecordingReport in `purchase_controller_test` ("no signed-in user → notSignedIn").
- purchase_controller.dart:157 — Legacy → breadcrumb (`payments`) — anonymous session blocked, an expected funnel step.
- purchase_controller.dart:195 — Legacy → Fault (`payments`) — store confirmed but the wallet never moved (highest-severity invisible failure).
- purchase_controller.dart:213 — Legacy → Fault (`payments`) — `AsyncValue.guard` caught a store/SDK error during buy. Note for review: the Riverpod observer (ticket 03) also sees this `AsyncError`; the explicit Fault keeps the sku tags, so left as is.
- purchase_controller.dart:246 — Note (`payments`, promoted) — pre-purchase balance unread, assuming 0; was an empty `catch (_)`. Can only over-report "credited", never hide a charge.
- purchase_controller.dart:286 — Note (`credits`, breadcrumb only) — one poll attempt failed; a later attempt may succeed and exhaustion is the caller's Fault. `debugPrint` removed.
- purchase_controller.dart:275, :303 — Legacy → breadcrumb (`credits`) — poll succeeded / poll exhausted, were `debugPrint`s outside any catch; the exhausted line now rides the caller's Fault.

### lib/features/ai_credits/data/credits_repository.dart
- credits_repository.dart:88 — Fault (`credits`) — `ensure-credits` edge call failed; a stale zero on screen, never a lost grant.
- credits_repository.dart:119 — Fault (`credits`) — `token_wallets` read failed; zero returned. Asserted via RecordingReport in `credits_repository_test` ("fetchWallet returns zero on exception").
- credits_repository.dart:162 — Fault (`credits`) — realtime payload did not parse; schema drift, not a network blip (keys attached).
- credits_repository.dart:198 — Fault (`credits`) — `token_ledger` read failed; empty ledger returned.

### lib/features/ai_credits/data/revenuecat_service.dart
Constructor now takes `Report? report` (was `SentryReporter sentry`); the `_report`/`_crumb` helpers' `debugPrint`s are gone, every catch calls `_r.fault` inline with `rc_operation` / `rc_store` tags. `revenueCatServiceProvider` lifecycle unchanged (keepAlive).
- revenuecat_service.dart:150 — Legacy → Fault (`payments`) — wrong-platform API key, RevenueCat disabled for the session.
- revenuecat_service.dart:186 — Fault (`payments`) — `Purchases.configure` threw.
- revenuecat_service.dart:212 — Fault (`payments`) — `Purchases.logIn` threw (a missed login credits nobody's wallet).
- revenuecat_service.dart:245 — Fault (`payments`) — `getOfferings` threw; null returned.
- revenuecat_service.dart:268 — Legacy → Fault (`payments`) — purchase attempted before configure.
- revenuecat_service.dart:282 — Fault (`payments`) — `PurchasesError` other than user-cancel; cancel stays a breadcrumb, and `fault` downgrades `purchaseCancelledError` / `networkError` itself if one ever reaches it.
- revenuecat_service.dart:298 — Fault (`payments`) — unexpected purchase error; the raw `PlatformException` cancel shape is still a breadcrumb first.
- revenuecat_service.dart:356 — Fault (`payments`) — `restorePurchases` threw.

### lib/features/subscription/application/subscription_status_provider.dart
- subscription_status_provider.dart:79 — Fault (`subscription`) — resolve failed, degrading to none / tester grant. Asserted via RecordingReport in `subscription_status_provider_test` ("build never throws").

### lib/features/subscription/application/pro_paywall_controller.dart
No catch blocks; converted off `sentryReporterProvider` so ticket 10 can delete it.
- pro_paywall_controller.dart:82 — Legacy → breadcrumb (`subscription`) — PRO_PURCHASE_ENABLED off.
- pro_paywall_controller.dart:92 — Legacy → Fault (`payments`) — pro purchase with no signed-in user.
- pro_paywall_controller.dart:100 — Legacy → breadcrumb (`subscription`) — anonymous session blocked.
- pro_paywall_controller.dart:129 — Legacy breadcrumb → Note (`payments`, promoted) — purchase completed but Pro not yet active: money moved, status did not; the one upgrade in this file.
- pro_paywall_controller.dart:140 — Legacy → Fault (`payments`) — guard caught a store/SDK error during buy.

### lib/features/subscription/data/subscription_service.dart
Constructor now takes `Report? report`; `_report` helper and both `debugPrint`s gone.
- subscription_service.dart:78 — Fault (`payments`) — `getCustomerInfo` threw; null returned.
- subscription_service.dart:148 — Fault (`payments`) — `restorePurchases` threw; null returned.

### lib/features/subscription/data/user_entitlements_repository.dart
Was not in the baseline (its catches used the `AppLogger` alias); converted per the brief's "while you are there" rule. Constructor now takes `Report? report` instead of `AppLogger logger`; provider no longer reads `deps.logger`.
- user_entitlements_repository.dart:87 — Degraded (`subscription`) — `users.is_internal` mirror failed; expected offline, retried on next resolve. Asserted via RecordingReport in `user_entitlements_repository_test` ("mirrorInternalFlag returns false on failure").
- user_entitlements_repository.dart:119 — Fault (`subscription`) — `user_entitlements` remote read failed (offline downgrades itself; RLS/shape is real).
- user_entitlements_repository.dart:148 — Fault (`subscription`) — Drift cache write failed after a good remote read.
- user_entitlements_repository.dart:191 — Fault (`subscription`) — Drift cache read failed.
- user_entitlements_repository.dart:207 — Fault (`subscription`) — Drift cache clear failed on sign-out.

### lib/shared/services/notification_service.dart
Static class: `static Report? _report` with `_r => _report ?? SentryReport.global` and `debugSetReport` as the test seam. Every LaunchTrail line is kept; Report is the PROD-readable half. No ordering or behaviour change.
- notification_service.dart:185 — Fault (`push`) — legacy iOS launch payload could not be read from prefs (tape line kept).
- notification_service.dart:223 — Note (`push`, promoted) — OneSignal init skipped, no app id yet: D9's founding case, now a warning event as well as a tape line. Asserted via RecordingReport in `push_arming_order_test`.
- notification_service.dart:315 — Fault (`push`) — `requestPermission` / opt-out heal threw; a valid-token device may stay unreachable. `debugPrint` removed.
- notification_service.dart:328 — Fault (`push`) — OneSignal init threw. `debugPrint` removed.
- notification_service.dart:445 — Fault (`push`) — login/logout alias sync threw (the `invalid_aliases` mechanism); `detach` flag attached. `debugPrint` removed.
- notification_service.dart:681 — Fault (`push`) — legacy iOS resume payload could not be read (tape line kept).
- notification_service.dart:717 — Fault (`push`) — explicit `requestPermission(true)` threw. `debugPrint` removed.

## Counts
- Catch blocks migrated: 33 (27 Fault, 1 Degraded, 2 Note, 0 Removed, 0 Reasoned) plus 3 catches in `user_entitlements_repository.dart` already counted above (they were alias-reported, not baseline).
  - By baseline: 22 unreportedCatch + 11 printInCatch lines deleted = 33.
- Non-catch legacy calls moved to Report: 15 (purchase_controller 6, revenuecat_service 2 + helpers, pro_paywall_controller 5, credits_controller 1, notification_service 1 new Note).
- Direct `package:sentry*` imports in scope: none before, none after.

## Tests touched
`credits_controller_test`, `purchase_controller_test`, `credits_repository_test`,
`revenuecat_service_test`, `subscription_status_provider_test`,
`subscription_service_test`, `user_entitlements_repository_test`,
`push_arming_order_test`. All green with the guard test (239 tests in the run).

## Left for others
- `test/shared/services/notification_push_identity_test.dart` runs against
  `SentryReport.global` with no injected fake; it passes, no assertion added
  (the sync step bails before any catch in a test binding).
- Duplicate-report question on `purchase_controller.dart:213` and
  `pro_paywall_controller.dart:140` (observer + explicit Fault) is a review call,
  not changed here.
