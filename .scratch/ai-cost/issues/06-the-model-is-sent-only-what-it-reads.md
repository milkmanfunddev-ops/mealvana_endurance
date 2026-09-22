# 06: The model is sent only what it reads

**Status:** done (wave 4, 2026-09-22)
**Blocked by:** 02 (touches supabase/functions/_shared/vana/tools.ts), 04 (touches supabase/functions/_shared/vana/chat.ts), 05 (touches supabase/functions/_shared/vana/chat.ts).
**Next:** `/implement-lee ai-cost`
**Model:** fable

**What to build:** Vana answers the same and the pickers look the same, and a planning conversation stops growing by about 10,000 tokens per picker. An opener arrives after one model step, not two.

**Decisions:** mp-420, mp-432; approved as mp-471.

**Touches:** supabase/functions/_shared/vana/tools.ts, supabase/functions/_shared/vana/chat.ts, supabase/functions/tests/vana, scripts/vana-eval

- [x] The meal picker returns a full form to the app and a compact form to the model: the meals shown plus a count of the rest. The app-facing part is unchanged against the frozen contract fixtures.
- [x] Every other tool the audit lists as oversized has a model-facing form under a stated size budget (one test per tool).
- [x] Replay uses the compact form, and the picker message is stored once.
- [x] A turn ends when Vana asks a choice, hands off, or saves feedback silently; the stop conditions are checked against the pinned SDK version. The live opener eval asserts one model step.
- [x] On dev, input tokens on the fourth planning turn of a scripted conversation are recorded in this ticket before and after (expect about 72k to fall under 35k).

## Dev measurement (2026-09-22)

`scripts/vana-eval/run.ts --only happy-path --skip-confirm` as the entitled dev account (test@test.com), the rows read
back from `vana_calls` on DEV (`vlmtsdzpnjnavdgytcmi`). Before = the base `8499daa0` as deployed by wave 3; after =
`adad0d7b` deployed to dev (vana-chat, jade-chat, vana-action, vana-day-notes, describe-meal, analyze-meal-photo).

| call | before: input tokens (steps) | after: input tokens (steps) | after: first-step input |
|---|---|---|---|
| 1 opener | 31,056 (2) | 15,351 (1) | 15,351 |
| 2 | 59,168 (3) | 31,074 (2) | 15,145 |
| 3 | 74,145 (2) | 15,995 (1) | 15,995 |
| **4** | **91,026 (2)** | **49,662 (3)** | **16,150** |
| 5 | 91,993 (2) | 17,181 (1) | 17,181 |
| 6 | 46,041 (1) | 35,087 (2) | 17,260 |
| whole conversation | 393,429 in · $0.227 | 164,350 in · $0.098 | |

The fourth call fell from 91k to 50k. It did not land under 35k because that turn ran three model steps (setSetting,
suggestMeals, then the sentence after the picker); per step it is 16k, where it was 45k. The two conversations took
different paths (the before run opened on a pending debrief, so its pickers landed on calls 2 and 3), which is why the
per-step figure is the like-for-like one. Every turn that ended on a question ran one step. Each picker row is stored
once: `metadata.ui_parts` is null on every after row, where before it duplicated the 44k-character `parts`.

What the measurement also shows, for ticket 07: every one-step turn read 0 tokens from the cache (a plan write between
turns rebuilds the athlete context, and tools, persona and context are one block). The cache reads seen here are all a
turn's second step reading its own first step.

Next: /implement-lee ai-cost
