# 35: Restore develop's Delete Account dialog wording

**Status:** done 2026-10-08: passed in ticket 48 (wave 5); the action reads "Delete" as item 1 intended
**Labels:** fix, round:develop-2026-10, area:settings, copy
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** nothing. Runs in the same agent as 36 (both touch `assets/config/content_defaults.json`).
**Next:** `/testing-wave develop-2026-10` (fix wave 4)
**Model:** opus

**What to build:** Ticket 29 (commit `57db9836`) moved the Settings confirm dialogs onto `settings.*` content keys and brought mealplanning's text with them. Lee (2026-10-08, wave 2 question a) wants develop's old Delete Account wording back, under the same keys. The Sign out dialog keeps its current text: develop's old sign-out body promised a guest mode, which mp-508 / ticket 29 removed on purpose, and `settings_account_dialogs_test.dart:189` asserts the sign-out text has no "guest". Line numbers from code at `4e77cf43`.

1. **Delete dialog defaults** in `assets/config/content_defaults.json` (`settings` block, lines 182-185) become develop's old strings (`git show ce1a1527:lib/features/settings/presentation/screens/settings_screen.dart:624-657`):
   - `delete_account_button`: "Delete Account" (was "Delete account")
   - `delete_confirm_title`: "Delete Account?" (was "Delete account?")
   - `delete_confirm_body`: "This will permanently delete your account and all associated data. This action cannot be undone." (was "This permanently deletes your account and all of its data. This cannot be undone.")
   - `delete_confirm_action`: "Delete" (unchanged)
2. **Nothing else moves.** `sign_out_*` (178-180) and `confirm_cancel` (181) stay. The dialogs themselves (`settings_screen.dart:578-594` sign out, `:615-669` delete, both through `_confirmAccountAction` at `:677`) read the keys and need no change.
3. **Tests.** `test/features/settings/settings_account_dialogs_test.dart` reads the strings through `loadDefaultContent()`, so the delete assertions at `:250-266` follow the JSON; run it. No server-side `settings.*` rows exist under `supabase/`, so nothing is seeded remotely.

**Findings:** none (wave 2 question a).

**Decisions:** Lee, 2026-10-08: delete dialog only; sign-out text stays as the no-guest-mode wording.

**Touches:** assets/config/content_defaults.json. 1 file (the test is run, not changed). No generated files.

**Overlaps:** 36 and 37 also edit `content_defaults.json`: 35 and 36 go to one agent; 37 runs after that agent merges.

No edge-function or schema change. Nothing to deploy.

- [x] `settings_account_dialogs_test.dart` green with the new defaults (5/5, wave 4).
- [ ] Retest on a simulator: Settings → Delete account shows the old title and body (retest ticket 30's account checks, next test wave).

Next: /testing-wave develop-2026-10 (fix wave 4)
