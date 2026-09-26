# Ticket 119 verdicts (wave 36, run w36-20260926T0031Z, app 72d3723e)

| id | verdict | evidence (under runs/119/) | new Finding |
|---|---|---|---|
| 31-002 | pass | 05-tree-checked.json: water bottle is CheckBox (role switch), AXValue 0 unticked (tree-profile-prefs.txt), 1 ticked; 05-hydration-checked-unsaved.png | |
| 31-004 | pass | db-31-004-after-clear.txt: first_name NULL, last_name kept; 47-reopen-first-cleared.png; field still empty after a relaunch (notes.md) | |
| 31-005 | pass | 06-after-orange-back.png, 07-after-swipe-back.png; db-31-005-after-back-arrow.txt, db-31-005-after-swipe.txt: nothing written, reopened unticked. Dropped with no prompt (idea 119-010) | |
| 31-006 | pass | 08-after-tp-name-chip.png, 09-after-gender-chip.png, 10-after-birthday-chip.png, 11-after-fs-chip.png: each chip fills only its field; db-31-006-after-chips-leave.txt: nothing written after leaving. Chips show while TrainingPeaks is requires_reauth | |
| 31-007 | fail | db-31-007-after-email-save.txt (public new, auth old), 52-login-new-address.png, db-31-007-after-relogin.txt (reverted at sign-in) | 119-002 |
| 31-008 | fail | 12-offline-save-1s.png, db-31-008-online-6min.txt (dev false 8 min online), db-31-008-after-signout.txt (true only at sign-out) | 119-001 |
| 31-009 | pass | 35-light-after-relaunch.png (Light kept), 43-after-purchase.png (carries to another account: per device), 57-dark-restored-after-relaunch.png (Dark back). Light Timeline unreadable: 119-003. System not tried: 119-011 | 119-003 |
| 31-011 | pass | 30-signout-dialog.png, 31-after-signout-cancel.png, 32-delete-dialog.png, db-31-011-test-after-cancels.txt (rows kept); past Cancel on the throwaway: 51-welcome-after-throwaway-signout.png, db-throwaway-after-delete.txt, revenuecat-throwaway-after-delete.json | |
| 31-013 | pass | 20-subscription.png, 22-diet-allergies.png, 23-sport-preferences.png, 24-body-composition.png, 25-nutrition-targets.png, 26-coach-connection.png, 27-connected-apps.png, 28-privacy.png, 29-help-feedback.png: each opened and returned; problems filed as 119-006, 119-007, 119-008, 119-009 | 119-007, 119-008 |
