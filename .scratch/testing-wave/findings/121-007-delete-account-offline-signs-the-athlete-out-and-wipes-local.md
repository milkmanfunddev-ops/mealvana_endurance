# 121-007 · Delete account offline signs the athlete out and wipes local data but keeps the server account, with no message

- kind: bug
- status: open
- ticket: 121
- run: w34-20260925T2320Z
- screen: Paywall
- decision: 

**Steps.**
1. A never-paid account on the paywall; `netcut.sh on --relaunch` (23:30:35Z).
2. ⋯ → Delete account → Delete (23:31:50Z).
3. Online again, SELECT auth.users and public.users; RevenueCat customer.

**Expected.**
86-011: a clear failure message, the athlete still signed in, the account and its local rows kept; no half delete.

**Actual.**
Welcome within 0.5 s, no message. Console: `Error calling delete-user Edge Function` (SocketException), `[RevenueCatService] logOut failed … NETWORK_ERROR`, then `Signing out user with scope: local`, `user_signed_out`, /welcome. Online at 23:32:11Z the account is whole on the server: auth.users and public.users rows for 9cd57a3f-cc25-429d-8929-8dfc0d9e4ffb, RevenueCat customer present. The athlete believes the account is gone. At e3367d2c `SettingsController.deleteAccount` logs a failed delete-user call and carries on with local cleanup and sign-out ("Continue with local cleanup even if edge function call fails"); the same path serves Settings → Delete account. The account was then deleted online through the paywall (23:33:16Z), which worked.

**Evidence.**
- runs/121/31-offline-delete-contact.png
- runs/121/32-after-offline-delete.png
- runs/121/db-rc-B-after-offline-delete.txt
- runs/121/db-rc-B-after-online-delete.txt
- runs/121/console-redacted.log (18:31:51 local)

**Decision quote.**
> 

**Triage.**

