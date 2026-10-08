# 53: `sweat_test_date` is sent as UTC

**Status:** in-progress (wave 6, 2026-10-08) (round develop-2026-10, fix wave 6)
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

- [x] Seam test (ticket 22's pattern): a profile with a local `sweatTestDate`, uploaded through the real repository against `FakePostgrest`, sends a value that `endsWith('Z')` and `isAtSameMomentAs` the local one.
- [x] `flutter analyze` clean on touched files.
- [ ] Retest: one `users.sweat_test_date` row read after the next simulator run that saves a sweat test (retest ticket, Settings).

## Fix notes

Fix wave 6 pass A, branch `testing-wave/develop-2026-10/52-53`.

- `lib/features/auth/domain/user_preferences.dart` (`UserProfile.toJson`): `sweat_test_date` now goes out as `sweatTestDate?.toUtc().toIso8601String()`, inline, no helper (ticket 39's rule). The read paths (`fromSupabaseRow`, `fromJson`) are unchanged. Drift hands the value back in local time, as it does for the other writers. `UserProfile` is a hand-written class, so there was no codegen.
- Other date fields in that `toJson`, checked against `users` in both `docs/dev_schema.txt` and `docs/prod_schema.txt`:
  - `created_at`, `updated_at` (`timestamptz`): already UTC (tickets 22/39).
  - `weight_pounds_updated_at`, `body_fat_pct_updated_at` (`timestamptz`): already UTC.
  - `birthday` (`date`): stays a plain `YYYY-MM-DD`, correctly.
  - `last_active_at` and `auth_skipped_at` (`timestamptz`) are not in this `toJson`.
  - So `sweat_test_date` was the only naive `timestamptz` left in it.
- Test: `test/features/auth/user_profile_utc_test.dart` (new, 2 tests, real `UserRepository` + Drift + `FakePostgrest`):
  - A date-picker local midnight goes out ending in `Z`, at the same instant, and `birthday` stays a plain date.
  - A server row with `sweat_test_date` as PostgREST answers it (`…+00:00`) is saved, read back from Drift, and uploaded twice. Both sends end in `Z` and keep the server instant.
  - Both tests fail against the old line (`'2026-09-14T00:00:00.000'`, no offset), which also shows the drift: a server `05:00Z` came back from Drift as local midnight and would have been re-sent as `00:00Z`.
- Runs: `user_profile_utc_test.dart` 2/2 pass. #116 grep under `test/` (`UserProfile`, `toJson`, `sweat_test_date`/`sweatTestDate`) named 98 files, all run: 1069 pass, 0 fail. `flutter analyze` on both touched files: no issues. No catch added.
- Left for the lead: the retest box (one `users.sweat_test_date` row after a simulator sweat-test save). Expect a `Z` instant at the athlete's local midnight. Rows written before this fix hold local midnight read as UTC, and nothing rewrites them until the athlete saves the sweat profile again.

Next: /testing-wave develop-2026-10
