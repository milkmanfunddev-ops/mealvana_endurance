# 88-012 · Offline, the Meal plans list spins for good and an opened conversation shows as an empty New meal plan

- kind: bug
- status: triaged
- ticket: 88
- run: w29-20260925T1949Z
- screen: Conversations; Vana chat (meal planning)
- decision: 

**Steps.**
1. Retest of 15-006 step 1 and 16-008. App relaunched with netcut, netcut on. Ask Vana > full screen > Conversations > Meal plans (20:16:43Z); wait 35 s.
2. Netcut off, reload the list, netcut on (20:17:43Z), open Sep 22 6:59 AM (`0b7df6f0`, never opened on this install, 11 messages, archived 6f365c30 with 2 meals).
3. Back; open Sep 25 2:58 PM (`ebac747d`, opened online earlier this session). Then netcut off with it open (20:18:29Z) and wait 12 s.

**Expected.**
A cached history or a clear offline/retry state, never the empty state of a new chat (15-006, 16-008); the list says it can't load and offers a retry.

**Actual.**
Step 1: a spinner under RECENT for 35 s and more, no rows, no message; the console repeats `[VANA_CHAT_REPOSITORY] fetchConversations(meal_planning) failed`. Switching tabs after going online loaded the list. Steps 2 and 3: the chat opens headed "New meal plan", no history, bar "Your plan · 0 meals", the same screen as a brand-new plan; nothing says it is offline. Back online the open chat does not recover by itself (still empty 12 s later); leaving and reopening loads it. An athlete who types here would be writing into what looks like a new plan. Online after a kill and relaunch, the same conversation opened with its history (15-006 step 2 passes); a fast switch between two conversations showed only the second's (step 4 passes).

**Evidence.**
- runs/88/82-15-006-conversations-offline.png, runs/88/84-15-006-conversations-offline-35s.png: the spinner.
- runs/88/85-15-006-offline-open-unopened-3s.png, runs/88/86-15-006-offline-open-unopened-15s.png: 0b7df6f0 as an empty "New meal plan".
- runs/88/87-15-006-offline-open-ebac747d.png, runs/88/88-ebac747d-after-back-online-12s.png
- runs/88/console-redacted.log: fetchConversations failed lines, 15:16–15:17 local.

**Decision quote.**
> 

**Triage.**

Fix ticket 129 (Lee, 2026-09-25). Closed by the retest after it merges.
