# 32-011 · Follow-up: Connected Apps untried paths (hidden workouts after reconnect, Delete synced data, V.O2 and Runna Connect, sharing-sheet Turn Off)

- kind: followup-test
- status: triaged
- ticket: 32
- run: w3-20261008T1256Z
- screen: Connected Apps
- decision: retest ticket 50 (startup, tabs, learn, connected apps), wave 5

**Steps.**
1. The Disconnect dialog says hidden workouts "come back if you reconnect". This run hid 43 TrainingPeaks
   workouts and the reconnect (a different TP athlete: "Lee Martin" instead of "Xuan Huang") imported 0.
   Reconnect the same athlete after a disconnect and check the Timeline gets its workouts back.
2. "Delete synced data" on a disposable account: what goes, on the server and locally.
3. V.O2 Connect after the disconnect (no test login: check the sheet opens and Cancel is clean); Runna Connect.
4. The TrainingPeaks sharing sheet's Turn Off Sharing, then the "Write fuel plan to TrainingPeaks" checkbox.
5. Long-press discoverability: the "Tip: Long-press Sync Now to disconnect" line sits below the fold.

**Expected.**
Each path ends in a state the card, the Timeline and the `integrations` row agree on.

**Actual.**
Not run.

**Evidence.**
- runs/32/m11-after-allow.png the sharing sheet
- runs/32/m14-connected-apps-reentered.png the cards after the section

**Decision quote.**
> 

**Triage.**
