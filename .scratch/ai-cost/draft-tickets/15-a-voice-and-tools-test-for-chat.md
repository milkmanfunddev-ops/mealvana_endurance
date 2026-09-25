# 15: A voice and tools test for Vana, ready for the Haiku retirement

**Status:** ready-for-agent
**Blocked by:** 04
**Next:** `/mattpocock-skills:implement 15 ai-cost`
**Model:** fable
**Due:** before 2026-10-15

**What to build:** `scripts/vana-eval` checks structure by regex, tests whatever dev runs, and has one general conversation. Haiku 4.5 is listed as not retiring before 2026-10-15 (unverified), so this is needed whatever happens on cost. Planning stays on Haiku: no cheaper model has credible recent tool-calling scores.

**Spec:** .scratch/ai-cost/spec.md
**Research:** docs/research/ai-cost-model-bakeoff.md

**Touches:** scripts/vana-eval/

- [ ] 30 conversations (at least 10 general), each run three times, model chosen by env var.
- [ ] Metrics: tool exact-match, zero fuelling numbers invented by the model, steps per turn, cost in dollars, and a binary voice judge.
- [ ] The voice judge is calibrated against 100 turns Lee labels (ready-for-human step inside this ticket).
- [ ] A baseline run on Haiku 4.5 is recorded.

Next: /mattpocock-skills:implement 15 ai-cost
