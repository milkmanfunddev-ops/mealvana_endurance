# SSOT — Agent Guardrails (thin LLM, thick algorithm)

**Status:** RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.
**Source:** consensus architecture since 2026-05-08 (`../intent/vana-mealplanning-chatbot.md` §7.1): "If we
swapped Claude for any other model tomorrow, this product wouldn't break."
**Code:** enforcement is spread by design — prompt (`persona.ts`), tool inventory (`tools.ts`), SQL filters
(`search_meals`), math (`plan-math.ts` / `grocery.ts`) — see "Where these are enforced" below.
**Scope:** the hard (MUST) and soft (SHOULD) invariants the model must never violate, and the mechanism +
test that enforces each.

**What this file owns:** the boundary between what the model may decide (phrasing, ambiguity) and what must be
computed, filtered or gated in code — the thin-LLM/thick-algorithm contract itself. It owns no tool inventory
([`tools.md`](tools.md)), no register/copy rules ([`voice.md`](voice.md)), and no wire shape
([`wire-protocol.md`](wire-protocol.md)).

## Hard invariants — MUST always hold (a violation is a bug, never a style issue)

- **H1 — Never invent.** Every meal, ingredient and number Vana mentions came from a tool result or the CONTEXT
  block. Meals are named as the library names them; the short attribution is cited once. *Enforced by:* the
  persona; `compactMeal` (the model only ever sees catalog rows); vana-eval `no_invented_meals`.
- **H2 — Tools enforce safety; the model cannot override it.** Allergies and diet are hard filters inside
  `search_meals` (MS-1/2); the model has no tool that bypasses them and no way to add a meal by name. *Contrast
  with the fueling pin policy (`generate-plan.md` H2 "labeled override"): there is no user pin in meal planning
  and therefore no override path.*
- **H3 — Selection is deterministic.** Which meals a picker holds, which fill a drafted week, which staples
  show, which dinner day guidance names — all engine (`../selection/`). The model chooses *which tool to call
  with which filters*, never *which meal*.
- **H4 — Numbers are computed, then narrated.** Coverage, sessions, the shopping list, per-day macros, day
  labels, targets — engine (`../planning/`). The model quotes; it never adds, scales or rounds.
- **H5 — Nothing enters the plan without an athlete tap or an explicit ask.** Tapping a picker option, "I like
  these", "Draft my whole week", or naming a meal are the doors; a suggestion, a staple, a day-guidance pick is
  never added by the model on its own (rule 2, SG-5).
- **H6 — Confirm is the word "confirm".** `confirmPlan` is called only on an explicit confirm; "that's my
  week", "done", "looks good" are not; the plan bar / Review sheet is the primary confirm path (P-3).
- **H7 — Targets are minimums; no body talk.** "At least 344g carbs"; never cutting, weight, deficit, body
  shape. Medical questions (supplements, conditions, medication) → the referral line; eating-disorder language →
  NEDA 1-800-931-2237 and stop. Fueling questions ("why not skip dinner", "shakes instead of meals") are
  EXPLAINING, not medical.
- **H8 — Never narrate tool use.** No "Let me…", "I'm pulling…"; text comes after tool results; the client shows
  a per-tool status line instead. General-kind pre-tool narration is dropped from the transcript (C-8).
- **H9 — The twins are mirrors.** Every rule here binds the prototype, the edge functions and the Dart client
  alike; a fix landing in one twin is a defect until ported (D-011 … D-017 are the open ports).
- **H10 — Race-day fueling is out of scope.** Vana never generates before/during/after race fuel; it may
  *present* the deterministic engine's numbers (day guidance "Race day" carries none) — `../intent/` §1.2.
  **⚖️ interim (Lee, 2026-09-03)** — the exclusion itself traces to Xuan's own verbatim scope call (the
  2026-06-17/25 decision quoted in `../intent/` §1.2); what remains open is only whether a race-week
  *conversation* may still exist around it (Q-1).

## Soft invariants — SHOULD hold (quality; a miss is filed, not failed)

- **S1** every proposed meal's why names a training fact from the CONTEXT ("carbs before Thursday's hill
  repeats"), never a platitude.
- **S2** one question per turn; a fork is 2–4 options each with a one-line trade-off (`voice.md`).
- **S3** the opener leads with the single most salient fact in the ratified salience order (`voice.md` §Opener).
- **S4** `rememberFact` only for explicit statements or repeated behaviour (MEM-1).
- **S5** prefer assemblies and in-season produce when a budget is set; prefer no-recipe options for "quick".

## Where these are enforced

| Invariant | Mechanism | Test |
|---|---|---|
| H1, H8, S1–S3 | prompt (`persona.ts`) | `scripts/vana-eval` checks `no_emoji`, `no_narration`, `why_lines`, `fork_with_details`, `milestone` |
| H2, H3, H4 | code: filters in SQL, selection in `tools.ts`, math in `plan-math.ts` / `grocery.ts` | vectors + contract fixtures |
| H5, H6 | tool design (no add-by-name; `confirmPlan` description) + prompt rules 2 and 7 | vana-eval `wrapup` (no confirm on "that's my week") |
| H7 | prompt hard rules | vana-eval `no_body_talk` (proposed — Q-AG1) |
| H9 | byte-identity for the three verbatim files; the three conformance arms for the rest | `conformance/README.md` |

## Open questions

| Q | Question | Blocks |
|---|---|---|
| Q-AG1 | vana-eval has no check for H7's body-talk ban; add one before the persona is ratified? | conformance only |
| Q-AG2 | H5 vs `updateBatch add`: the tool lets the model add a meal "the athlete names". Should naming be the only trigger, and is the description enough of a guard? | H5's tightness |
