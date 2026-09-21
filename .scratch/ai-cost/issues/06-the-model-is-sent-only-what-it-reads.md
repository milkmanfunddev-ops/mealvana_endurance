# 06: The model is sent only what it reads

**Status:** ready-for-agent
**Blocked by:** 02 (touches supabase/functions/_shared/vana/tools.ts), 04 (touches supabase/functions/_shared/vana/chat.ts), 05 (touches supabase/functions/_shared/vana/chat.ts).
**Next:** `/implement-lee ai-cost`
**Model:** fable

**What to build:** Vana answers the same and the pickers look the same, and a planning conversation stops growing by about 10,000 tokens per picker. An opener arrives after one model step, not two.

**Decisions:** mp-420, mp-432; approved as mp-471.

**Touches:** supabase/functions/_shared/vana/tools.ts, supabase/functions/_shared/vana/chat.ts, supabase/functions/tests/vana, scripts/vana-eval

- [ ] The meal picker returns a full form to the app and a compact form to the model: the meals shown plus a count of the rest. The app-facing part is unchanged against the frozen contract fixtures.
- [ ] Every other tool the audit lists as oversized has a model-facing form under a stated size budget (one test per tool).
- [ ] Replay uses the compact form, and the picker message is stored once.
- [ ] A turn ends when Vana asks a choice, hands off, or saves feedback silently; the stop conditions are checked against the pinned SDK version. The live opener eval asserts one model step.
- [ ] On dev, input tokens on the fourth planning turn of a scripted conversation are recorded in this ticket before and after (expect about 72k to fall under 35k).

Next: /implement-lee ai-cost
