# 15: Device check and the doc

**What to build:** The debug screen, behind the existing admin gate, has four buttons: throw a Fault, raise a Degraded, record a Note then throw, and call an edge function with a bad payload. Run on the simulator against dev, all four arrive in the dev project within a minute with the right level, the user id and role, the breadcrumb trail, no replay, and the Mixpanel `error_reported` event; the edge one arrives under `edge-dev`. The Sentry integration doc is rewritten for `Report`, the ladder, the allow-list, the guard and the settings. The QA-seed failures seen in the dev project (users RLS 42501, qa-seed uuid upload) are written to the SSOT review queue for the QA repo.

**Blocked by:** 10 Contract; 12 Edge functions report

**Status:** built (2026-10-06, branch `sentry`); see build notes for the one unverified item

- [x] Four buttons exist on the debug screen (plus a fifth, the unhandled crash owed by ticket 02), visible only in the dev flavor, behind the Developer / Tester gate
- [x] The ticket records four dev-project event ids with level, user, breadcrumbs and environment as expected; replay count unchanged. The Mixpanel fan-out was seen as the dev build's console echo (dev never instantiates the Mixpanel tracker), not as an event in Mixpanel; a prod-flavor build would be needed for that
- [x] The Sentry integration doc describes `Report`, the ladder, the allow-list, the guard test, the edge wrapper and the project settings, and names no deleted class
- [x] A review-queue entry exists for the QA-seed failures with the issue ids

## Build notes (2026-10-06, branch `sentry`, lead session)

**What was built.**
- `lib/features/settings/application/report_pipeline_probe.dart`: `ReportPipelineProbe` with
  `fault()`, `degraded()`, `noteThenFault()`, `edgeBadPayload()`; every report in area `debug`
  with a `probe` tag; custom `ReportProbeFault` / `ReportProbeDegraded` exception types so no
  allow-list entry downgrades them. The edge probe posts `'not json'` to `get-foods`, whose
  handler answers the parse failure through `errorResponse(..., 400, ..., cause)`, which
  captures; the app records only a Note for the 400 so the app project gets no second event.
  `reportPipelineProbeProvider` wires the real `Report` and the Supabase functions client.
- `DebugScreen`: a collapsed "Sentry pipeline" expansion tile with five buttons (the four of the
  ticket plus "Crash (unhandled)", which throws from the next frame outside `Report` so ticket
  02's `handled: false` check could run). The body became one `CustomScrollView` so the new
  section does not overflow the 600 px smoke-test viewport.
- **The gate was dead.** The triple-tap on the Profile & Preferences row never fired: the row's
  own `InkWell` won the gesture arena, so the outer `GestureDetector` never counted a tap and the
  first tap navigated to the profile screen (no "Settings tap detected" line ever reached the
  log). Replaced by a "Debug console" row inside the existing Developer / Tester section (seven
  taps on the version text, or auto-shown on an internal device). Triple-tap code removed.
- Found on the way, fixed because it blocked the run: `athleteZonesProvider` read `ref` after
  its first `await` (`ref.read(reportProvider)` for the decode-issue callback, introduced by the
  wave-3 migration), which threw `UnmountedRefException` and made the whole Settings screen show
  "Error loading settings" on every open. The read now happens before the await. This is one of
  ticket 18's cases; noted there.
- Tests: `test/features/settings/application/report_pipeline_probe_test.dart` (6, through
  `RecordingReport`) and `test/features/settings/presentation/screens/debug_screen_probe_test.dart`
  (2, buttons present and each one reaches `Report`). Settings smoke suite and the source guard
  still green.
- Doc: `docs/technical/sentry-integration.md` § The dev debug screen gained "Proving the pipeline
  on a device" (button table, expectations, Mixpanel echo in dev). The doc names no deleted class.
- Review queue: `.scratch/ssot/review-queue.md` (copied from `mealplanning`, where it lives;
  expect an add/add merge on `develop`, keep both) gained the DEV-4 / DEV-82 QA-seed entry under
  Miscellany.

**Device run.** iPhone 17 Pro simulator, dev flavor, signed in as the shared keychain account
(`test@test.com`, user `607f9dd5-6fa7-48ee-a628-720d4a0506a1`, a coach). Window
20:10:12Z to 20:10:51Z. Every event below carries `user.id` = that id, `role:coach`,
`device_id:608A0694…`, `shorebird_patch:none`, `environment:development`, no email, no replay.
Dev replay count 0 before and after (prod 5, untouched).

| Button | Event id | Issue | Level | Tags | Breadcrumbs |
|---|---|---|---|---|---|
| Throw a Fault | `e83e78f4daf540cd983e427b3320a940` | 7777383981 | error | `severity:fault` `area:debug` `probe:fault` | 72, incl. `http` (PostgREST) and `ui.click` |
| Raise a Degraded | `014ca122a5494847bc76889c2afae76e` | 7777384125 | warning | `severity:degraded` `probe:degraded` | 73 |
| Note, then throw | `71413287154e43188508192e86b43d5c` | 7777384314 | error | `probe:note_then_fault` | 75, incl. `note.debug` "Debug screen: note before the Fault"; no event for the Note itself |
| Edge: bad payload | `5e04bf5104474e5f94d83c0455c590c9` | 7777384506 | error | `environment:edge-dev` `component:edge_function` `edge_function:get-foods` `method:POST` | 2 (`console`); title `SyntaxError: Unexpected token 'o', "not json" is not valid JSON`; app side only the Note "edge probe refused as expected" (400) |
| Crash (unhandled) | `dcbc87f1c3404011926d7e5b706dfaf8` | 7777385161 | fatal | mechanism `FlutterError`, `handled: false` | 79 |

Mixpanel: dev builds use the no-op echo tracker, so the fan-out shows in the simulator console,
one line per Fault/Degraded: `📊 [ANALYTICS] error_reported {severity: fault, area: debug,
exception_type: ReportProbeFault, sentry_event_id: e83e78f4…}`, likewise `degraded` /
`ReportProbeDegraded` / `014ca122…` and `fault` / `71413287…`. The crash has no fan-out, as
designed.

Ticket 02's owed device checks, now done: forced crash `handled: false` + mechanism
`FlutterError` (fatal); `user.id`, `role`, `device_id`, `shorebird_patch` on every event; a
PostgREST call as an `http` breadcrumb on the dev events. **Unverified:** `traceparent` on the
edge request headers. The edge wrapper attaches no request entry to its event, so the headers
are not visible from Sentry; the edge event does carry a trace context
(`2d4771aecc0f49e78ff0cb2ab19d5084`). Checking it needs an edge log line or a header echo.

**Also seen on this run (for triage, not fixed here).** Startup on the dev build produced,
before any button: `DriftRemoteException` Fault in `activities`; two `DatabaseReset` Degradeds
in `database`; two `PostgrestException` Faults in `subscription` (`column
user_entitlements.entitlement does not exist`, the dev entitlements table shape); the
`athleteZonesProvider` UnmountedRefException (fixed above, event `242566ca993c4b738eb033a1174200b5`);
two `TrainingPeaksApiException` Degradeds in `training_peaks` (token expired, expected). The
`subscription` pair is a real dev-schema mismatch worth its own look.

**Build gotcha, written down so the next device run does not lose an hour.** `flutter run` for
the dev flavor failed with `Value of type 'Options' has no member 'experimental'` in
sentry_flutter 9.30.1's `SentryFlutter.swift`. The resolved sentry-cocoa was 8.58.4 and its Swift
interface declares the property; the culprit was a stale explicit-module cache in
`~/Library/Developer/Xcode/DerivedData/Runner-*/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules/Sentry-*.swiftmodule`
(dated 2026-09-26, no `experimental` symbol at all). Deleting that directory (plus `Sentry.build`
and `sentry_flutter.build` beside it) fixed the build. A direct `xcodebuild` with
`-derivedDataPath build/ios` succeeded all along, which is how the cache was isolated.

**Full suite (after the device run, flutter run stopped first).** `flutter test`: 5059 passed,
8 skipped, 2 failed, both pre-existing and unrelated: `test/manual_live/training_peaks_api_test.dart`
(live TrainingPeaks token expired, environmental) and
`test/shared/ci_config_contract_test.dart` "Unit tests / analyze / format must gate a push to
develop", which also fails against `develop`'s `codemagic.yaml` (four failures there): the test
still expects the run-on-every-push lane that Lee switched to PR-only on 2026-08-21. Worth a
ticket of its own to realign the contract test with the ruling.

## Code review (2026-10-06, Standards + Spec axes)

Fixed: hand-written `Provider` → `@riverpod` (FOA §4/§10); `EdgeProbeOutcome` is now a
three-state kind (refused / accepted / unreachable) instead of two fields that conflated two
states, and its copy moved out of the application layer into the screen; the `MaterialPageRoute`
push carries a route name; the Debug console row is shown only when `appEnvironment == 'dev'`
(story 49 says dev-only; neither the old triple-tap nor the first cut of this row checked the
flavor, so a prod build would have offered the crash button); the Mixpanel acceptance line now
says what was actually observed. Recorded, not changed: `_runProbe` uses `setState` around an
await like the screen's existing `_performSync` (dev-only screen, no controller); the probe
labels and result lines are hardcoded, the content system has no dev-screen strings. Scope beyond
the four buttons, each written up above: the fifth crash button (ticket 02's owed check), the
Developer / Tester entry point replacing the dead triple-tap, the `athleteZonesProvider` fix.
