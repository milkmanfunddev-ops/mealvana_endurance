# 30-015 · Delete Account: untried paths (Cancel on the dialog, delete-user answering 500, Sign Out dialog text, region cache after delete)

- kind: followup-test
- status: open
- ticket: 30
- run: w3-20261008T1255Z
- screen: Settings
- decision: 

**Steps.**
1. Delete Account → Cancel (`settings.confirm_cancel` today): nothing deleted (SQL), still signed in.
2. Delete with `netcut slow 15000 --only <supabase host>` so delete-user times out mid-flight: what the athlete sees,
   whether the account is gone, and whether a retry double-deletes.
3. Sign Out dialog (all raw keys in this run, 30-001): once the keys show words, check the text matches ticket 35's
   ruling (no guest mode).
4. After a delete, read `privacy_*` prefs: the region cache survives the delete (seen: `geo GB` and C's `analytics_consent_*`
   = denied/strict stayed after C's delete at 13:25:58Z, prefs-after-C-delete.txt; 01-012 territory). Decide whether a deleted athlete's consent answer (`analytics_consent_*`) should
   survive to the next person on the device.

**Expected.**
Cancel deletes nothing; a slow delete tells the truth; prefs left on the device are only what the next user may inherit.

**Actual.**
Not run.

**Evidence.**
- runs/30/30a-22-delete-dialog.png
- runs/30/30b6-01-signout-dialog.png
- runs/30/prefs-after-C-delete.txt

**Decision quote.**
> 

**Triage.**
