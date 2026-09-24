# 31-004 · Profile & Preferences: clear a first or last name and save, check the name is cleared

- kind: followup-test
- status: open
- ticket: 31
- run: w11-20260924T1648Z
- screen: Profile & Preferences
- decision: 

**Steps.**
1. On an account with a first or last name set, open Profile & Preferences.
2. Clear the First name field and tap Save Changes.
3. Read public.users.first_name by SQL and reopen the screen.

**Expected.**
The name is cleared in the app and in the database.

**Actual.**
Not run. Why it is worth running: the save path passes null for an empty field and the controller keeps the existing value when the new one is null (settings_controller.dart _saveProfile, `firstName: currentState.firstName ?? existingProfile.firstName`), so a name may be impossible to remove once set. test@test.com has no names, which is why this run changed the water-bottle setting instead.

**Evidence.**
- 

**Decision quote.**
> 

**Triage.**
