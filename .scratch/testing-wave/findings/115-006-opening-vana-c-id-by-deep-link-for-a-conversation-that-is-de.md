# 115-006 · Opening /vana?c=<id> by deep link for a conversation that is deleted, archived or belongs to another account

- kind: followup-test
- status: triaged
- ticket: 115
- run: w32-20260925T2219Z
- screen: Vana chat
- decision: 

**Steps.**
1. Signed in as an account, `xcrun simctl openurl UDID "com.milkman.mealvanaendurance:///vana?c=<id>"` with <id> = (a) a deleted conversation, (b) an archived plan's conversation, (c) another account's conversation id, (d) a random uuid.
2. Note what the chat shows and whether any vana_calls row or message is written.

**Expected.**
(a), (c), (d): a plain "not found" and no model call, never another account's messages; (b): the conversation read-only with its archived bar.


**Actual.**
Not run. This run used the deep link to open the draft's own conversation 7cc15497 with no model call (30-draft-conversation.png); the route takes any id from outside the app.


**Evidence.**
- runs/115/30-draft-conversation.png — the deep-linked draft conversation.
- runs/115/notes.md — the 16-003 path line.

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
