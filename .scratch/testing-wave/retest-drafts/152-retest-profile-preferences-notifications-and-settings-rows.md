# 152: Retest: Profile & Preferences, notifications, Body Composition and the Settings rows

**Status:** ready-for-agent
**Blocked by:** 138.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** fix ticket 138 and the 2026-09-26 triage, about ten checks a run.

**What to build:** A retest run on the testing build (`app-build.json`). It re-runs each Finding's steps against ticket 138's fixes and runs the folded Settings follow-ups. Nothing is fixed during the run. Follow `RUNBOOK.md`.

**Accounts and start state:** account E, new, `lee+e2e-152-<UTC>`, bought Annual. Checks 1-5 and 7-9 use E. Check 6 needs test@test.com's Garmin weight and is read only there. App data cleared. Notification permission is fresh on a cleared app. Check 5 starts from E's very first sign-in, so plan it first.

**Shared account:** test@test.com, read only (check 6 opens Body Composition and saves nothing).

**COST:** none.

## Checks

1. **Email is read-only (119-002).** E > Settings > Profile & Preferences. *Pass:* Email shows as read-only text labelled "Your login email". A Save of another field leaves `public.users.email` and `auth.users.email` unchanged. *Verify:* screen, SELECT both.
2. **Discard changes? on leaving (119-010).** Change gender and tick a chip, then (a) the top back arrow, (b) the bottom back arrow, (c) the iOS swipe. *Pass:* each asks "Discard changes?" (Discard / Keep editing). Keep editing keeps the edits. Discard writes nothing. With no changes, back leaves at once. *Verify:* screen, SELECT `users.updated_at`.
3. **An offline save uploads when back online (119-001).** `netcut.sh on --relaunch`, tick "I run with a water bottle", Save. `off` without sign-out or relaunch, wait 60 s. *Pass:* `users.runs_with_water_bottle` is true on dev by then (resume at the latest), not only at sign-out. *Verify:* SELECT after 0, 30 and 60 s.
4. **Save offline, then sign out offline (119-012).** `on --relaunch`, change a field, Save, Settings > Sign Out > Sign out (still offline). `off`, Log In as E. *Pass:* the field has the new value in the app and by SQL, or the sign-out says clearly that the change stays on this phone (the offline sign-out line, 120-006) and it is sent at the next sign-in. Nothing is lost silently. *Verify:* screen, SELECT.
5. **Notifications: asked once after sign-in, answer stored (125-004).** At E's first sign-in (cleared app). *Pass:* the iOS prompt shows right after sign-in, not on the second launch. Allow writes `users.notifications_enabled = true`. It does not ask again on relaunch. Turn notifications off in iOS Settings for "Endurance Dev", resume the app: the column turns false. *Verify:* screenshots, SELECT after each step.
6. **Garmin chip only when it differs (119-007).** test@test.com > Settings > Body Composition (read only; save nothing). *Pass:* where the weight field already reads the Garmin value (185 lb), the plain source pill shows, not "Garmin · 185 lb, tap to use". *Verify:* screenshot, SELECT the stored weight and the Garmin value if stored.
7. **Privacy: analytics off stops events (119-016).** E > Settings > Privacy > Share anonymous usage data off. Open three screens, relaunch, open three more. Turn it back on. *Pass:* no `[ANALYTICS]` send lines while off, and they resume when on. *Verify:* console-redacted.log.
8. **Help & Feedback: Rate and Report (119-017).** Rate Your Experience: pick a score, then cancel, not send. Report a Bug: it opens the same report as shake (screenshot, mark-up). Cancel it. *Pass:* both open and cancel cleanly. *Verify:* screenshots.
9. **The support address (119-009, rewritten).** As written it sent a test mail to the listed address, an external message the run may not send. Rewritten: read the address on Help & Feedback and the sender of E's sign-up code email (Gmail). *Pass or record:* if they differ (support@mealvana.com vs support@mealvana.io), file an idea Finding for Lee to say which inbox is read. Send no mail. *Verify:* screenshot, the Gmail message's From.

**Findings:** 119-002, 119-010, 119-001, 125-004, 119-007; follow-ups 119-012, 119-016, 119-017, 119-009 (rewritten).

**Decisions:** Lee's rulings in `triage-20260926.md` (119-002, 119-010, 125-004).

**Touches:** account E only (profile fields, notification setting, privacy toggle), deleted at the end. test@test.com read only.

- [ ] Runs by the runbook, with a look-around on every screen, nothing fixed. No RevenueCat or database writes the ticket doesn't name, even on your own account.
- [ ] `RUNS/verdicts.md`: one row per check and Finding id, with evidence under `runs/152/`.
- [ ] Each Finding listed is closed with evidence or a new bug Finding.
- [ ] Account E is deleted through the app at the end. No email is sent.

Next: /implement-lee testing-wave
