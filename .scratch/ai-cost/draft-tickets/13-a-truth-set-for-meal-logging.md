# 13: A truth set for meal logging

**Status:** ready-for-human
**Blocked by:** none
**Next:** `/mattpocock-skills:implement 13 ai-cost`
**Model:** opus
**Due:** October

**What to build:** No ground truth exists: the July benchmark scored three Claude models against each other and they disagreed by 20 to 47% on calories. The 07-30 revert to Sonnet (`2dbd554c`) measured nothing. Someone has to weigh meals.

**Spec:** .scratch/ai-cost/spec.md
**Research:** docs/research/ai-cost-model-bakeoff.md

**Touches:** benchmarks/, scripts/

- [ ] 60 text and 40 photo cases from weighed meals with USDA macros, stored under `benchmarks/`.
- [ ] A harness that runs any gateway model id over the set from one env var and reports carb error, signed bias, cost and latency.
- [ ] Pass mark recorded: carbs within 15 g or 20% per meal, signed carb bias under 5%, never worse than Sonnet 4.6.

Next: /mattpocock-skills:implement 13 ai-cost
