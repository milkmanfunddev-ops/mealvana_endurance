# 31-001 · Raw content keys shown as text: Timeline Reconnect notice and the meal card's Save as favorite button

- kind: bug
- status: open
- ticket: 31
- run: w3-20261008T1256Z
- screen: Timeline
- decision: 

**Steps.**
1. Sign in as test@test.com on a cleared app (12:57:55Z); TrainingPeaks and V.O2 refresh tokens are dead, so both rows go to requires_reauth (12:58:06Z).
2. Look at the Timeline under + Add Food.
3. Log any meal, open its card's ⋯ menu.

**Expected.**
The Reconnect notice reads "{provider} needs you to sign in again to keep syncing." with a "Reconnect" action, and the third card action reads "Save as favorite" (all three keys are in assets/config/content_defaults.json under `connections` and `meal_log_actions`).

**Actual.**
The notice shows the literal keys `connections.reconnect_notice` (wrapped one syllable per line, "con / nect / ions / .rec / …") and `connections.reconnect_notice_action`; the card menu's third button reads `meal_log_actions.save_as_favorite`. `ContentService.getValue` falls back to the key itself when the loaded content lacks it (content_service.dart:71-75, from code), so the bundled defaults are not reached for keys added by ticket 29's backports. The notice was gone after a relaunch at 12:59:09Z with nobody dismissing it, while both integrations were still requires_reauth (see the followup Finding). Same root likely affects every content key ticket 29 added; not checked one by one.

**Evidence.**
- runs/31/03-after-notif-prompt.png — Reconnect notice made of raw keys
- runs/31/32-card-menu.png — card menu button `meal_log_actions.save_as_favorite`
- runs/31/notes.md — times and integration states
- runs/31/db-before.txt — integrations before sign-in (training_peaks `error`)

**Decision quote.**
> 

**Triage.**

