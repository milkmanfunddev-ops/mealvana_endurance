# 02-006 · Settings Delete Account confirm uses hardcoded strings while the paywall's uses the content system

- kind: bug
- status: triaged
- ticket: 02
- run: w2-20260923T1442Z
- screen: Settings
- decision: 

**Steps.**
1. Signed in past the paywall, open Settings, scroll to Account, tap Delete Account.

**Expected.**
The confirm dialog's title, body and buttons come from the content system, as the paywall's
delete confirm does (ContentKeys.paywallDeleteConfirm*). CLAUDE.md: no hardcoded user-facing
strings where the content system exists.

**Actual.**
"Delete Account?", "This will permanently delete your account and all associated data. This
action cannot be undone.", "Cancel", "Delete" and the "Delete Account" button label are literals
in settings_screen.dart (around lines 700-750). The two delete confirms therefore read
differently ("Delete account?" / "This permanently deletes your account and all of its data").

**Evidence.**
- runs/02/14-settings-delete-confirm.png, runs/02/07-delete-confirm-A.png
- lib/features/settings/presentation/screens/settings_screen.dart, the Delete Account TextButton

**Decision quote.**
> 

**Triage.**
Fix ticket 47 (Lee, 2026-09-25). Closed by the retest after it merges.
