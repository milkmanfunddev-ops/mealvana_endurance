type: ruling-request
bundle: agent@v1

## Why this matters
This reverses a decision recorded the same day (2026-08-31: "opener = frame + three dinners") without Xuan
having seen either version. It is the newest, least-settled call in this restructure and the one most likely to
need her direct input rather than a Lee interim reading, because it touches the tension between spec §2.1/§2.3
(proactive, one question at a time) and §2.2 (confident proposal first) head-on.

## The question
The planning opener now writes 2–3 context sentences (proving awareness of the athlete's week) and then asks
ONE question via `askChoice` ("What sounds good for dinners this week?" with 3–4 trade-off chips), proposing no
meals until the athlete answers. This reverses the 2026-08-31 decision that the opener should present a frame
plus three concrete dinner suggestions immediately (matching spec §2.2's "confident proposal first,
Xuan: 'if you trust us, we decide for you'"). The reversal cites Xuan's own SCEN-U source, which opens with a
question ("Let's plan the week — starting with dinner. What sounds good?"). Does the question-first shape stand,
or should the opener go back to proposing dinners immediately (with `draftWeek`, which does exist now, doing the
zero-question full-week proposal for athletes who want it)?

## Options
- **Question-first opener (current build).** Matches SCEN-U's own literal opening line and spec §2.3's "one
  question at a time" more directly than the three-dinner opener did; `draftWeek` (a "Draft my whole week" chip,
  now available since Phase 2) is the mechanism that still delivers the confident zero-question proposal §2.2
  describes, just not as the *default* opener path.
- **Revert to frame + three dinners.** Matches §2.2's "confident proposal first" as the *default* experience,
  not an opt-in chip; risks re-asking what the picker's first answer already covers if the athlete doesn't want
  any of the three.
- **Hybrid: propose dinners, but make the fork visible immediately.** E.g. present three dinners AND the
  trade-off chips in the same turn, athlete can tap a dinner or tap a chip to redirect. Higher prompt complexity;
  risks overwhelming the first turn (spec §2.3 warns against "overwhelming lists").

## Recommendation
Keep question-first for now — it is directly sourced from Xuan's own scenario text, not an invented shape, and
`draftWeek` already covers the zero-question path for athletes who want it. But this is exactly the shape of
call this register exists to flag cheaply: unlike Q-4 (macros default), this one trades off two of Xuan's own
spec passages against each other, so it should not be treated as settled until she has actually seen it.

## Gates
`persona.ts` `OPENERS.meal_planning` and rule 0 ("THE INTERVIEW"); `spec/agent/voice.md` §Opener;
`spec/planning/opener-selection.md`'s `plan` variant; the `presenting` check in `scripts/vana-eval/run.ts`.

## Suggested spec home
`spec/agent/voice.md` §Opener; `spec/planning/opener-selection.md`; `DEVIATIONS.md` D-020 (fold the ruling in
as a dated quote once Xuan has seen it).
