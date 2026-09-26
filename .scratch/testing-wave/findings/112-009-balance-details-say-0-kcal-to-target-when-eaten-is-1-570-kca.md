# 112-009 · Balance details say "0 kcal to target" when eaten is 1,570 kcal over the target

- kind: bug
- status: triaged
- ticket: 112
- run: w34-20260925T2320Z
- screen: Timeline (net balance details)
- decision: 

**Steps.**
1. Today, after this run's logs: timeline → Expand details on NET BALANCE (23:40:19Z).

**Expected.**
Over target reads as over ("1,570 kcal over"), not as a target already met exactly.

**Actual.**
"Eaten 4,632 / 3,062" next to "0 kcal to target". The remaining figure clamps at 0.

**Evidence.**
- runs/112/60-offline-balance-details.png

**Decision quote.**
> 

**Triage.**

Held for Xuan (Lee, 2026-09-26): the fix would change "kcal to target", ratified in her `energy-card.md`. Taken out of ticket 137; goes to Xuan with the SSOT pass.
