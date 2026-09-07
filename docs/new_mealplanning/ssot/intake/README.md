# Meal-planning intake — ruling requests

The drop folder for items whose resolution is **Xuan's call**, adapted from the QA repo's `intake/`
(`mealvana_endurance_qa/intake/README.md`) for this app-side SSOT. There is no separate ops repo on this side —
product-lifecycle items (bugs, feature requests) go straight to the Notion boards per `.claude/notion/boards.md`;
**this folder is only for contract-lifecycle items**: a ruling, a spec addition, a scope call that changes what
`ssot/spec/**` says.

Consumer: Xuan (or Lee relaying her ruling) processes these when cutting decisions — by reading the file,
ruling, and folding the ruling into the named spec home as a dated, quoted addition (the pattern the QA repo
calls the `intraday-display.md` §4b amendment: a ruling from Xuan is quoted, dated, and folded in place, never
paraphrased into prose that could drift). Processed files get a one-line stamp prepended:
`> **RESOLVED <date> → <where it landed>**` (or `> **DECLINED <date> — <why>**`). Nobody strips that stamp.

## File format

One atomic item per file, named `YYYY-MM-DD-<short-slug>.md`, type `ruling-request` (this folder currently
carries no `spec-erratum` items — those go straight into `DEVIATIONS.md` instead, since this SSOT has nothing
ratified yet for an erratum to be *against*):

```
type: ruling-request
bundle: <family>@v1 (or blank if cross-cutting)

## Why this matters
one line — what stays a ⚖️ interim call, or stays unbuilt, until this is resolved

## The question
...

## Options
- Option A — trade-offs
- Option B — trade-offs

## Recommendation
optional

## Gates
what app-side work this blocks or would need to change

## Suggested spec home
where the ruling should be folded once made
```

## Guardrails

- Files here never edit `spec/**` or `DEVIATIONS.md` directly, and never self-ratify — a ruling request states
  the question and options; it does not decide.
- Cross-reference `OPEN-QUESTIONS.md` and `DEVIATIONS.md` by their Q-/D- ids instead of restating them.
- Leave unknowns blank; don't fabricate an answer to fill a field.

## Current items

| File | Question |
|---|---|
| `2026-09-03-q1-scenario-scope.md` | Do the AI Scenarios govern mechanics-only, or does any of their race-day domain content apply? |
| `2026-09-03-q2-wizard-door.md` | Does the structured 6-step wizard ship, ever, or does chat absorb its virtues permanently? |
| `2026-09-03-q3-artifact-depth.md` | Does artifact depth stay in-app (share sheet + notifications), or does calendar/email/PDF integration get built? |
| `2026-09-03-q4-macros-default.md` | Confirm macros-on-by-default (low-ambiguity — Xuan already conceded this 2026-05-20). |
| `2026-09-03-q5-proactive-cadence.md` | Does the proactive loop stay opener-only, or does push notification get turned on? |
| `2026-09-03-q6-tone.md` | Does the moment-based voice register replace the flat two-sentence persona, as interpreted? |
| `2026-09-03-q7-intro-card-reversal.md` | Was removing the first-run intro card (in favor of the question-first opener) the right call, or does some one-time explainer still belong? |
| `2026-09-03-opener-question-first-reversal.md` | Does the question-first opener (reversing the 08-31 "frame + three dinners" decision) stand, and does it satisfy §2.2's "confident proposal first" or only §2.1/§2.3? |
