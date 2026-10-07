# 02-013 · Mobile MCP agent would not start on wave-pool-2; idb fallback carried the run

- kind: idea
- status: closed
- ticket: 02
- run: w1-20261007T1103Z
- screen: none
- decision: 

**Steps.**
Idea (process): the mobile MCP's first command on wave-pool-2 failed with "failed to start agent … timed out waiting for WebDriverAgent to be ready", so this run drove the app only with `idb ui tap` / `idb ui text` / `idb ui describe-all`, which worked throughout. The wave lead could check the MCP helper on each wave simulator after `simulator.mjs claim` (one `mobile_take_screenshot`), and the runbook could name idb as an equal path rather than a fallback.

**Expected.**
Agents know before the run whether the MCP works on their simulator.

**Actual.**


**Evidence.**
- runs/02/notes.md — the MCP error and the idb fallback

**Decision quote.**
> 

**Triage.**
IMPROVEMENTS entry: the mobile MCP helper fails to start on a wave simulator; idb-first is the runbook's fallback and carried a full run
