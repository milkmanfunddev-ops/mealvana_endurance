# 18: Riverpod lifecycle

**What to build:** Every `UnmountedRefException` (prod CP, D1, C9, BZ, CK, CB, CA and the dev set), `userIdProvider` disposed during loading (CN, DEV-6T), and provider modified while building (CM, CJ, C5, DEV-8C). Fix the top offenders by hand with `ref.mounted` checks after async gaps and move modifications out of build, and fix the pattern where a shared helper exists.

**Blocked by:** 10 Contract

**Status:** ready-for-agent

- [ ] Each listed issue has a named root cause and a fix or a reasoned reclassification
- [ ] The `allEventsProvider` and `settingsControllerProvider` cases cannot recur: tests reproduce the dispose-during-await and pass
- [ ] All listed issues resolved in Sentry
