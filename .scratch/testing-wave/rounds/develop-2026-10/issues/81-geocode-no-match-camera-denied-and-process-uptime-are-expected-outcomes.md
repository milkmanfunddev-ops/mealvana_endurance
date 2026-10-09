# 81: A place search with no match and a camera with access off are expected outcomes; process uptime counts from main()

**Status:** in-progress (wave 8, 2026-10-09)
**Labels:** fix, round:develop-2026-10, area:events, area:meal-logging, area:startup
**Branch:** `develop-next` (fix-wave worktree)
**Source:** Findings 69-003, 68-003, 67-005; TRIAGE.md rulings of 2026-10-09
**Blocked by:** nothing in code. Shares `content_keys.dart` and `content_defaults.json` with 82 (see Overlaps).
**Next:** `/testing-wave develop-2026-10` (fix wave 8)
**Model:** opus

Line numbers are from code at `84615131`. Read CLAUDE.md's D9 and `lib/shared/services/report/report.dart:14-27` and `:747-875` (`trackExpectedFailure`, `faultUnlessWeather`, `noteExpected`) first. This ticket follows ticket 55's pattern: an expected outcome becomes a `note` plus one `expected_failure {area, reason}` count through `noteExpected`. It never becomes `error_reported`.

Lee, 2026-10-09: "geocode no-match and camera-denied become `expected_failure` (areas location / meal_logging, reasons no_match / camera_permission_denied) with copy that says what happened and what to do (camera: 'Camera access is off; turn it on in Settings' via a content key, with the gallery untouched); process_uptime_ms comes from the real process start (a Dart-side timestamp taken in main() or the platform's process start time)."

## Findings

- **69-003 · A place with no geocode match faults to Sentry (area location).** Edit Event → Location, typed "tw69 unsaved". LocationIQ answered `NotFoundException (404): No location found: {"error":"Unable to geocode"}`. The console showed a red `⛔ [location] Error searching locations` box and `error_reported {severity: fault, area: location, exception_type: _Exception}` (23:30:44Z). This can happen on every no-match keystroke batch. Evidence: `runs/69/console-redacted.log` (line ~577, "Exception: Failed to search locations: NotFoundException (404)…"), `runs/69/h01-edit-back-no-prompt.png`.
- **68-003 · Camera with access off says "Could not access the camera or gallery." and sends degraded.** Camera access was revoked (`simctl privacy … revoke camera`), then Log a Meal → Describe → Camera. The snackbar does not say access is off or where to turn it on, and it names the gallery, which was not tapped. The console sent `error_reported {severity: degraded, area: meal_logging, exception_type: PlatformException}`, with the exception `PlatformException(camera_access_denied, The user did not allow camera access., null, null)` (`runs/68/console-redacted.log:482-494`). Evidence: `runs/68/06d-camera-after-revoke.png`.
- **67-005 · SlowOperation reports `process_uptime_ms` 6132 for a startup measured at 11860 ms.** `⚠️ [performance] Slow operation: startup.total` with `{duration_ms: 11860, process_uptime_ms: 6132}` (`runs/67/console-redacted.log:81-91`), also in dev Sentry (`runs/67/sentry-67.md`). An uptime shorter than a step inside it cannot be true.

## Fix

1. **Name the no-match at the repository (69-003).** From code: `LocationRepository.searchLocations` (`lib/shared/data/repositories/location_repository.dart:45-58`) catches everything and rethrows `Exception('Failed to search locations: $e')` (`:56`). That wrapper erases the type, so the Mixpanel line reads `_Exception`. The package throws `NotFoundException` for a 404 (`location_iq-1.1.4/lib/src/core/error/error_handler.dart:21-22`). The package's public library exports only its models (`location_iq.dart:14`, `export 'src/models/models.dart'`), so the type is reachable only through `package:location_iq/src/core/error/exceptions.dart`.
   - Add `class LocationNoMatchException implements Exception` at the foot of `location_repository.dart`, with `const LocationNoMatchException(this.query)` and a `toString`.
   - Import `package:location_iq/src/core/error/exceptions.dart show NotFoundException` with `// ignore: implementation_imports` and a one-line reason: the package exports no error types, and a type test survives obfuscation where a string match on `runtimeType` would not (`LocationIQException.toString` is itself built from `runtimeType`, `exceptions.dart:9-14`).
   - In `searchLocations`, add `on NotFoundException { throw LocationNoMatchException(query); }` before the general `catch`. The general catch stays.
   - `geocode` (`:63-70`) and `reverseGeocode` (`:75-88`) are not changed. From code, nothing in `lib/` calls `LocationService.geocodeAddress` or `reverseGeocodeCoordinates` (grep), so no run can reach them.
2. **The service notes it and answers "no match" apart from "failed" (69-003).** From code: `LocationService.searchLocations` (`lib/shared/services/location_service.dart:278-293`) turns every throw into `_report.fault(… area: 'location', message: 'Error searching locations')` and returns `[]`. That is the red box and the `error_reported` fault.
   - Give `LocationService` an optional `AnalyticsTracker? analytics` (constructor `:39-40`). The provider body (`:23-29`) passes `analytics: ref.read(analyticsTrackerProvider)` (`lib/shared/services/analytics/analytics_tracker.dart:419`). It does not go through `appExternalDepsProvider`, which also watches Supabase and SharedPreferences.
   - Change the return type to `Future<List<LocationIQAutocompleteResult>?>`. Add `on LocationNoMatchException` first: `await _report.noteExpected('Location search: no match', area: 'location', reason: 'no_match', analytics: _analytics); return const [];`. A real failure keeps its `fault` and now returns `null`, so a screen can tell "nothing matched" from "the search failed". `location` is not a promoted note area (`report.dart:41-46`), so `noteExpected` is allowed.
   - The provider's body changes, so `location_service.g.dart`'s debug hash changes. Run the unfiltered codegen.
3. **Edit Event says so under the field (69-003, the copy half of the ruling).** From code: `_searchLocations` (`lib/features/events/presentation/screens/event_form_screen.dart:399-426`) stores the results, and the dropdown shows only `if (_locationSearchResults.isNotEmpty)` (`:987`). A no-match today shows nothing, and the typed text is still saved as the location (`:576-578`, `:611-613`).
   - Add `bool _locationNoMatch = false`. Set it from the service's answer: `results != null && results.isEmpty`, and store `results ?? []`. Clear it everywhere the results are cleared: text change (`:383`), a new search starting (`:390`), focus lost (`:364`), a selection (`:437`) and `:287`/`:703`.
   - Under the field, when `_locationNoMatch && !_isSearchingLocation`, show one small line from the content system: `event_form.location_no_match` "No matching places. Check the spelling, or keep what you typed." The screen reads no content today (grep), so it reads `ref.read(contentServiceProvider)` and adds the import.
   - A failed search (`null`) shows no line. The fault is already written down.
   - `lib/shared/widgets/location_search_field.dart:95-109` is the only other caller of `searchLocations`. Nothing in `lib/` mounts it (grep `LocationSearchField(`). It changes only to compile: `_results = results ?? []`.
4. **Camera access off is an outcome with copy that says what to do (68-003).** From code: `_pickPhoto` (`lib/features/meal_logging/presentation/screens/log_meal_screen.dart:1979-2024`) catches every picker throw (`:1992-2011`), sends `degraded` (`:1994-2002`) and shows the hardcoded `'Could not access the camera or gallery.'` (`:2004-2008`).
   - Add a branch first in that catch: `source == ImageSource.camera && e is PlatformException && e.code == 'camera_access_denied'` (the code the run saw, `runs/68/console-redacted.log:482`). It calls `await ref.read(reportProvider).noteExpected('log meal: camera access off', area: 'meal_logging', reason: 'camera_permission_denied', analytics: ref.read(appExternalDepsProvider).analytics, data: {'method': method})`. Read both before the first `await`, as `:2014-2017` already reads the tracker. If mounted, it then calls `MealvanaSnackbar.showInfo(context, content.getValue(ContentKeys.mealLogDescribeCameraAccessOff))` and returns. There is no `degraded` and no `error_reported`.
   - New key `meal_log.describe.camera_access_off`, "Camera access is off. Turn it on for Mealvana in Settings.". It follows the ruling's words and the barcode scanner's existing wording (`barcode_scanner.permission_denied`, `content_defaults.json:355`).
   - **The gallery is untouched.** `photo_access_denied` and every other throw keep today's `degraded` and today's line (`photo_attached_analytics_test.dart:89-111` pins that path).
5. **Process uptime counts from `main()` (67-005).** From code: `PerformanceTelemetry._processUptime` is `static final Stopwatch _processUptime = Stopwatch()..start();` (`lib/shared/services/report/performance_telemetry.dart:35`). Dart initialises a static field lazily, so the clock starts at the class's first use. `startup.total` starts its own stopwatch earlier, in `AppStartup.build` (`lib/features/app_startup/application/app_startup_provider.dart:152`), and records at `:336-340`. The uptime therefore comes out shorter than the step.
   - Replace the field with `static Stopwatch? _processClock;` and add `static void markProcessStart() => _processClock ??= Stopwatch()..start();`. Add a private getter `_uptimeMs => (_processClock ??= Stopwatch()..start()).elapsedMilliseconds`, so a test or an entry that never marks still gets a value. Use the getter at all three reads (`:112`, `:218`, `:238`). `debugReset` (`:267-270`) also sets `_processClock = null`.
   - Call `PerformanceTelemetry.markProcessStart()` as the first statement of `bootstrap()` (`lib/shared/core/bootstrap/bootstrap.dart:57-59`, before `SentryWidgetsFlutterBinding.ensureInitialized()`). All three entries reach `bootstrap` (`lib/main.dart:11`, `lib/main_dev.dart`, `lib/main_prod.dart`; `lib/main_web.dart:18`), so one call covers dev, prod and web. The bootstrap may import the Report layer (`sentryImportPermittedDirs`, `test/shared/source_guard/source_guard.dart:114-116`).
   - The field keeps the name `process_uptime_ms`. Its doc comment says it counts from the Dart entry (`main()`), so the engine's start before `main` (a few hundred ms) is not in it. Every step the app measures starts after `main`, so uptime is now at least any step's duration. A native process-start read (iOS `sysctl` `kp_proc.p_starttime`) would need a platform channel on both platforms. It is not done here (Decisions).

**Decisions.**
- The no-match test is on the package's own type through a `src/` import, not on text. The ignore comment carries the reason. If `location_iq` moves the file, the import fails at compile time, not silently at runtime.
- `searchLocations` answers `null` for a failure and `[]` for no match. Its two callers are listed. The weather service holds `LocationService` (`weather_service.dart:17`) but does not call `searchLocations` (grep).
- Edit Event gets a no-match line because the ruling asks for copy that says what happened and what to do. The location stays free text: what was typed is still saved.
- The camera line is an info snackbar, not an error: the athlete chose this, and the line tells them how to undo it. It has no "Open Settings" action. The barcode scanner's line has none either, and Questions asks about adding one.
- Uptime from `main()` is the ruling's first option and needs no platform code.

**Concurrency and refresh.**
- Two location searches in flight (the 500 ms debounce, `event_form_screen.dart:393-395`, can let an older one land late): each sets results and `_locationNoMatch` from its own answer, and the last write wins. That is today's behaviour for results. Each no-match notes once and counts once, which is accurate: each was a LocationIQ call.
- A no-match landing after the screen closed: `mounted` is checked before `setState` (`:404`). The note and count still go, and they are true.
- Camera tapped twice while the first picker throws: each throw notes and counts once and shows one bar, and the second bar replaces the first. The picker is modal, so a second tap cannot start while the first is open.
- `markProcessStart` twice (a hot restart reruns `main` in a live isolate): `??=` keeps the first mark, so uptime keeps counting from the first `main`, as a process clock should. A hot restart is debug-only.

## Touches

lib/shared/data/repositories/location_repository.dart
lib/shared/services/location_service.dart
lib/shared/services/location_service.g.dart (regenerated: the provider body's hash)
lib/features/events/presentation/screens/event_form_screen.dart
lib/shared/widgets/location_search_field.dart
lib/features/meal_logging/presentation/screens/log_meal_screen.dart
lib/features/content/domain/content_keys.dart
assets/config/content_defaults.json
lib/shared/services/report/performance_telemetry.dart
lib/shared/core/bootstrap/bootstrap.dart
test/shared/services/location_service_no_match_test.dart (new)
test/features/events/event_form_location_no_match_test.dart (new)
test/features/meal_logging/photo_attached_analytics_test.dart
test/shared/services/report/performance_telemetry_test.dart

14 files. `locationService` is `@riverpod`: its signature does not change, but its body does, so run the unfiltered codegen (`dart run build_runner build --delete-conflicting-outputs`) and check `git status` for deleted files. There is no Drift change and no edge function.

**Overlaps.** `content_keys.dart` and `content_defaults.json` are also in 82's Touches. Both tickets only add keys, in different sections: this ticket adds `meal_log.describe.camera_access_off` and a new top-level `event_form` section; 82 adds keys under `auth.login`, `ai_credits` and `food_search`. RUNBOOK #63 says two tickets whose Touches overlap never run in the same fix wave. The lead runs them one after the other or gives both to one agent. 72 and 73 (both fix wave 8) also name these two files, so the same applies to them. `log_meal_screen.dart` is not in 82 or 83: 82's empty-search fix lives in the shared `FoodSearchBar`. `event_form_screen.dart` is also named by 72 (event duplicates form guard), which is also marked fix wave 8. The two tickets edit different parts of the file (72 the save guard; this ticket the location search, `:361-440` and `:987`), but under #63 they still run one after the other, never side by side.

## Tests

Seam tests per `docs/test/README.md` § Seam tests: feed producer-shaped data, and test every controller write path through the real notifier.

- [ ] Unit (`location_service_no_match_test.dart`, new): the real `LocationService` over a `LocationRepository` subclass that overrides the `client` getter (`location_repository.dart:21`) with a mocktail `LocationIQClient` whose `autocomplete.suggest` throws the package's own `NotFoundException('No location found: {"error":"Unable to geocode"}')`, the producer's exact text from the run (test-side `src/` import with the same ignore). `searchLocations('tw69 unsaved')` returns `[]`. `RecordingReport` holds no fault and no degraded, and one `location` note with `expected_failure: no_match`. `RecordingAnalyticsTracker` holds exactly one `expected_failure {area: location, reason: no_match}` and no `error_reported`. A `ServerException`/plain `Exception` from the client returns `null` with exactly one fault, area location, and no count.
- [ ] Widget (`event_form_location_no_match_test.dart`, new, on the `event_form_back_button_test.dart` harness with `locationServiceProvider` overridden by the real service over that fake repository): type three or more letters and pump past the 500 ms debounce. The no-match line shows with the `event_form.location_no_match` default from content, and no dropdown. Type again: the line clears while searching. A failing repository: no line. Save after a no-match: the event's location is the typed text.
- [ ] Widget (`photo_attached_analytics_test.dart`, new case beside `:89`): Camera with the picker throwing `PlatformException(code: 'camera_access_denied', message: 'The user did not allow camera access.')`. The bar shows the `meal_log.describe.camera_access_off` default. `RecordingReport` holds no degraded and one `meal_logging` note. The tracker holds one `expected_failure {area: meal_logging, reason: camera_permission_denied}` and no `meal_ai_photo_attached`. The existing Gallery `photo_access_denied` case keeps its degraded and its old line unchanged.
- [ ] Unit (`performance_telemetry_test.dart`): after `debugReset`, call `markProcessStart()`, wait 60 ms (real time, `Future.delayed`), then `recordDuration('startup.total', 11 s)` with a `RecordingReport` override. The degraded's `extra['process_uptime_ms']` is ≥ 60 (before the fix, the clock started at that first use and read ~0). A second `markProcessStart()` keeps the first mark. With no mark, the payload still carries a non-negative `process_uptime_ms`.
- [ ] `flutter analyze` clean on every touched file. The one `implementation_imports` ignore is expected and commented.
- [ ] #116: before committing, `grep -rl` under `test/` for `LocationRepository`, `LocationService`, `searchLocations`, `locationServiceProvider`, `EventFormScreen`, `LogMealScreen`, `_pickPhoto`/`imagePickerProvider`, `PerformanceTelemetry`, `bootstrap(`, `ContentKeys` and `content_defaults`, and run every file named (at least `weather_service_test.dart`, `event_form_back_button_test.dart`, `event_form_goal_pace_by_sport_test.dart`, `describe_not_food_test.dart`, `describe_error_lines_wrap_test.dart`, `content_defaults_resolve_without_caller_test.dart`).
- [ ] #117: no new Report helper. The two new catch branches report through `noteExpected`, and each catch body also holds `_report.`/`.degraded(`, which `reportCalls` already matches (`source_guard.dart:91-110`). Run `test/shared/source_guard/` anyway, since catch bodies changed.
- [ ] #118: no expected outcome is written into notifier state. Both new outcomes are local `setState`/snackbar on screens.
- [ ] Codegen: unfiltered, once, for `location_service.g.dart`.

## Deploy

None. Client only.

## Retest

Next test wave, on a simulator (a rebuild is needed):
- **69-003:** Edit Event → Location, type a non-place ("tw69 unsaved"). The line "No matching places. Check the spelling, or keep what you typed." shows under the field, and the console has no `⛔ [location]` box and no `error_reported`. One `expected_failure {area: location, reason: no_match}` is tracked. A real place still lists suggestions.
- **68-003:** revoke camera (`xcrun simctl privacy <udid> revoke camera com.milkman.mealvanaendurance.dev`), relaunch, Log a Meal → Describe → Camera. The bar reads "Camera access is off. Turn it on for Mealvana in Settings.", the console has no `error_reported`, and there is one `expected_failure {area: meal_logging, reason: camera_permission_denied}`. Gallery with photos revoked still shows today's line.
- **67-005:** cold-launch the app and read any `performance` breadcrumb or SlowOperation in the console. Every `process_uptime_ms` is at least that record's `duration_ms` (for `startup.total` above all).

## Questions for Lee

1. Should the camera bar carry an "Open Settings" action (iOS opens the app's own Settings page)? The barcode scanner's line has none today. Recommended: not now. The line says where to go, and an action would need the same change on the barcode scanner to stay consistent.

**Rulings (Lee, 2026-10-09, wave 7 close).**
- Q1: no Open Settings action now; the copy says to turn it on in Settings and matches the scanner's line.
