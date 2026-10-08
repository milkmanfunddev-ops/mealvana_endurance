# 01-016 · Delete Account: offline, server failure, double tap, and signing in with the deleted address

- kind: followup-test
- status: closed
- ticket: 01
- run: w1-20261007T1103Z
- screen: Settings
- decision: 

**Steps.**
1. Cut the network (`netcut.sh on`), Settings → Delete Account → Delete. From code (`settings_controller.dart` deleteAccount, unverified): a non-200 from delete-user is logged and local cleanup continues, then the screen goes to Welcome. Check what the athlete is told and whether the server account remains (earlier rounds' "failed delete-user is reported to the athlete" and 121-007).
2. Tap Delete twice quickly on the confirm dialog.
3. After a successful delete: "I already have an account" with the deleted address and its old password; expect a clear error.
4. Sign up at an address that already has a live account.
5. The confirm dialog's strings are hardcoded in `settings_screen.dart` (earlier round's finding on hardcoded strings): not re-checked here.

**Expected.**
A failed delete never reports success or drops the athlete on Welcome with the server account alive; a double tap deletes once; sign-in with a deleted account gives a clear error.

**Actual.**
Not run (look-around). In this run the delete succeeded three times, Cancel kept the account three times, and the confirm dialog showed every time.

**Evidence.**
- runs/01/24-delete-dialog.png
- runs/01/db-A-after-cancel.txt
- runs/01/db-A-after-delete.txt

**Decision quote.**
> 

**Triage.**
retest ticket 30 (retest: auth and account), wave 3 (Lee: all 27 followups into four retest tickets)

**Closed (wave 3, 2026-10-08).** retest passed in ticket 30 (runs/30/notes.md, PASS 01-016)
