# 119-002 · Editing Email on Profile & Preferences saves an address the athlete cannot sign in with, and the next sign-in silently puts the old one back

- kind: bug
- status: triaged
- ticket: 119
- run: w36-20260926T0031Z
- screen: Profile & Preferences
- decision: 

**Steps.**
Retest of 31-007 (Profile & Preferences: edit the Email field and save), on the throwaway lee+e2e-119-20260926T0046Z (user b232e944).
1. Settings > Profile & Preferences. Change Email to lee+e2e-119-20260926T0046Z-new@rightpathprogramming.com, Save Changes (00:51:30Z).
2. Read public.users.email and auth.users.email by SQL. Look at Settings' Account card.
3. Sign out. Log in with the new address and the account's password (00:52:21Z), then with the old one (00:52:55Z).
4. Read both emails again.

**Expected.**
Either the field is read-only, or the change goes through the auth email-change flow; public.users.email never differs from the login email.

**Actual.**
1. Save shows success. public.users.email = the new address; auth.users.email = the old one, email_change empty: no confirmation mail, no auth change.
2. Settings' Account card then reads "Signed in with Email" and the new address, which is not a login.
3. Logging in with the new address: "Login failed. Please check your credentials." The old address logs in.
4. After that sign-in, public.users.email is the old address again (updated_at 00:52:59Z): the edit is undone without a word, and Profile & Preferences shows the old address.

So the field looks editable and saves "successfully", but it can never change the login, and it can change what coaches and support see only until the next sign-in. Product question for Lee: should Email be read-only here (change it through a proper auth email-change flow elsewhere, with a confirmation mail), or should this field start that flow?

Old Finding: 31-007.

**Evidence.**
- runs/119/48-email-edited.png: the edited field
- runs/119/db-31-007-after-email-save.txt: public vs auth email after the save
- runs/119/52-login-new-address.png: Login failed with the new address
- runs/119/53-login-old-address.png: the old address signs in
- runs/119/db-31-007-after-relogin.txt: public.users.email back to the old address after sign-in
- runs/119/54-settings-after-relogin.png: Settings showing the old address again

**Decision quote.**
> 

**Triage.**

Fix ticket 138, Settings, connections, allergies, Garmin (Lee, 2026-09-26). Ruling: Email on Profile & Preferences is read-only ("Your login email"). A change-email flow can come later (138). Closed by the retest after it merges. Record: `triage-20260926.md`.
