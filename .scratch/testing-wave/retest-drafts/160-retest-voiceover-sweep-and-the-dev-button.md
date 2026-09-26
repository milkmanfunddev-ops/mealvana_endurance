# 160: Retest: the VoiceOver sweep and the one dev button

**Status:** ready-for-agent
**Blocked by:** 141.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** fix ticket 141 and the 2026-09-26 triage, about ten checks a run.

**What to build:** A retest run on the testing build (`app-build.json`). It reads the accessibility tree (`idb ui describe-all`, `describe-point`) on every screen ticket 141's sweep touched, and checks the dev button's new place. Onboarding is judged on labels only (its copy is Xuan's). Nothing is fixed during the run. Follow `RUNBOOK.md`.

**Accounts and start state:** app data cleared. Account AA, new (`CRED new`), made during check 1 (onboarding and Sign Up), left never paid for check 8, then bought Annual. test@test.com for checks 4-6 and 9 (read only). The dev pill is excluded from semantics: tap it by coordinate (centre x, just under the status bar; 141 notes).

**Shared account:** test@test.com (read only). Other runs may log meals on it.

**COST:** `logging` ×1 (check 7's photo Analyze). Spend before the tap. If the wave's cap is used, check 7 becomes a followup-test Finding.

## Checks

1. **Onboarding (118-005).** On each step: the back arrow is a button named "Back". The full-screen "Continue" element on "Tell us about yourself" is gone. Sport and obstacle tiles are buttons with a checked state. The first and last name fields keep their names once filled. *Verify:* `describe-all` per step, saved to `RUNS`.
2. **Sign Up with Email's eye buttons (118-005, 119-005).** *Pass:* both read "Show password", as Log In's does. Never tap them (#89). *Verify:* `describe-all`.
3. **Back arrows on the Log In chooser and New Event (124-005, 118-005).** *Pass:* each is a button named "Back", and the chooser's back arrow is in the tree. *Verify:* `describe-all`.
4. **Vana full screen and Browse (118-005).** test@test.com: open an old conversation by deep link (no spend). Back, New conversation, Conversations, Add and Dictate are named buttons. Browse: Back, Search meals, Filters are buttons, and the filter menu items are at least 48 pt tall. Do not tap New conversation. *Verify:* `describe-all`, frame heights.
5. **Connected Apps (118-005).** *Pass:* Reconnect and Sync Now are separate buttons, not parts of one image label. *Verify:* `describe-all`.
6. **Profile & Preferences, the theme dialog, Nutrition Targets (119-005, 119-006).** *Pass:* the bottom back arrow is "Back". The "tap to use" chips are buttons. Gender, units, gut-training and sweat options report selected. Email and Birthday have names. System / Light / Dark report selected. Nutrition Targets fields are named by their target, not "Auto". Open, read, leave: save nothing. *Verify:* `describe-all` before and after tapping one chip (then Discard).
7. **Review & Log's photo thumbnail (100-007).** AA: `COST spend WAVE logging 160`, Log a Meal > Describe > Gallery (a photo added with `simctl addmedia`) > Analyze. *Pass:* the thumbnail has a label such as "Photo being logged". Back without logging. *Verify:* `describe-all`.
8. **The paywall message's frame (118-006).** AA before buying: ⋯ > Restore purchases (no subscription), then `describe-point` at Continue's centre while the message shows, and tap Continue. *Pass:* the point reads Continue, not the message, and the tap reaches Continue. *Verify:* `describe-point` output, screen.
9. **One dev button at the top edge (100-001, 118-001, #98).** *Pass:* one small button just under the status bar, clear of the Dynamic Island, the date header and every back button. A tap offers both tools. Nothing sits at the bottom any more: `describe-point` inside the right end of Welcome's Build My Plan, paywall Continue and Monthly, Redeem, What's New's Got it, and Previous lists' fifth-row ⋮ (test@test.com) each reads that control. *Verify:* screenshots, `describe-point` outputs.

**Findings:** 118-005, 119-005, 124-005, 119-006, 100-007, 118-006, 100-001, 118-001.

**Decisions:** Lee's rulings in `triage-20260926.md` (onboarding labels only; dev buttons fold into one at the top edge, IMPROVEMENTS #98).

**Touches:** account AA (made, one analysis not logged, deleted at the end). test@test.com read only.

- [ ] Runs by the runbook, with a look-around on every screen, nothing fixed. No RevenueCat or database writes the ticket doesn't name, even on your own account.
- [ ] `RUNS/verdicts.md`: one row per check and Finding id, with evidence under `runs/160/` (the saved trees).
- [ ] Each Finding listed is closed with evidence or a new bug Finding.
- [ ] Account AA is deleted through the app.

Next: /implement-lee testing-wave
