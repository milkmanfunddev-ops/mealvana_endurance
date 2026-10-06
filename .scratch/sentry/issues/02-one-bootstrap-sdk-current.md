# 02: One bootstrap, SDK current

**What to build:** All four entry points call one `bootstrap(flavor)` that initialises Sentry in the documented shape (`appRunner` runs the app; no manual FlutterError or PlatformDispatcher handlers; no zone wrapper), so a crash arrives marked unhandled with the Flutter mechanism. The SDK moves to the latest stable 9.x (`sentry_flutter`, `sentry_drift`, add `sentry_supabase`, plugin to latest 3.x) with Supabase breadcrumbs and trace propagation on. A per-flavor table supplies DSN, environment, traces rate (prod 0.1, dev 1.0), replay (session 0 everywhere; on-error prod cohort only, dev 0), debug flag; the hardcoded prod DSN fallback is gone and a missing dev DSN disables Sentry locally instead of reporting to prod. Identity is the Supabase user id with a role tag and a device-id tag; no email; replay masks text and images. A `shorebird_patch` tag is read at startup. Web follows the same table. The content preload missing from the prod entry point is restored by construction.

**Blocked by:** 01 Report service exists

**Status:** built (2026-10-06, branch `sentry`); device checks owed to ticket 15

- [x] `pubspec` resolves the latest stable 9.x SDK packages and `sentry_supabase`; codegen and analyzer clean
- [x] One `bootstrap(flavor)`; the four `main*` files are thin; `SentryFlutter.init` uses `appRunner`, with no `runZonedGuarded`, `FlutterError.onError` or `PlatformDispatcher.onError` set by app code
- [x] (device, ticket 15, 2026-10-06) A forced crash in a dev build shows in the dev project with `handled: false` and mechanism `FlutterError` (event `dcbc87f1c3404011926d7e5b706dfaf8`)
- [x] No prod DSN literal remains in app code; a dev build with no DSN reports nothing and logs a Fault to the console
- [x] (device confirmed, ticket 15, 2026-10-06) Events carry `user.id` = Supabase user id, tags `role`, `device_id`, `shorebird_patch`; no email anywhere in an event; `sendDefaultPii` false
- [ ] (device, ticket 15, 2026-10-06) PostgREST `http` breadcrumbs confirmed on the dev events; `sentry-trace` / `traceparent` on the edge request headers still unverified (the edge wrapper attaches no request entry, so the headers are not visible from Sentry; needs an edge log line)
- [x] Full suite green

## Build notes (2026-10-06)

- SDK: `sentry_flutter`, `sentry_drift` 9.6.0 → 9.30.1; `sentry_supabase` 9.30.1 added;
  `sentry_dart_plugin` 3.1.1 → 3.4.0; `shorebird_code_push` 2.0.7 added for the patch tag.
  Rename fallout: `SentryLogAttribute` → `SentryAttribute`; the test flush is
  `options.telemetryProcessor.flush()` (the `logBatcher` is gone).
- `lib/shared/core/bootstrap/bootstrap.dart`: `bootstrap(AppFlavor)`. Shape is
  `SentryFlutter.init(options, appRunner: runMealvana)`; no `runZonedGuarded`, no
  `FlutterError.onError`, no `PlatformDispatcher.onError` anywhere in `lib/`
  (`test/shared/core/bootstrap/entry_points_test.dart` scans for all three and for any DSN
  literal). The four `main*.dart` are one line each.
- `sentry_flavor_settings.dart`: the per-flavor table, pure Dart, tested in
  `sentry_flavor_settings_test.dart`. dev: traces 1.0, replay 0, SDK debug on. prod: traces 0.1,
  on-error replay = the per-install cohort roll (prod release builds only). web: traces 0.1,
  replay 0; web traces follow `APP_ENVIRONMENT` (1.0 dev, 0.1 prod) as the old web entry did.
  Session replay 0 everywhere. Profiling left at the SDK default (off); the dead
  `AppConfig.enableSentryProfiling` flag is deleted.
- `sentry_event_filter.dart` and `sentry_replay_sampling.dart` moved from
  `lib/shared/services/sentry/` to `lib/shared/core/bootstrap/` (tests moved with them), so the
  SDK import outside `report/` lives in the bootstrap directory ticket 04 permits.
- DSN: both `AppConfig` fallbacks deleted (`fromEnv` → `''`, `fromDartDefines` → `''`). An empty
  DSN skips `SentryFlutter.init` and prints a `[bootstrap] FAULT` line. Safety nets checked:
  Codemagic's prod step already fails on a missing `SENTRY_DSN` in `.env.prod.local`
  (`codemagic.yaml` ~L344) and Vercel production carries `SENTRY_DSN` + `SENTRY_ENVIRONMENT`
  (set 202 days ago). `.env.dev.local` and `.env.prod.local` on this machine both have it.
- Supabase: `SentrySupabaseClient(enableBreadcrumbs: false, enableErrors: false, client:
  SentryHttpClient())`. The inner `SentryHttpClient` writes one `http` breadcrumb per request
  (REST, auth, storage, edge), keeps reporting failed requests as `SentryHttpClientError` (the
  event filter's weather rule depends on that) and stamps `sentry-trace`, `baggage` and, with
  `propagateTraceparent = true`, `traceparent` on every outgoing request. The outer supabase layer
  adds the `db.*` span per PostgREST call; its breadcrumbs and errors are off so nothing is
  recorded twice (review found the doubling).
- Identity: `Report.setUser(id, {role, deviceId})` now sets `device_id` as a tag;
  `clearUser` removes it. `lib/shared/services/report/report_identity.dart`
  (`syncReportIdentity(ref)`) resolves role via `CoachRepository.isUserApprovedCoach` and the
  device id from `DeviceInfoService` when initialised. Called from a new deferred startup step
  `deferred.report_identity` (after `deferred.coach_status`) and from the auth listener on
  sign-in and sign-out. The critical-path `setSentryUserContext` now only sets the Supabase user
  id (no plugin, no network) and clears it when nobody is signed in; it reports its own failure
  as Degraded instead of logging. `sendDefaultPii` false; replay masks text and images.
- `shorebird_patch` tag: read in `appRunner` via `ShorebirdUpdater().readCurrentPatch()`;
  `none` on the base build and web; a failed read is a startup Degraded. Deliberate exception to
  "recoverable init lives in the startup flow": the tag must be on the scope before the first
  event, and the read is a local FFI call, so it stays in the bootstrap (standards review raised
  it).
- `syncReportIdentity` leaves a breadcrumb when device info is not ready and the `device_id` tag
  is deferred (rule D9).
- `sentryNavigatorKey` (defined in `main.dart`, imported by the router, the root widget and the
  credits paywall) is now `appNavigatorKey` in the bootstrap.
- `enableTimeToFullDisplayTracing` on; `enableLogs` on; app-hang tracking off in debug.
- Web lost nothing: it had no app-hang switch, no breadcrumb filter, no cohort; the table and
  the one `_configureSentry` give it all three (replay stays 0, unsupported on web).

Owed to ticket 15 (device): forced crash arrives `handled: false`, mechanism `FlutterError`;
user id + `role` + `device_id` + `shorebird_patch` on an event; a PostgREST breadcrumb/span on a
dev event; `traceparent` visible in an edge request's headers.

## Code review (2026-10-06, Standards + Spec axes)

Fixed: web dev trace rate (was 0.1 for every web build); doubled breadcrumbs and spans from
stacking two Sentry HTTP layers; dead `enableSentryProfiling` config; D9 breadcrumb on the
deferred `device_id` tag; one access path to `Report` in the identity code; unused `flavor` field
on the settings row. Recorded, not changed: the Shorebird read in `appRunner` (above). Returning
sessions never emit `signedIn`, so identity for them rests on `deferred.report_identity`; do not
remove that step. The old `setSentryUserContext` tests (mock reporter, `anonymous` id, app
version) are replaced by three through a recording `Report`.

Full suite: 2 pre-existing failures unrelated to this ticket, `test/manual_live/
training_peaks_api_test.dart` (needs live credentials) and `test/shared/ci_config_contract_test.dart`
("unit tests must gate a push to develop"; `codemagic.yaml` untouched here).
