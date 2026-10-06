# Error reporting and Sentry

Every error, warning and silent-path note leaves the app through one service, `Report`. Edge
functions report through one wrapper. Both write to the same two Sentry projects. Nothing else is
a sink for errors: there is no separate logger, debug logger or Sentry wrapper.

Vocabulary (Report, Fault, Degraded, Note, Expected failure, Silent path) is defined in
`CONTEXT.md` § Error reporting. Rule D9 in `CLAUDE.md` is the standing rule this implements. The
design record is `.scratch/sentry/spec.md`.

## Which call to make

| Situation | Call | What Sentry gets |
|---|---|---|
| Something broke that should never break (unexpected exception, failed upload, payment mismatch) | `report.fault(error, stackTrace: st, area: 'sync')` | event, level `error`; Mixpanel `error_reported` |
| An expected but bad condition the app lives with (offline, timeout, expired session, cancelled sign-in) | `report.degraded(error, stackTrace: st, area: ...)` | event, level `warning`; Mixpanel `error_reported` |
| A silent path took a branch (early return, skipped step, guard bail) | `report.note('Push: no app id, skipping init', area: 'push')` | breadcrumb on the next event; a `warning` event of its own in `startup`, `push`, `payments`, `sync` |
| Narrative worth reading next to an error | `report.info(message, area: ..., data: {...})` | structured log |
| Developer narrative | `report.debug(message, ...)` | structured log |
| A trail marker with no severity meaning | `report.breadcrumb(message, category: ...)` | breadcrumb |
| The error should leave the block | `rethrow` | nothing here; the caller owns it |

Rules that follow from the table:

- Call `fault` when unsure. If the error matches the expected-failure allow-list
  (`lib/shared/services/report/expected_failures.dart`), `Report` downgrades it to Degraded and
  tags it `expected_failure:<reason>`. Test-runner failures (`TestFailure` and friends) are
  dropped. A call site never has to decide what is noise.
- `info` and `debug` are not reports. A catch block that only calls them is a silent path, and the
  source guard rejects it.
- `area` is lower-cased before it is sent. Use it consistently; it becomes the `area` tag and the
  Mixpanel property.
- Optional arguments on `fault` and `degraded`: `tags` (searchable), `extra` (sent as the
  `diagnostic` context), `message` (event message), `fingerprint` (grouping).
- Mixpanel receives `severity`, `area`, `exception_type` and `sentry_event_id`. No message text.

### One error, one event

`Report` remembers each error object it has captured, by identity. A repository that Faults and
rethrows, the controller that catches the same object, and the Riverpod observer all see one
object; only the first capture becomes an event, and the later ones leave a breadcrumb. So report
where you have the most context and rethrow freely. Primitives (a thrown `String`) cannot be
tracked and are never deduped.

### Riverpod failures

`SentryProviderObserver` (`lib/shared/services/sentry/sentry_provider_observer.dart`) is
installed on the root `ProviderScope`. It turns every provider failure into a Fault, including
the `AsyncError` that `AsyncValue.guard` writes into a notifier's state. You do not need to report
a guarded error yourself. The observer:

- unwraps a `ProviderException` and reports the inner error with a `wrapped` tag, unless that
  object was already reported;
- dedupes within a session by provider name, exception type and message;
- records each retry attempt as a `riverpod.retry` breadcrumb and reports only when retries run
  out.

### Domain decoders

The domain layer may not depend on `Report` (`presentation -> application -> domain <- data`).
A pure decoder that tolerates a malformed stored value takes a `DecodeIssue` callback
(`lib/shared/domain/decode_issue.dart`), defaulting to `ignoreDecodeIssue`. The data layer
supplies the real one:

```dart
DecodeIssue get _onIssue => _report.decodeIssue('meal_logging');
```

Each issue becomes a Degraded in that area.

## Getting a `Report`

Inject it. Providers and controllers read `reportProvider`; classes take it in the constructor.

```dart
@riverpod
MealLogRepository mealLogRepository(Ref ref) {
  return MealLogRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    report: ref.read(reportProvider),
  );
}
```

Code that already reads `appExternalDepsProvider` can use its `report` field; it is the same
instance.

`SentryReport.global` is the fallback for code with no injection point: static helpers, widgets
without a `ref`, and the bootstrap before the provider graph exists. Building `reportProvider`
points the global at the same instance, so both paths share one hub and one analytics fan-out.
Prefer injection whenever a `ref` or constructor is available.

`NoopReport` has the same interface and emits nothing.

## Testing with `RecordingReport`

`test/helpers/fakes/recording_report.dart` records every call and emits nothing. Override the
provider or pass it to the constructor, then assert on what was reported:

```dart
final report = RecordingReport();
final container = ProviderContainer(
  overrides: [reportProvider.overrideWithValue(report)],
);

// ... drive the code under test ...

expect(report.faults.single.area, 'sync');
expect(report.notes, isEmpty);
```

It exposes `calls`, `faults`, `degradeds`, `notes`, `userIds` and `cleared`. Each recorded call
carries `severity`, `error`, `message`, `area`, `tags`, `extra` and `data`.
`PerformanceTelemetry.reportOverride` takes the same fake for timing tests.

The service itself is tested with the SDK transport swapped for an in-memory one, in
`test/shared/services/report/report_test.dart`.

## The source guard

`test/shared/source_guard/report_source_guard_test.dart` reads every `lib/**.dart` file (generated
code and `lib/features/_archived/` excluded) and fails on three things:

1. **An unreported catch.** A catch block passes only if its text contains an escape (`rethrow`,
   `throw`, `Error.throwWithStackTrace(`) or a `Report` call (`.fault(`, `.degraded(`, `.note(`,
   `report.`, `_report.`, `Report.`). A catch that only logs with `info` or `debug` fails.
2. **A `print(` or `debugPrint(` inside a catch**, whether or not the block also reports.
3. **A Sentry SDK import** outside `lib/shared/services/report/` and `lib/shared/core/bootstrap/`.

The exact matching rules are at the top of `test/shared/source_guard/source_guard.dart`.

### Allowing a deliberate silent catch

Some catches are silent on purpose, for example Report's own sinks, which would recurse if they
reported. Add one line to the `## reasoned` section of `test/shared/source_guard/allow_list.md`:

```
unreportedCatch lib/path/to/file.dart :: } catch (_) { :: why this catch stays silent
```

- The signature is the trimmed source line holding the `catch` (or bare `on`) keyword, so line
  numbers can drift.
- Identical signatures in one file are counted: three silent catches need three lines.
- The reason is one line and must justify the silence. Adding one is a review decision.
- The `## baseline` section only shrinks. Never add to it. The test also fails on an entry that no
  longer matches a site.

## Identity

`syncReportIdentity` (`lib/shared/services/report/report_identity.dart`) runs from the startup
flow and again on each sign-in and sign-out. It sets:

- the Sentry user to the Supabase user id;
- a `role` tag, `athlete` or `coach`, from the coach lookup (left unset if the lookup fails,
  which is reported as Degraded);
- a `device_id` tag once device info is ready.

On sign-out it clears all three. No email is ever sent: `sendDefaultPii` is off, and replay masks
all text and images.

## The dev debug screen

In a dev-flavor build, tap the version text in Settings seven times (or mark the device
internal) to reveal the Developer / Tester section, then tap "Debug console" to open
`DebugScreen`. Prod builds have no entry point. Its log view reads
`ReportLog`, an in-memory ring of the last 500 lines that `Report` mirrored. Every `fault`,
`degraded`, `note`, `info` and `debug` call lands there with its level, area, data and error.
Nothing else writes to it. You can filter by level, copy to the clipboard, or clear it. It is a dev
convenience and does not count as a D9 channel.

### Proving the pipeline on a device

The screen's "Sentry pipeline" section (collapsed by default) fires one report of each class
through `ReportPipelineProbe` (`lib/features/settings/application/report_pipeline_probe.dart`).
Every probe lands in area `debug` with a `probe` tag, so the events are easy to find and never
mistaken for a real failure.

| Button | What it does | What to expect in the dev project |
|---|---|---|
| Throw a Fault | `report.fault(ReportProbeFault)` | one `error` event, tags `severity:fault`, `probe:fault` |
| Raise a Degraded | `report.degraded(ReportProbeDegraded)` | one `warning` event, `probe:degraded` |
| Note, then throw | `report.note(...)` then `report.fault(...)` | one `error` event whose breadcrumbs carry the `note.debug` crumb; no event for the Note itself (`debug` is not a promoted area) |
| Edge: bad payload | `functions.invoke('get-foods', body: 'not json')` | one event in environment `edge-dev` tagged `edge_function:get-foods`; the app records only a Note for the 400 |
| Crash (unhandled) | throws from the next frame, outside `Report` | one `error` event with `handled: false`, mechanism `FlutterError`; no Mixpanel fan-out |

Each Fault and Degraded also produces one Mixpanel `error_reported` event. In a dev build the
tracker is the no-op echo, so the event shows in the simulator console as
`📊 [ANALYTICS] error_reported {...}` rather than in Mixpanel. Every event should carry the Supabase
user id, the `role`, `device_id` and `shorebird_patch` tags, and a PostgREST breadcrumb trail; none
should have a replay attached. The run that first proved this, with event ids, is recorded in
`.scratch/sentry/issues/15-device-check-and-the-doc.md`.

## Bootstrap

All four entry points call `bootstrap(flavor)` (`lib/shared/core/bootstrap/bootstrap.dart`). It
runs `SentryFlutter.init(options, appRunner: ...)` and installs no error handler of its own; the
SDK marks crashes unhandled with the Flutter mechanism.

Per-flavor settings come from one table in `sentry_flavor_settings.dart`:

| Flavor | DSN source | Traces | Replay on error | SDK debug |
|---|---|---|---|---|
| dev | `.env.dev.local` | 1.0 | never | on |
| prod | `.env.prod.local` | 0.1 | per-install cohort | off |
| web | `--dart-define` | 1.0 dev, 0.1 prod | never | off |

- No fallback DSN. An empty DSN disables Sentry for that run and prints a console line, so dev
  events can never land in the prod project.
- Environment comes from `SENTRY_ENVIRONMENT`, falling back to `development` or `production`.
- Release is `mealvana_endurance@<version>+<build>`, dist is the build number, and every event is
  tagged `shorebird_patch` (`none` on a base build).
- Whole-session replay is off everywhere.
- Structured logs are on. Supabase calls are breadcrumbs and spans (`SentryHttpClient` inside
  `SentrySupabaseClient`), Drift statements are spans, and outgoing requests carry
  `sentry-trace`, `baggage` and `traceparent`.

`beforeSend` is `filterSentryEvent` (`sentry_event_filter.dart`), the same for every flavor:

1. Drop test-runner failures.
2. Downgrade expected failures that reached the SDK without passing through `Report` (SDK HTTP
   errors, uncaught throws) to `warning`, tagged `expected_failure`. SDK-reported failures of
   `get-weather-forecast` are downgraded as `handled_fallback`, because the caller substitutes a
   default forecast. A 502 from `garmin-backfill` or `kroger` is `upstream_unavailable` (the
   function's upstream, Garmin or Kroger, failed and said so), and a 504 from any Supabase
   endpoint is `gateway_timeout`. Both also carry `http_endpoint:<function or table>`. Every other
   SDK-reported 5xx stays a Fault (`classifyHandledHttpFailure`, ticket 19).
3. In release builds, drop `debug` and `info` events, except those tagged `metrickit`. Structured
   logs are not events and pass untouched.

## Telemetry that is not an error

**Slow steps.** `PerformanceTelemetry.measure` and `recordDuration`
(`lib/shared/services/report/performance_telemetry.dart`) record each step as a `perf.step` span
with a duration measurement, plus a breadcrumb. A step over 2 s makes the breadcrumb a warning.
A step over 10 s also sends one Degraded event, once per step per process, fingerprinted by step
name. A local database reset is always a Degraded event.

**MetricKit (iOS).** `ios/Runner/MetricKitReporter.swift` buffers Apple MetricKit payloads until
Dart is ready, then hands them to `MetricKitRelay`
(`lib/shared/services/report/metrickit_relay.dart`):

- A metric payload (daily CPU, energy, launch and hang aggregates) becomes a structured log via
  `Report.info`, flattened into attributes.
- A diagnostic payload (CPU exception, hang, disk-write exception, crash, with native stacks)
  becomes a Degraded warning event tagged `metrickit:diagnostic`. Filter the issue stream by the
  `metrickit` tag.
- If the native reporter is missing, the relay leaves a `startup` Note.

MetricKit only delivers on real devices, at most once a day for metrics. It is native code: it
ships in a real build and cannot be Shorebird-patched. It is not consent-gated; it is stability
data about our own code. `MetricKitReporter.swift` is wired into
`Runner.xcodeproj/project.pbxproj` by hand. A native file missing from the target fails only at
the build step with "Cannot find X in scope".

## Edge functions

`supabase/functions/_shared/sentry.ts` wraps every function:

```ts
import { initSentry, withSentry } from "../_shared/sentry.ts";
initSentry();
serve(withSentry("my-function", async (req) => { ... }));
```

Per request the wrapper runs under its own `withIsolationScope`, tags `edge_function`, `method`
and `component: edge_function`, captures an exception that escapes the handler (answering 500),
and flushes before returning.

- Same two Sentry projects as the app. Environment is `edge-dev` or `edge-prod` from the
  `SENTRY_ENVIRONMENT` secret. Traces sample rate is 0. With no `SENTRY_DSN`, every call is a
  no-op.
- `_shared/responses.ts` reports for you: `serverError()` captures its error; `errorResponse()`
  captures when given a cause or a 5xx status, and leaves a breadcrumb for a 4xx with no cause.
- For other catches use `captureEdgeError`, `captureEdgeMessage` or `edgeBreadcrumb`.
- `_shared/sentry_coverage.test.ts` fails if any non-frozen function's `index.ts` does not enter
  through `withSentry` with its folder name, and drives each handler with a fake client to prove
  one capture per request.
- In dev, a request with the `x-sentry-probe` header set to the `SENTRY_PROBE_TOKEN` secret makes
  the wrapper throw, to prove the pipeline end to end.

## Sentry projects and alerts

Org `milkman-24`, free (Developer) plan. Prod project `mealvana-endurance`, dev project
`mealvana-endurance-dev`. The full record of settings, IDs and API calls is
`.scratch/sentry/issues/13-sentry-projects-configured.md` § Settings changed.

- **Prod alerts:** two email rules, "New issue" and "Regression", filtered to environment
  `production`, at most once per 24 hours per issue, sent to team `milkman`. Dev events never page.
- **Dev alerts:** none. Dev gets the weekly report only.
- **Both projects:** spike protection on; browser-extension and legacy-browser inbound filters on;
  digests at 30 min minimum, 60 min maximum.
- **No dev quota cap.** The plan offers no per-project cap. If dev threatens the shared quota,
  lower dev `sampleRate` in the app.
- **Cron monitor:** `raw-retention-sweep` on prod, `17 3 * * *` UTC, 30-minute margin.
- Issue alerts live in the workflow engine (`/organizations/milkman-24/workflows/`); the legacy
  `/rules/` endpoints return 404.

## Session replay: the per-install cohort

**Never set `onErrorSampleRate` to a fractional value.**

A non-zero `onErrorSampleRate` starts sentry-cocoa's recorder, which then runs for the whole
foreground session to keep a rolling 30 s buffer. The rate is rolled only at error time, to
decide whether to upload the buffer. So `0.1` costs all of the battery and keeps a tenth of the
replays. A beta tester's phone ran hot on `1.0` (2026-07-16). An A/B on the simulator measured
about 1.9x idle CPU with replay armed, with `SentrySessionReplay.takeScreenshot()` driven by a
display link on an idle app.

What the app does instead (`lib/shared/core/bootstrap/sentry_replay_sampling.dart`):

- `resolveReplayOnErrorSampleRate` rolls once per install and returns only `1.0` or `0.0`.
  `kReplayArmedCohortFraction` is 0.1. An armed install records and uploads on error; an unarmed
  one never starts the recorder.
- Prod only, release builds only. Off in debug builds and on web.
- Gated on analytics consent. An unconsented install is never armed and never assigned a cohort.
- To re-roll the fleet, bump the `_cohortKey` suffix. It is pure Dart, so it can ship in a
  Shorebird patch.
- Unarmed installs still attach a screenshot of the error moment, the stack trace and up to 100
  breadcrumbs.
- `test/shared/core/bootstrap/sentry_replay_sampling_test.dart` guards the 1.0-or-0.0 rule.

Revisit if upstream fixes the idle cost:
[sentry-cocoa#5263](https://github.com/getsentry/sentry-cocoa/issues/5263) (session replay
should use run-loop observers) and
[#6885](https://github.com/getsentry/sentry-cocoa/issues/6885) (closed as its duplicate). If the
idle cost goes away, return to a flat `1.0`.

## Debug symbols, mappings and source maps

The plugin (`sentry_dart_plugin`, `sentry:` block in `pubspec.yaml`) names no project on purpose.
`SENTRY_PROJECT` comes from the environment, and a run without it refuses instead of defaulting
to prod. The release name must match what the bootstrap reports,
`mealvana_endurance@<version>+<build>`, where `<build>` is the build number the cut actually used.
CI resolves it per cut; pubspec's own `+N` is not it. That mismatch is why releases such as
`1.29.0+6` sat empty while real events arrived as `1.29.0+148`, unreleased.

Where uploads run:

- **Codemagic, release workflows only** (`prod-ios`, `prod-android`, and the trigger-disabled
  `main-*`): the `&upload_sentry_symbols` step in `codemagic.yaml`. It fails the build on a
  missing `SENTRY_AUTH_TOKEN` or a failed upload. The develop auto-cut (`dev-ios`) and the dev
  lanes do not run it. `test/shared/ci_config_contract_test.dart` enforces both.
- **Android R8 mapping:** `sentry_dart_plugin` cannot upload `mapping.txt`. The Sentry Gradle
  plugin in `android/app/build.gradle.kts` runs in UUID-only mode. The Codemagic step reads the
  UUID from the bundle's `sentry-debug-meta.properties` and runs
  `sentry-cli upload-proguard --uuid`. Check Project Settings, ProGuard in Sentry after a release
  cut.
- **Web source maps:** `scripts/build_web.sh` builds with `--source-maps`, uploads when the Vercel
  project carries `SENTRY_AUTH_TOKEN` and `SENTRY_PROJECT`, then deletes `build/web/*.map`. Without
  the token it logs and skips.
- **After a Shorebird patch:** a patch is a new Dart snapshot with new symbols. Run the command
  below from the backport worktree once the patch has shipped.

One-off, local or post-patch upload:

```bash
# From the tree the build came from, after the build (dSYM in build/ios/archive,
# Android symbols in build/app/intermediates). Token: ~/.sentryclirc [auth] token,
# or the Codemagic mealvana_prod group's SENTRY_AUTH_TOKEN.
export SENTRY_AUTH_TOKEN=<token>
export SENTRY_PROJECT=mealvana-endurance        # or mealvana-endurance-dev
export SENTRY_RELEASE=mealvana_endurance@1.29.0+148   # the build's own number
export SENTRY_DIST=148
dart run sentry_dart_plugin
```

## Related docs

- Console output in debug builds: `docs/technical/logging-service.md`
- `docs/technical/README.md`
- `docs/deployment/README.md`
