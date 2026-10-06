# 01: Report service exists (expand)

**What to build:** One class, `Report`, in the shared services layer, is the only thing code calls to report a Fault, a Degraded condition or a Note (glossary: CONTEXT.md § Error reporting). It sends to Sentry at the right level, promotes a Note to a warning event when its area is startup, push, payments or sync, downgrades allow-listed expected failures from Fault to Degraded, drops test-only exceptions, sends one Mixpanel `error_reported` event per Fault or Degraded, and writes info and debug lines as Sentry structured logs and to the console in debug builds. A `NoopReport` with the same interface exists for tests and consent-off builds. This is the expand step of the logger merge: the existing `SentryReporter` methods and the logger's `error`, `warning`, `info`, `debug` stay callable as thin aliases onto `Report`, so every current call site compiles unchanged. The old `isSentryNoise` drop list becomes the allow-list.

**Blocked by:** None (can start immediately)

**Status:** done (2026-10-05, branch `sentry`)

- [x] `Report` exposes `fault`, `degraded`, `note`, `info`, `debug`, `breadcrumb`, `setUser(id, role)`, `clearUser`; `NoopReport` implements the same interface
- [x] Fault → Sentry `error`; Degraded → `warning`; Note → breadcrumb, promoted to a `warning` event for areas startup, push, payments, sync; info/debug → `Sentry.logger`
- [x] Allow-listed types and patterns (socket, timeout, handshake, cancelled sign-in, invalid credentials, expired session, user-cancelled purchase, OAuthAccountNotFound, RevenueCat network) arrive as warnings, never errors; `TestFailure` never arrives
- [x] Every Fault and Degraded also emits Mixpanel `error_reported` with severity, area, exception_type, sentry_event_id and no message text
- [x] Old reporter and logger APIs are aliases onto `Report`; the app compiles with no call site changed; the external-deps provider hands out `Report`
- [x] Service seam tests drive the real `Report` with the SDK's in-memory transport and a fake analytics tracker and assert level, tags, user, breadcrumbs, downgrades, promotion, the Mixpanel event, and that `NoopReport` emits nothing
- [x] `flutter analyze` clean, full suite green

## Build notes (2026-10-05)

- `lib/shared/services/report/report.dart`: `Report` interface, `SentryReport`, `NoopReport`,
  `LoggedFault` (a message-only Fault), `reportProvider`. `lib/shared/services/report/expected_failures.dart`:
  the allow-list, with one `ExpectedFailure` enum value per reason; the value is the
  `expected_failure` tag.
- Aliases: `SentrySdkReporter`, `PrettyAppLogger` and the static `DebugLogger` all forward to `Report`.
  Logger `error`/`fatal` and `DebugLogger.error` are Faults, `warning` is Degraded, `info`/`debug`
  are structured logs. `DebugLogger` reaches the provider's instance through `SentryReport.global`.
- `setUserContext` forwards only the id (device id, as before); ticket 02 switches identity to the
  Supabase user id plus role, so the profile fields it used to carry are not forwarded.
- Notes are not fanned out to Mixpanel, including promoted ones; story 22 names Fault and Degraded only.
- The four entry points now share one `beforeSend` (`filterSentryEvent`): test-runner leaks dropped,
  expected failures downgraded to warning and tagged, info/debug dropped in release except MetricKit.
  `options.enableLogs = true` added so `Report.info`/`debug` reach Sentry on 9.6; ticket 02 keeps it.
- Fingerprint kept on `fault`/`degraded` because two callers depend on it
  (raw-retention dead-man check, plan-generation anomaly).
- Analytics is looked up lazily (`AnalyticsTracker Function()`) because the analytics tracker depends
  on the logger alias; a `watch` would be a provider cycle.
- Seam test: `test/shared/services/report/report_test.dart` (29 cases) with an in-memory `Transport`.

## Code review (2026-10-05, Standards + Spec axes)

Fixed in this change:
- **Recursion (real bug):** the Mixpanel tracker logs its own failures through the logger alias,
  which lands back in `Report`; a Fault raised under the fan-out was fanned out again, forever
  (async, so no timeout could catch it). Fan-out now runs under a zone marker and a Fault inside
  that zone is captured but not fanned out. Test: "a tracker that logs its failure through Report
  cannot loop".
- **D9 on the capture-failed path:** when the SDK itself throws, Report now writes the debug log
  and a breadcrumb, not only the debug console.
- **One event is never both:** `filterSentryEvent` overwrites `severity` to `degraded` when it
  downgrades, instead of leaving a warning tagged `severity: fault`.
- **Areas lower-cased** at the boundary so legacy `context: 'SYNC'` and `area: 'sync'` are one tag.
- **Weather 546s** are tagged `handled_fallback`, not `offline`.
- **RevenueCat needles** qualified (`PurchasesErrorCode.*`); `storeProblemError` and bare
  `userCancelled` removed.
- Unused filter helpers deleted; console and debug-log sinks merged into one `_mirror`.

Left as is, with reasons:
- `sentry_event_filter.dart` imports the SDK outside `report/`; it is the bootstrap's `beforeSend`
  and ticket 02 rewrites the bootstrap. Ticket 04's allow-list must carry it until then.
- `_toSentryLog` uses the static `Sentry.logger`; `Hub.options` is `@internal`.
- Severity and level mappings stay as small switches; a `ReportSeverity` extension can come with
  ticket 10 when the aliases go.

Needs Lee's ruling (one line to change either way):
- **Promoted Notes and Mixpanel.** The glossary says a promoted Note "is promoted to a Degraded
  warning event"; story 22 says Fault and Degraded fan out. Built: promoted Notes do NOT fan out
  and are tagged `severity: note`. If Lee wants them counted in Mixpanel, add the fan-out call in
  `SentryReport.note`.
