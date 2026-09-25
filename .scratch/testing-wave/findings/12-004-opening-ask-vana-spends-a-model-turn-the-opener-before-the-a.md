# 12-004 · Opening Ask Vana spends a model turn (the opener) before the athlete types, and the wave's cost counter has no kind for Vana chat

- kind: idea
- status: wontfix
- ticket: 12
- run: w4-20260924T0417Z
- screen: Vana
- decision: 

**Steps.**
Idea: the harness's `cost.mjs` knows `plan` and `logging` only. A Vana chat turn, and the opener that opening Ask Vana fires on its own, are neither. This run counted its two turns (opener + one message) as `logging` 1/5 and 2/5 for wave 4. Either add a `chat` kind with its own cap, or say in the spec that chat turns count as logging. Tickets that only open Vana to look should know it spends: the opener here cost $0.0214 (10,706 input tokens), more than the message itself ($0.0052).

**Expected.**

**Actual.**

**Evidence.**
- runs/12/db-admin-after.txt (vana_calls: vana.opener.general and vana.chat.general, both debited)
- runs/12/edge-logs-vana-console.txt

**Decision quote.**
> 

**Triage.**

Won't fix (Lee, 2026-09-25): the cost kind is done (`chat`, IMPROVEMENTS #45); the opener spending a turn before the athlete types is kept as product behaviour.
