# 16: Simple general turns on a cheap model, if the voice holds

**Status:** needs-info
**Blocked by:** 15, 07
**Next:** `/mattpocock-skills:implement 16 ai-cost`
**Model:** fable
**Due:** after 15

**What to build:** 55% of general turns call no tool. A cheap model with one escape tool (`needVana`) could take them, worth $0.10 to $0.17 a month, and it is what makes "general chat carries on at zero credits" possible (mp-430 clause 6). Only if ticket 15's voice judge passes it.

**Spec:** .scratch/ai-cost/spec.md
**Research:** docs/research/vana-cost-and-pricing.md lever 5; ai-cost-model-bakeoff.md

**Touches:** supabase/functions/_shared/vana/chat.ts

- [ ] Router eval result recorded.
- [ ] A proposal card on the decisions page before any build.

Next: /mattpocock-skills:implement 16 ai-cost
