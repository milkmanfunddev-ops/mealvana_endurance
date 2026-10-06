# 04: Source guard with a baseline (ratchet)

**What to build:** A test in the normal suite walks the app source and fails when a catch block neither rethrows, nor calls `Report` (or an alias listed as acceptable until contract), nor appears in an allow-list file beside the test where every entry has a one-line reason. The same test fails on a Sentry SDK import outside the service and the bootstrap, and on `print` or `debugPrint` inside a catch. It lands green by listing every current violation in a baseline section of the allow-list, so each migration batch deletes its entries and the test ratchets downward; an entry can never be added without a reason.

**Blocked by:** 01 Report service exists

**Status:** built (2026-10-06, branch `sentry`)

- [x] The test exists, runs in `flutter test`, and is green on the branch at the moment it lands
- [x] The allow-list file has a `baseline` section listing every current violation by file and line signature, and a `reasoned` section that is empty or carries one-line reasons
- [x] Deleting a baseline entry without fixing its catch turns the test red; adding an unreported catch anywhere turns it red
- [x] A `sentry` import outside the two permitted locations turns it red; a `print` inside a catch turns it red
- [x] The test's own matching is documented at the top of the file in plain words, including what counts as reported

## Build notes (2026-10-06)

- Files, all under `test/shared/source_guard/`:
  - `report_source_guard_test.dart`: the guard (four tests) and the matcher self-tests (15
    inline snippets: empty catch, rethrow, throw-new, each `Report` call, each legacy alias,
    info/debug-only, print and debugPrint in a catch, bare `on X {`, mixin/extension `on`,
    catch/print inside comments and strings, braces inside strings, nested catch, SDK import
    in and out of the permitted dirs, ratchet arithmetic).
  - `source_guard.dart`: the matcher, with the rules written out in plain words at the top.
    No package imports, so it is runnable from plain `dart`.
  - `allow_list.md`: the data file, hand-edited. Prose before the first `## ` heading is
    documentation; `## reasoned` (empty) and `## baseline` hold one entry per line.
- Rules, short form (the long form is the header of `source_guard.dart`):
  - Scanned: `lib/**.dart` minus `*.g.dart`, `*.freezed.dart`, `lib/features/_archived/`.
    Comments and string contents are blanked before matching; `${}` interpolations are
    walked as code so a `}` inside a string never closes a block early.
  - A catch block is `} catch (`, `} on X catch (` or a bare `} on X {`; the leading `}`
    separates it from a mixin's `on` clause. Body = brace-matched block.
  - Reported means the body contains an escape (`rethrow`, `throw`,
    `Error.throwWithStackTrace(`), a `Report` call (`.fault(`, `.degraded(`, `.note(`,
    `report.`, `_report.`, `Report.`), or a legacy alias accepted until ticket 10
    (`reportCriticalError`, `reportDatabaseError`, `reportNetworkError`,
    `reportEdgeFunctionError`, `captureMessage`, `_sentry.`, `sentry.`, `Sentry.capture`,
    `logger.error`/`.warning`/`.fatal` with or without the underscore, `DebugLogger.error`/
    `.warning`, `AppLogger`). `logger.info`/`.debug` and `DebugLogger.info` do not count.
    An inner catch's report counts for its outer block.
  - `print(`/`debugPrint(` inside a catch is a separate finding, reported or not.
  - `import 'package:sentry…'` is a finding outside `lib/shared/services/report/` and
    `lib/shared/core/bootstrap/`.
- Keys: `<kind> <path> :: <trimmed catch line>` (or the import line). Counted, so a file
  with five identical `} catch (e) {` violations carries five entries; line numbers are not
  stored and drift freely.
- Counts at landing: 1,081 files scanned, 1,191 catch blocks found, 437 unreported catches
  across 191 files, 71 prints inside catches, 14 Sentry SDK imports outside the permitted
  dirs (`sentry_reporter.dart`, `sentry_provider_observer.dart`, `app_router.dart`,
  `connection_native.dart` (`sentry_drift`), `performance_telemetry.dart`,
  `data_sync_service.dart`, `sync_coordinator.dart`, `daily_macro_targets_repository.dart`,
  `formula_pins_repository.dart`, `personal_formulas_repository.dart`,
  `raw_retention_dead_man_check.dart`, `tp_writeback_service.dart`,
  `dashboard_transient_telemetry.dart`, `macro_targets_controller.dart`). Baseline: 522
  entries, reasoned: 0.
- Ratchet proven by hand before commit: deleting one baseline entry → red on "every … is
  listed"; a probe file with an empty catch → red naming `lib/zz_guard_probe_tmp.dart:4`;
  an entry for a file that does not exist → red on "no allow-list entry is stale".
- How a migration ticket uses it: fix the sites, run
  `flutter test test/shared/source_guard`, and delete the entries the stale check names
  (the failure message lists them key by key). Moving a print out of a catch deletes its
  `printInCatch` entry the same way; moving an SDK import deletes its `sentryImport`
  entry. New deliberate silence goes under `## reasoned` with ` :: <reason>` on the line;
  the parser rejects a reasoned entry without one and a baseline entry with one.
- Ticket 10 deletes the `legacyAliases` list in `source_guard.dart` together with the
  shims; whatever then turns red is its remaining work.
- Not done here: nothing. `flutter analyze` on the three files and `flutter test
  test/shared/source_guard test/shared/core/bootstrap` (63 tests) are green.
