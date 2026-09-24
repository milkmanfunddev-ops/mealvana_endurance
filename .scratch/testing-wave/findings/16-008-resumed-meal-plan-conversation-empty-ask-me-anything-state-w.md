# 16-008 · Resumed meal-plan conversation: empty Ask me anything state while a vana-action call hangs to a socket timeout

- kind: followup-test
- status: open
- ticket: 16
- run: w9-20260924T1446Z
- screen: Vana chat (meal planning), opened from Conversations
- decision: 

**Steps.**
1. Signed in, open Conversations → Meal plans → an older conversation with history.
2. Watch the screen for the first minute, with the console and the vana-action request log side by side.
3. Repeat with a slow network (Network Link Conditioner) and with the server unreachable.

**Expected.**
A loading state while history and the conversation's draft are fetched, then the history and plan bar; on a failed or slow fetch, an error with a retry. Never the empty "Ask me anything" state of a new chat.

**Actual.**
Seen this run, not settled. The first open of `d8efbdb3` (09:50:29 local) showed the empty "Ask me anything" state, with no history and no plan bar, until I went back at 09:51:40. The server logged no vana-action request for that open: its request log has vana-action at 09:49:29 and next at 09:51:47, which was the next conversation. At 09:52:47 the console logged `SocketException: Operation timed out … /functions/v1/vana-action` from VanaTransport.postJson. The chat awaits `_loadDraft` (get_plan) inside `build`, so a hung get_plan would hold the empty state. Opening `d8efbdb3` again at 09:52:53 loaded in about 4 s. The mobile MCP's screenshots on this simulator were also stale once (see notes), so the first-open screenshot was discarded; this needs a clean repeat.

**Evidence.**
- runs/16/console-excerpts.log — lines 27612 (open), 29280 (back), 31527–31536 (socket timeout on vana-action).
- runs/16/edge-requests.txt — no vana-action between 09:49:29 and 09:51:47.

**Decision quote.**
> 

**Triage.**

