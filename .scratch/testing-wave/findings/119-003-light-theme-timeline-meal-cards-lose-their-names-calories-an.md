# 119-003 · Light theme: Timeline meal cards lose their names, calories and times, and the header stays dark

- kind: bug
- status: triaged
- ticket: 119
- run: w36-20260926T0031Z
- screen: Timeline
- decision: 

**Steps.**
Found running 31-009, on test@test.com.
1. Settings > Appearance > Light (00:44:57Z). Settings turns light and reads well.
2. Relaunch the app (00:45:19Z) and look at the Timeline.

**Expected.**
Every Timeline card and label readable in Light, as in Dark.

**Actual.**
The pick survives the relaunch, but on the Timeline the meal cards show only the fork icon and the coloured macro numbers: the meal names ("Greek yogurt + honey", "W14-25 Built bowl", "Oatmeal + …"), the kcal figures and the time labels down the left (2:15 PM, 6:23 PM, 6:24 PM) are drawn in a colour that vanishes on the cream background, and so are the workout cards' time labels. The header block (date, net balance, filter bar) and the two workout cards stay dark plum. The accessibility tree still carries the names, so it is a colour problem. A new account signed up on the same device showed the same dark header on an empty light Timeline.

**Evidence.**
- runs/119/35-light-after-relaunch.png: Timeline in Light after the relaunch
- runs/119/43-after-purchase.png: the new account's Timeline in Light
- runs/119/57-dark-restored-after-relaunch.png: the same Timeline in Dark for comparison

**Decision quote.**
> 

**Triage.**

Fix ticket 137, Timeline and activities (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
