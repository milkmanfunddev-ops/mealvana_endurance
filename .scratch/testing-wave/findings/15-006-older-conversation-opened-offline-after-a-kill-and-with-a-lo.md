# 15-006 · Older conversation opened offline, after a kill, and with a long transcript: history, plan bar and scroll position

- kind: followup-test
- status: closed
- ticket: 15
- run: w12-20260924T1712Z
- screen: Vana chat (meal planning), opened from Conversations
- decision: 

**Steps.**
1. Open an older meal-plan conversation once online, then turn the network off (simulator: Network Link Conditioner 100% loss) and open it again, and open one never opened on this install.
2. Kill the app while a conversation is open; relaunch; open it from Conversations.
3. Open the longest stored conversation (`4a774c41`, 15 turns, general; `f6a0f7fa`, 15 turns, meal planning) and scroll top to bottom; compare turn count with vana_messages.
4. Open two conversations one after the other quickly (back, then the next row) and check the second never shows the first's turns or plan bar.

**Expected.**
Offline: the cached history with a clear offline or retry state, never the empty "Ask me anything" state of a new chat (16-008). After a kill: the same turns and plan bar. Long transcripts: every stored turn, in order, opening at the newest turn. No turns or plan bar carried over from the previous conversation.

**Actual.**


**Evidence.**
- runs/15/turns-vs-db.md — how this run matched turns to rows.

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 88 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).

Run by retest ticket 88 (run w29-20260925T1949Z, build e3367d2c): fail, filed as 88-012, 88-024; closed here, the new Findings carry it.
