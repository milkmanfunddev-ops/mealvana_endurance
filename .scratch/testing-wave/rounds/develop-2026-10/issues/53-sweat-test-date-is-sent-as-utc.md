# 53: `sweat_test_date` is sent as UTC

**Status:** ready (round develop-2026-10, fix wave 6)
**Labels:** fix, round:develop-2026-10, area:sync, area:auth
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** nothing in code; runs in the fix wave after retest wave 5 (cut at the wave-4 close from ticket 39's closing note).
**Next:** `/testing-wave develop-2026-10` (fix wave after retest wave 5)
**Model:** opus

**What to build:** Tickets 22 and 39 made every `timestamptz` writer send `.toUtc().toIso8601String()`. One remained because its file was off-limits in wave 4: `UserProfile.toJson` sends `sweat_test_date` (a `timestamptz` column in both schema dumps) as naive local time. Lee, 2026-10-08: fix it the same way.

Site, from code at `98b15919` (re-read before editing):
```
lib/features/auth/domain/user_preferences.dart:390:      sweatTestDate: row['sweat_test_date'] != null
lib/features/auth/domain/user_preferences.dart:391:          ? DateTime.tryParse(row['sweat_test_date'] as String)
lib/features/auth/domain/user_preferences.dart:485:      sweatTestDate: json['sweat_test_date'] != null
lib/features/auth/domain/user_preferences.dart:486:          ? DateTime.tryParse(json['sweat_test_date'] as String)
lib/features/auth/domain/user_preferences.dart:555:      'sweat_test_date': sweatTestDate?.toIso8601String(),
```

1. `sweat_test_date` goes out as `toUtc().toIso8601String()`; the Drift read-back stays local as the other writers' do.
2. Check the dump (`docs/dev_schema.txt`, `docs/prod_schema.txt`) for any other date field in the same `toJson` that is `timestamptz` and still naive; fix those in the same pass and list them in the ticket. A `timestamp without time zone` or a `date` column stays naive (ticket 39's Decisions).

**Findings:** none (ticket 39's closing note).

**Decisions:** Lee, 2026-10-08: yes, follow-up ticket. Ticket 39's rule holds: inline `.toUtc()`, no shared helper.

**Touches:** lib/features/auth/domain/user_profile.dart (or wherever `sweat_test_date` is serialised; the grep above names it), test/features/auth/user_profile_utc_test.dart (new). 2 files. If `UserProfile` is freezed or json_serializable, run unfiltered codegen and commit what it changes.

**Overlaps:** none with 52 or 54.

No edge-function or schema change. Nothing to deploy.

- [ ] Seam test (ticket 22's pattern): a profile with a local `sweatTestDate`, uploaded through the real repository against `FakePostgrest`, sends a value that `endsWith('Z')` and `isAtSameMomentAs` the local one.
- [ ] `flutter analyze` clean on touched files.
- [ ] Retest: one `users.sweat_test_date` row read after the next simulator run that saves a sweat test (retest ticket, Settings).

Next: /testing-wave develop-2026-10
