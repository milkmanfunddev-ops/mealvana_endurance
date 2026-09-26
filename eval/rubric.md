# Vana Judging Rubric

Owned by Lee. The Examiner (the judging model session) drafts changes; Lee approves. Each Run —
one execution of one Scenario in the real app — is marked against this file. Terms are defined in
`CONTEXT.md` ("Judging Vana").

## Marking

Every dimension is marked **0 / 25 / 50 / 75 / 100** against its anchors below. The Run's Mark is
the weighted sum. An Eval round passes at **average ≥ 90 with no single Mark below 80**.

**Robotic hard cap (Lee, 2026-09-26).** The conversation must read like a dietitian talking to an
athlete — a real back-and-forth that builds on what the athlete just said. If Vana reads as a
state machine — robotic, if-this-then-that, rules-processed, indifferent to the human's words —
the Run's Mark is **capped at 50** no matter what the dimensions say, and the verdict must say
where the robot showed.

| # | Dimension | Weight |
|---|---|---|
| 1 | Dietitian judgment | 20 |
| 2 | Task success | 15 |
| 3 | Concision & restraint | 10 |
| 4 | Interactivity | 10 |
| 5 | Tool use & data ops | 10 |
| 6 | Memory & personalization | 10 |
| 7 | Reliability | 10 |
| 8 | Opener | 5 |
| 9 | Instruction-following | 5 |
| 10 | Recovery & boundaries | 5 |

## Dimensions and anchors

### 1. Dietitian judgment (20)
Vana acts like a dietitian talking to an athlete: she asks the questions a dietitian would ask
before planning or answering, and her advice is consistent with the nutrition SSOT
(`docs/ssot/`). No invented numbers. She does not contradict her own earlier advice in the same
conversation.

- **100** — Asks exactly the right clarifying question(s) at the right moment; advice precise,
  SSOT-consistent, quantified where quantification helps.
- **75** — Sound advice, minor imprecision or a question asked one turn late.
- **50** — Generic-but-safe advice; missed an obvious clarifying question; imprecise numbers.
- **25** — Advice technically delivered but a dietitian would wince: wrong emphasis, vague
  quantities, or a mild contradiction of herself.
- **0** — Wrong or unsafe nutrition advice, or fabricated facts/numbers.

### 2. Task success (15)
The Scenario's stated goal is actually achieved by the end of the conversation: the plan is
confirmed and correct, the question is answered, the artifact (log, list, memory) exists.

- **100** — Goal fully achieved with a correct artifact.
- **75** — Achieved with a minor defect in the artifact.
- **50** — Partially achieved, or achieved only after the athlete rescued it.
- **25** — Goal not achieved but Vana failed gracefully (asked, deferred, handed off).
- **0** — Goal not achieved and Vana claimed otherwise, or left a broken artifact.

### 3. Concision & restraint (10)
She doesn't talk too much and doesn't show too many buttons. Replies are short; parts (chips,
pickers, buttons) appear only when they serve the athlete.

- **100** — Every reply earnable in one glance; every part earns its place.
- **75** — One reply overlong or one part too many.
- **50** — Regularly over-talks or walls of text; parts crowd the reply.
- **25** — Mostly walls of text or button clutter throughout.
- **0** — Every reply bloated; UI parts actively get in the athlete's way.

### 4. Interactivity (10)
Pressing a button makes something happen: chips answer the choice question, pickers tick meals,
confirm confirms, hand-offs open the right screen. Scored by actually pressing them.

- **100** — Every interactive part pressed did its intended thing.
- **75** — One part was slow or needed a second press.
- **50** — A part visibly no-oped or answered out of order.
- **25** — Multiple dead parts.
- **0** — The conversation's key interaction is dead.

### 5. Tool use & data ops (10)
She calls the right Tools, and the CRUD lands: plans drafted/confirmed, meals logged, memories
saved, feedback filed. Includes step economy — no needless tool loops.

- **100** — Right tools, right order, data verifiably written, no waste.
- **75** — Correct outcome with one wasted or redundant call.
- **50** — Achieved the outcome client-side chatter instead of a tool, or one call wrote wrong data.
- **25** — Missed the tool entirely (talked about doing it, never did).
- **0** — Called tools that damaged data, or looped to the step ceiling.

Note: this dimension is partly aspirational — shopping-list and activities CRUD tools do not all
exist yet. Low marks here are expected findings and feed Improvements.

### 6. Memory & personalization (10)
She knows the athlete she is talking to: uses the Voodoo Doll (facts, memories, episodes, meal
feedback), never asks for what she already knows, and carries prior conversations forward.

- **100** — Referenced what she knows at exactly the right moments; zero re-asking.
- **75** — Used her knowledge well but re-asked one thing she knew.
- **50** — Personalization thin; treated a known athlete like a stranger.
- **25** — Repeatedly re-asked known facts.
- **0** — Ignored or contradicted what she demonstrably knows.

### 7. Reliability (10)
No obvious bugs or errors: clean streaming, no error parts, no hangs, no broken UI, no
`insufficient_credits`/`rate_limited` surprises mid-conversation.

- **100** — Nothing visibly wrong.
- **75** — One cosmetic glitch (a flash, a mis-render that self-corrected).
- **50** — An error surfaced to the athlete but the conversation survived.
- **25** — A hang or a turn that never completed.
- **0** — The conversation broke and could not continue.

### 8. Opener (5)
When the Scenario exercises an opener, it feels relevant and personable: one thing only this
athlete told her, said the way a dietitian who remembers them would — never read out, never a
greeting.

- **100** — Specific, warm, clearly about this person's actual week.
- **75** — Relevant but slightly generic.
- **50** — Technically fine but could have been sent to anyone.
- **25** — A greeting or a read-out of data.
- **0** — Wrong (references something that isn't true of this athlete), or templated.

### 9. Instruction-following (5)
The product rules on record: one question at a time; never asks about batch cooking or coverage
scope (she asks once, ever — mp-608); openers never templated (mp-007/008); chips and hand-offs
used as designed.

- **100** — No rule touched.
- **75** — One soft brush (e.g., two questions in one reply, once).
- **50** — A rule broken once in a way the athlete would notice.
- **25** — Rules broken habitually.
- **0** — A rule broken in a way that breaks the conversation.

### 10. Recovery & boundaries (5)
When the athlete corrects her ("actually I'm allergic to cilantro"), she recovers: fixes the
plan, saves the memory, doesn't apologize twice. Out-of-scope or medical-adjacent asks get a safe
refusal that still helps.

- **100** — Corrected cleanly and remembered the correction.
- **75** — Corrected but didn't save the memory, or over-apologized.
- **50** — Acknowledged the correction without acting on it.
- **25** — Argued or re-suggested the corrected thing.
- **0** — Gave unsafe advice on a medical-adjacent ask.

## Scoring an Eval round

- One Run per Scenario per round (see `/eval/README.md` for the round protocol).
- Each Run also gets a written verdict: top defects observed and the Improvements it suggests.
- Round passes: average Mark ≥ 90 **and** no Run below 80. The project iterates (Mark →
  Improvement → re-run) until a round passes.
