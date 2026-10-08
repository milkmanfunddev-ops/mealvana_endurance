# 01-006 · First Timeline after signup sends two DashboardTargetsAnomaly events to Sentry for a sub-second 'computing' gap

- kind: bug
- status: closed
- ticket: 01
- run: w1-20261007T1103Z
- screen: Timeline
- decision: 

**Steps.**
1. Finish email signup; the app lands on the Timeline.
2. Read the console for `[macro_dashboard]` lines and `error_reported`.

**Expected.**
Targets still computing for under a second right after signup is the normal first-load state; no Sentry event, or one at most if it lasts past a threshold.

**Actual.**
On all three signups the console logs "Dashboard shown without targets {reason: computing}" then "Dashboard targets transient resolved {duration_ms: 876 / 877 / 756}", and two `error_reported {severity: degraded, area: macro_dashboard, exception_type: DashboardTargetsAnomaly}` events go out each time (six events in this run: 06:11:05, 06:11:08, 06:17:31, 06:17:32, 06:33:28, 06:33:28 local). The screen itself was fine. Every new athlete adds two Sentry events.

**Evidence.**
- runs/01/console-redacted.log (06:11:04-06:11:08, 06:17:31-32, 06:33:28 local)
- runs/01/22-after-verify.png

**Decision quote.**
> 

**Triage.**
fix ticket: a transient that resolves under its threshold is a breadcrumb, not a Sentry error

**Closed (wave 3, 2026-10-08).** retest passed in ticket 30 (runs/30/notes.md, PASS 01-006)
