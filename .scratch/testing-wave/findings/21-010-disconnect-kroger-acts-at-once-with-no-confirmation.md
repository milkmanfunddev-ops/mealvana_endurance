# 21-010 · Disconnect Kroger acts at once with no confirmation
- kind: idea
- status: triaged
- ticket: 21
- run: w17-20260924T2233Z
- screen: Shop with Kroger
- decision: 

**Steps.**
1. Idea: ask before disconnecting Kroger. On Shop with Kroger, connected, tapping "Disconnect Kroger" (22:37:0x UTC) deleted the connection at once with no confirmation and no message; the Connect button simply came back. Reconnecting means the kroger.com sign-in again. The button sits right under "Add to Kroger cart", so a slipped tap costs a sign-in. A confirm, or at least a message saying it was disconnected, would help.

**Expected.**


**Actual.**


**Evidence.**
- runs/21/12-after-disconnect.png
- runs/21/db-kroger-after-disconnect.txt

**Decision quote.**
> 

**Triage.**
Fix ticket 82 (the wave lead, 2026-09-25: Lee asked for every bug fix that can be done without him). Closed by the retest after it merges.
Moved to retest ticket 111 when 90 was split (Lee, 2026-09-25).
