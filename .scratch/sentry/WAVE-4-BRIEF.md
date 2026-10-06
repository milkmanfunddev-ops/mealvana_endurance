# Wave 4 brief: ticket 10, the contract (read fully before touching code)

Branch of record: `sentry`. FIRST in your worktree: `git reset --hard sentry`, then
`flutter pub get --offline`, then copy `.env`, `.env.dev.local`, `.env.prod.local` from
`/Users/leemartin/development/mealvana_endurance/` (gitignored; never commit them). Never `git stash`.

## The job
Every file in your scope stops referencing the legacy surfaces: `AppLogger` / `PrettyAppLogger` /
`appLoggerProvider` (`lib/shared/services/logging_service.dart`), `DebugLogger`
(`lib/core/utils/debug_logger.dart`), `SentryReporter` / `SentrySdkReporter` / `NoopSentryReporter` /
`sentryReporterProvider` (`lib/shared/services/sentry/sentry_reporter.dart`), and the `sentry:` /
`logger:` fields of `AppExternalDeps`. They are replaced by `Report`
(`lib/shared/services/report/report.dart`, read its header). The lead DELETES the legacy files after the
wave; do not edit or delete them yourself, and do not touch `lib/features/_archived/`.

## Verification rule for this wave (Lee, 2026-10-06)
`dart analyze <every file you changed>` must be clean (or `flutter analyze --no-pub lib/<dir> test/<dir>`).
Run NO `flutter test`. The lead runs the whole suite once after merging. Where you rewrite a test's
assertion, read the production code path so the assertion is true; do not guess.

## Mapping
Injection: a class that took `required AppLogger logger` (or `SentryReporter sentry`) takes
`required Report report` instead (store as `_report`). If it already has a `Report? report` param from
wave 3, drop the logger/sentry param and use that. Providers: `ref.watch(appLoggerProvider)` /
`ref.watch(sentryReporterProvider)` → `ref.watch(reportProvider)`. Only where no injection point exists
(static helpers, `fromJson` outside domain, widgets without a ref) use `SentryReport.global`.

| Legacy call | Report call |
|---|---|
| `logger.info(m, context: c, data: d)` | `_report.info(m, area: c, data: d)` |
| `logger.debug(m, context: c, data: d, error: e)` | `_report.debug(m, area: c, data: {...?d, if (e != null) 'error': e.toString()})` |
| `logger.warning(m, context: c, data: d, error: e, stackTrace: st)` | `_report.degraded(e ?? LoggedFault(m, context: c), stackTrace: st, area: c, extra: d, message: e == null ? null : m)` |
| `logger.error(...)` / `logger.fatal(...)` | `_report.fault(` same shape as warning `)` |
| `logger.api(m, endpoint:, statusCode:, requestData:, responseData:, duration:, error:)` | error == null → `_report.info(m, area: 'api', data: {...})`; else `_report.fault(error, area: 'api', message: m, extra: {...})` |
| `logger.database(m, operation:, table:, data:, duration:, error:)` | same pattern, area `'database'` |
| `logger.navigation / userAction / analytics(...)` | `_report.info(m, area: 'navigation' / 'user_action' / 'analytics', data: {...named args})` |
| `logger.nutritionPlan(m, planId:, phase:, data:, error:)` | error == null → `info(area: 'nutrition_plan')`; else `degraded(error, area: 'nutrition_plan', message: m, extra: {...})` |
| `DebugLogger.debug(m)` / `.info(m)` | `report.debug(m)` / `report.info(m)` (inject; `SentryReport.global` only if impossible) |
| `DebugLogger.warning(m)` | `report.degraded(LoggedFault(m))` |
| `DebugLogger.error(m, error: e, stackTrace: st)` | `report.fault(e ?? LoggedFault(m), stackTrace: st, message: e == null ? null : m)` |
| `sentry.reportCriticalError(e, stackTrace:, context:, tags:)` | `report.fault(e, stackTrace:, area: context, tags:)` |
| `sentry.reportEdgeFunctionError(fn, e, responseTime:, statusCode:, stackTrace:)` | `report.fault(e, stackTrace:, area: 'edge', tags: {'edge_function': fn, if (statusCode != null) 'status_code': '$statusCode'}, extra: {if (responseTime != null) 'response_ms': responseTime.inMilliseconds})` |
| `sentry.reportDatabaseError(e, operation:, table:, stackTrace:)` | `report.fault(e, stackTrace:, area: 'database', tags: {if (operation != null) 'operation': operation, if (table != null) 'table': table})` |
| `sentry.reportNetworkError(e, url:, method:, statusCode:, timeout:, stackTrace:)` | `report.degraded(e, stackTrace:, area: 'network', tags: {...non-null of method/status_code}, extra: {...url/timeout})` |
| `sentry.addBreadcrumb(message:, category:, level:, data:)` | `report.breadcrumb(message, category:, data:)` |
| `sentry.captureMessage(m, level: warning, tags:, extra:, fingerprint:)` | `report.degraded(LoggedFault(m), tags:, extra:, fingerprint:)`; level error/fatal → `fault`; level info/debug → `report.note(m, data: extra)` |
| `sentry.setUserContext(deviceId:, ...)` / `clearUserContext()` | identity is owned by `lib/shared/services/report/report_identity.dart` (ticket 02). If that already covers the caller's moment, DELETE the call and say so in your part file; otherwise `report.setUser(id, deviceId:)` / `report.clearUser()` |
| `sentry.isEnabled` | `report.isEnabled` |
| `AppExternalDeps(..., sentry: x, logger: y, ...)` | drop both args (they are optional now); pass `report:` if the code under test reads it |

Where wave 3 left a repository that Faults AND rethrows while its controller Faults again: `Report`
now dedupes by error identity (one object, one event), so leave both or drop the inner one; do not add
new double reports.

## Tests
Shared fake: `test/helpers/fakes/recording_report.dart` (`RecordingReport`, `.faults/.degradeds/.notes/.calls`).
`MockAppLogger`, `MockSentryReporter`, `RecordingAppLogger`, `RecordingSentryReporter`,
`NoopSentryReporter` → `RecordingReport`. `appLoggerProvider.overrideWithValue(...)` →
`reportProvider.overrideWithValue(report)`. `verify(() => mockLogger.error(...))` → an assertion on
`report.faults` (match on `area`, `message` or `error.toString()`); `verifyNever` → `isEmpty`.
A mock that existed only to satisfy a constructor becomes `RecordingReport()` with no assertions.

## Domain decoders (Lee's ruling, 2026-10-06: domain stays pure)
Domain files that call `SentryReport.global` from `fromJson` / Drift decoders drop the Report import
and take a callback instead: `DecodeIssue onIssue = ignoreDecodeIssue` (import
`shared/domain/decode_issue.dart`), called as `onIssue('what was malformed', error: e, stackTrace: st)`
at each former report site; behaviour (the fallback value) is unchanged. The data-layer caller that
reads the column passes `report.decodeIssue('<area>')` (import
`shared/services/report/decode_issue_report.dart`). Files: see your prompt.

## Finishing
1. `dart analyze` clean on every changed file. No `flutter test`.
2. Write `.scratch/sentry/issues/10-part-<letter>.md`: files converted (count), identity calls deleted
   (which), domain decoders moved, anything you could not convert and why.
3. One commit: `refactor(sentry): ticket 10 part <letter>, <scope> off the legacy aliases`, ending with
   the attribution lines from your system reminder. Do not push. Do not merge.
4. Report back: branch, sha, counts, leftovers.
