# 09: Migrate: credits, subscription, notifications, the rest

**What to build:** Every catch block in AI credits, subscription and entitlements, the notification service (OneSignal init, permission, identity sync), and every remaining directory not covered by tickets 05 to 08 is classified and moved to `Report`: a swallowed failure becomes a Fault, an expected-but-bad condition a Degraded, a best-effort branch a Note with its area set, and a try/catch that hides a real bug is removed so the error propagates. Direct Sentry SDK calls in these directories route through `Report`. Every baseline entry for these directories is deleted from the guard's allow-list; any catch left deliberately silent gets a reasoned entry instead. The ticket's closing comment lists every site and its classification so review can overrule one.

**Blocked by:** 01 Report service exists; 04 Source guard with a baseline

**Status:** ready-for-agent

- [ ] No baseline entry remains for AI credits or the other directories in scope; the guard test is green
- [ ] No `print`, `debugPrint`, logger-only or empty catch remains in scope; each is a `Report` call, a rethrow, or a reasoned allow-list entry
- [ ] No direct Sentry SDK import remains in scope
- [ ] The ticket records each site's classification (Fault / Degraded / Note / removed / reasoned)
- [ ] Existing tests in scope still pass; where a catch becomes a Fault on a tested path, the test asserts the report through `NoopReport` or the transport, not console output
