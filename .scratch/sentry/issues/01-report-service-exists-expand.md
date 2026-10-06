# 01: Report service exists (expand)

**What to build:** One class, `Report`, in the shared services layer, is the only thing code calls to report a Fault, a Degraded condition or a Note (glossary: CONTEXT.md § Error reporting). It sends to Sentry at the right level, promotes a Note to a warning event when its area is startup, push, payments or sync, downgrades allow-listed expected failures from Fault to Degraded, drops test-only exceptions, sends one Mixpanel `error_reported` event per Fault or Degraded, and writes info and debug lines as Sentry structured logs and to the console in debug builds. A `NoopReport` with the same interface exists for tests and consent-off builds. This is the expand step of the logger merge: the existing `SentryReporter` methods and the logger's `error`, `warning`, `info`, `debug` stay callable as thin aliases onto `Report`, so every current call site compiles unchanged. The old `isSentryNoise` drop list becomes the allow-list.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] `Report` exposes `fault`, `degraded`, `note`, `info`, `debug`, `breadcrumb`, `setUser(id, role)`, `clearUser`; `NoopReport` implements the same interface
- [ ] Fault → Sentry `error`; Degraded → `warning`; Note → breadcrumb, promoted to a `warning` event for areas startup, push, payments, sync; info/debug → `Sentry.logger`
- [ ] Allow-listed types and patterns (socket, timeout, handshake, cancelled sign-in, invalid credentials, expired session, user-cancelled purchase, OAuthAccountNotFound, RevenueCat network) arrive as warnings, never errors; `TestFailure` never arrives
- [ ] Every Fault and Degraded also emits Mixpanel `error_reported` with severity, area, exception_type, sentry_event_id and no message text
- [ ] Old reporter and logger APIs are aliases onto `Report`; the app compiles with no call site changed; the external-deps provider hands out `Report`
- [ ] Service seam tests drive the real `Report` with the SDK's in-memory transport and a fake analytics tracker and assert level, tags, user, breadcrumbs, downgrades, promotion, the Mixpanel event, and that `NoopReport` emits nothing
- [ ] `flutter analyze` clean, full suite green
