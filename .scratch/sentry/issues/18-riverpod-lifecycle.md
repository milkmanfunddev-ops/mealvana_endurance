# 18: Riverpod lifecycle

**What to build:** Every `UnmountedRefException` (prod CP, D1, C9, BZ, CK, CB, CA and the dev set), `userIdProvider` disposed during loading (CN, DEV-6T), and provider modified while building (CM, CJ, C5, DEV-8C). Fix the top offenders by hand with `ref.mounted` checks after async gaps and move modifications out of build, and fix the pattern where a shared helper exists.

**Blocked by:** 10 Contract

**Status:** ready-for-agent

- [ ] Each listed issue has a named root cause and a fix or a reasoned reclassification
- [ ] The `allEventsProvider` and `settingsControllerProvider` cases cannot recur: tests reproduce the dispose-during-await and pass
- [ ] All listed issues resolved in Sentry

## Note (2026-10-06, from ticket 15's device run)

`athleteZonesProvider` threw `UnmountedRefException` on every open of the Settings screen in the
dev build (`ref.read(reportProvider)` after the first `await`, introduced by the wave-3 Report
migration in `athlete_zones_provider.dart`). Fixed in ticket 15 by reading `Report` before the
await; dev event `242566ca993c4b738eb033a1174200b5`. The same shape, a `ref.read` of
`reportProvider` after an async gap, is worth a sweep across the other migrated providers when
this ticket runs.
