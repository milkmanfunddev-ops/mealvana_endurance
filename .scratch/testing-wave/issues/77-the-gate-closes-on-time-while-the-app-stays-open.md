# 77: The Gate closes on time while the app stays open

**Status:** done (wave 24, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** An app left in the foreground lands on the paywall when Pro ends, not only on the next resume (Finding 05-005 saw 93 minutes). The status controller schedules a re-count at the moment its answer stops counting (expiry, plus the 15-minute grace when the subscription renews, ticket 67's `countedAt`) and re-fetches once then; a new answer re-schedules and a dispose cancels the timer.

**Findings:** 05-005 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** mp-457 and mp-280 (access stays open until the entitlement's end date, then the Gate answers closed), mp-679 (the 15-minute grace for a renewing subscription).

**Touches:** lib/features/subscription/application/subscription_status_provider.dart, lib/features/subscription/domain/entitlement.dart

- [x] A seam test with an injected clock and fake timers: an open answer whose expiry passes while the controller lives turns closed at expiry (non-renewing) or expiry + 15 min (renewing), with no resume.
- [x] A test: a fresh active answer arriving before then cancels the close.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
