# 36: The profile Email field is editable only when auth has no real address

**Status:** in-progress (wave 4, 2026-10-08)
**Labels:** fix, round:develop-2026-10, area:settings, area:auth
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** nothing. Runs in the same agent as 35 (shared `content_defaults.json`).
**Next:** `/testing-wave develop-2026-10` (fix wave 4)
**Model:** opus

**What to build:** Supabase Auth owns the login address (`auth.users.email`); `public.users.email` is a copy written at signup and upgrade (`auth_migration_service.dart:785-794`) and lowercased at write (ticket 21). Commit `e3d5e3f5` (ticket 29) made the Profile & Preferences Email field read-only. Lee (2026-10-08, wave 2 question g): read-only is right when auth holds a real address (email/password, Google, Apple with a shown address), but an Apple sign-in that hid the address gives auth a private-relay string (`…@privaterelay.appleid.com`) the athlete cannot change and nobody can read. In that case, and when auth has no address at all, the field is an editable **contact email** saved to `public.users.email`. Line numbers from code at `4e77cf43`.

1. **The state carries the auth address and whether the field is editable.** `SettingsController.build` (`settings_controller.dart:250-254`) folds profile and auth emails into one `effectiveEmail`; `SettingsState` (`settings_state.dart:151`) keeps only the merged value. Add `authEmail` (from `supabaseUser?.email`, `:170`) and `emailEditable` to `SettingsState` (+ `copyWith`): editable when `authEmail` is null/empty or `isPrivateRelayEmail(authEmail)` (`lib/shared/services/support/support_identity.dart:11-17`, already used by `root_app_widget.dart:389` and the help screen). Display value: the profile copy when editable (contact email, may be empty), the auth address when read-only.
2. **The screen.** `preferences_screen.dart:401-410` renders `_buildReadOnlyField` unconditionally. When `emailEditable`, render the editable `_buildTextField` with key `profile_edit.email_field` (the pre-`e3d5e3f5` field: `git show ce1a1527:…/preferences_screen.dart:365-373`), label and hint from new keys `profile_edit.contact_email_label` ("Contact email") and `profile_edit.contact_email_hint` ("Where we can reach you"); `content_keys.dart:246-253`, defaults `content_defaults.json:343-349`. Otherwise keep the read-only field and the "Your login email" label. `saveAllPreferences` (`:126-139`) passes `email` only when editable (trimmed, empty → clear).
3. **The save stops echoing the auth address into the profile row.** `settings_controller.dart:805-806` writes `currentState.email ?? existingProfile.email`, and `currentState.email` is the merged value, so today every save copies the auth address (for Apple: the relay string) into `public.users.email` whenever the profile copy was empty. Write `email` only from an explicit edit (editable case); otherwise leave the row's value alone (`email: existingProfile.email`, `clearEmail: false`).
4. **A fresh login never overwrites a contact email with a relay or empty address.** `auth_migration_service.dart:785-794` (`_handleFreshLogin`) sets `email: sessionEmail` whenever it is non-empty. Guard it: when `isPrivateRelayEmail(sessionEmail)` and the remote profile already has a non-relay, non-empty email, keep the profile's value. Write a LaunchTrail/breadcrumb line when the guard fires (D9).
5. **`auth_provider` is not needed**: the relay check decides, so `AuthUser` (`auth_user.dart:2-9`) stays as it is.

**Findings:** none (wave 2 question g).

**Decisions:**
- Auth is the one source of truth for the login address; the profile column is a cached copy, or a contact address when auth has none worth showing. Nothing in this ticket changes the login address.
- Read-only for a shown Apple address: Apple gives the real address in the identity token when the athlete chose to share it; only the relay case is editable.
- Legacy rows that already hold a relay string (from the echo in item 3) show as an editable empty contact field only when the stored value is itself a relay address; treat a stored relay value as empty for display.

**Touches:** lib/features/settings/domain/settings_state.dart, lib/features/settings/presentation/providers/settings_controller.dart, lib/features/settings/presentation/screens/preferences_screen.dart, lib/features/auth/application/auth_migration_service.dart, lib/features/content/domain/content_keys.dart, assets/config/content_defaults.json, test/features/settings/presentation/screens/preferences_clear_text_fields_test.dart, test/features/settings/presentation/screens/preferences_accessibility_test.dart, test/features/settings/settings_state_test.dart, test/shared/services/support/support_identity_test.dart (new), test/features/auth/application/fresh_login_keeps_contact_email_test.dart (new). 11 files. `SettingsController` is `@riverpod`: run unfiltered codegen if its signature changes (it should not).

**Overlaps:** 35 (`content_defaults.json`; same agent). 37 (`content_keys.dart`, `content_defaults.json`): runs after this agent merges. 39 touches no settings file.

No edge-function or schema change. Nothing to deploy.

- [ ] Widget tests (`preferences_clear_text_fields_test.dart`, seeded through `_SeededSettingsController` at `:40-59`): with `authEmail: 'alice@example.com'` the field is read-only, labelled "Your login email", and a save leaves `saved!.email` unchanged (the existing test at `:148-164`); with `authEmail: 'x1y2@privaterelay.appleid.com'` the field is editable, empty, labelled "Contact email", typing `lee@example.com` and saving writes `saved!.email == 'lee@example.com'`; with `authEmail: null` the same. `preferences_accessibility_test.dart:141-146` adds the editable label case.
- [ ] Controller seam: a save with the field read-only does not write `email` into the profile row (the echo in item 3 is gone): assert the `updateUserProfile` call keeps `existingProfile.email`.
- [ ] `support_identity_test.dart`: relay, plain and empty addresses.
- [ ] `fresh_login_keeps_contact_email_test.dart`: a fresh login with a relay session address keeps a stored `lee@example.com`; a real session address still replaces an empty profile email.
- [ ] `flutter analyze` clean on touched files.
- [ ] Retest on a simulator (retest ticket 30, next test wave): email/password account shows read-only; the relay case needs a real Apple hidden-address account (device check, Lee's phone) and is noted as such.

Next: /testing-wave develop-2026-10 (fix wave 4)
