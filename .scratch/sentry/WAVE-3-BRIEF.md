# Wave 3 brief: migration tickets 05–09 (read fully before touching code)

Branch of record: `sentry`. Your worktree may have been created from `main`; FIRST run
`git fetch . sentry 2>/dev/null; git reset --hard sentry` (or `git reset --hard <sha of sentry HEAD>`) and
confirm `lib/shared/services/report/report.dart` exists. Never run `git stash`.

## What a migration ticket does
Every catch block in your directories is classified and moved to `Report`
(`lib/shared/services/report/report.dart`, read it; glossary in `CONTEXT.md` § Error reporting; spec
`.scratch/sentry/spec.md`). Then the matching lines are DELETED from the `## baseline` section of
`test/shared/source_guard/allow_list.md` (only your directories' lines; touch nothing else in that file
except to add a `## reasoned` entry). Finish with the guard test green:
`flutter test test/shared/source_guard/report_source_guard_test.dart`.

## The ladder
- **Fault** `report.fault(e, stackTrace: st, area: 'x', message: 'what we were doing')` — something
  broke that should never break; the catch used to swallow it (print / debugPrint / logger-only / empty).
  `fault` auto-downgrades expected failures (network, cancelled sign-in, expired session… see
  `expected_failures.dart`), so you do NOT need to check for those yourself.
- **Degraded** `report.degraded(...)` — expected but bad; the app lives with it (feature off, fallback used).
- **Note** `report.note('took branch X', area: 'x', data: {...})` — a best-effort / silent path took
  a branch (skipped, early return, cache miss fallback). In areas `startup`, `push`, `payments`,
  `sync` a Note is promoted to a warning event (rule D9) — that is intended.
- **Removed** — the try/catch hid a real bug; delete it so the error propagates (or `rethrow`).
- **Reasoned** — stays silent on purpose. Add one line to `## reasoned` with a real reason
  (`<kind> <path> :: <signature> :: <reason>`). Rare; a review decision, not a shortcut.
`info`/`debug` are NOT reports (structured logs only) — a catch that only `info`s still fails the guard.

Areas are lowercase, short, stable: `startup`, `auth`, `sync`, `database`, `push`, `payments`,
`credits`, `subscription`, `nutrition_plan`, `meal_logging`, `settings`, `integrations`, `garmin`,
`training_peaks`, `final_surge`, `vdot`, `runna`, `coach_mode`, `meal_planning`, `onboarding`, … pick
the feature folder name unless one above fits better. Use `payments` for RevenueCat/purchase code,
`push` for OneSignal/notification code, `sync` for anything in the sync pipeline (incl. integration
event sync).

## Getting a `Report`
- Riverpod code (controllers, services built by providers): `ref.read(reportProvider)` (import
  `shared/services/report/report.dart`). Prefer injecting once in the provider and passing it in.
- Plain classes: constructor parameter `Report? report` stored as `_report`, with
  `Report get _r => _report ?? SentryReport.global;` (pattern: `sentry_provider_observer.dart`).
- Widgets/screens: `ref.read(reportProvider)`; screens stay UI-only — if a screen has real logic in a
  catch, that logic belongs in a controller (do not refactor whole screens; the minimum move).
- Do NOT reach for the legacy aliases (`logger.error`, `DebugLogger.error`, `sentryReporterProvider`,
  `reportCriticalError`…) — they are deleted by ticket 10. If a file already uses `_logger.error(...)`
  for a catch, convert that call to `Report` too while you are there (same file, same ticket).
- Direct `package:sentry_*` imports in your directories must go; route through `Report` (breadcrumbs
  via `report.breadcrumb`, levels via fault/degraded/note). `sentry_drift` in `connection_native.dart`
  is ticket 06's: the Drift integration must be constructed in the bootstrap or Report layer, not the
  database file — move the import, keep the behaviour.
- Never `print`/`debugPrint` inside a catch. Remove them (Report mirrors to console in debug builds).

## Tests
- Shared fake: `test/helpers/fakes/recording_report.dart` (`RecordingReport`, `.faults/.degradeds/.notes`).
  Inject with `reportProvider.overrideWithValue(report)` or the constructor param.
- Where a catch becomes a Fault/Degraded/Note on a path that already has a test, the test asserts the
  report through `RecordingReport`, not console output. One assertion per newly-reported path that
  has an existing test; do not write new tests for every site, do add one for any `removed` catch
  whose new propagation changes behaviour.
- Run only the test files you touched plus the guard test. `dart analyze <changed files>` (or
  `flutter analyze --no-pub lib/<your dirs>`) must be clean. NEVER run the full suite, NEVER
  `flutter build`, NEVER open a simulator. Tests under `test/manual_live/` are excluded (need creds).
- Codegen: only if you touched a `@riverpod` / Drift annotation (`dart run build_runner build -d`).

## Finishing
1. Guard test green, touched tests green, analyze clean.
2. Append to your ticket file (`.scratch/sentry/issues/NN-*.md`) a section `## Sites` listing EVERY
   site as `path:line — <Fault|Degraded|Note|Removed|Reasoned> — one clause why`, then flip
   `**Status:**` to `done`. Ticket 09 part B writes to `.scratch/sentry/issues/09-part-b-sites.md` instead.
3. Commit on your worktree branch, message `refactor(sentry): migrate <scope> to Report (ticket NN)`,
   ending with the attribution lines from your system reminder. Do not push. Do not merge.
4. Final report back to the lead: branch name, commit sha, counts (sites by class), baseline lines
   deleted, anything you left for another ticket, any test you could not make green and why.

Overlaps (leave to the named ticket, do not touch):
- `lib/shared/services/sentry/` and `lib/core/utils/debug_logger.dart`, `logging_service.dart`,
  `debug_log_storage.dart`: ticket 10.
- `lib/shared/services/performance_telemetry.dart`, MetricKit code, and
  `lib/features/macro_dashboard/application/dashboard_transient_telemetry.dart`: ticket 11.
- `lib/shared/services/report/`: ticket 05 only (its own internal `catch (_)` blocks become reasoned entries).
