# 89-017 · Previous lists and Shopping: delete and rename with the network cut, Share and Kroger on a rebuilt plan list

- kind: followup-test
- status: open
- ticket: 89
- run: w29-20260925T1950Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
1. Previous lists > a row's ⋮ > Delete and Rename with the app's network cut (19-007 step 5's offline half; 20-004 covers the tab's menu, not the sheet's).
2. Share on the confirmed plan's list (rebuilt after a delete) and Shop with Kroger from it.
3. The Shopping tab right after Rebuild shopping list: it showed the old list for ~5 s (runs/89/33-after-rebuild.png); check whether a tick in that window lands on the wrong list.

**Expected.**
Offline writes refuse with a message and leave the sheet and DB agreeing; the rebuilt list is the one shared and sent to Kroger.

**Actual.**
Not run (followup).

**Evidence.**
- runs/89/33-after-rebuild.png: the old list just after Rebuild.
- runs/89/34-after-rebuild-10s.png: the rebuilt list.

**Decision quote.**
> 

**Triage.**
