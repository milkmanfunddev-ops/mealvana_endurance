# SSOT — Athlete Context (the CONTEXT block)

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.**
**Engine:** `buildAthleteContext(userId, latestUserText?, anchorDate?)` + `contextBlock(ctx)` — prototype
`server/vana/context.ts`, edge `_shared/vana/context.ts`. **The edge twin is ahead** (RECENT · SEASON ·
BUDGET · LAST WEEK · coverage lines, 2026-09-03 Phases 2–3); the prototype lacks them — D-12.
**Consumers:** the planning system prompt (the whole block), day notes, the home payload. General-kind
conversations get NONE of it (only name + date) — `../domain/conversation.md` C-3.

`AthleteContext` is server-internal: the Dart client never sees it (`02-contract.md`).

## Inputs → lines

Built once per turn, ≤ ~1.5k tokens as an object, ~250 tokens as text. Every line names its source table.

| Line | Source | Rule |
|---|---|---|
| `ATHLETE` | `users` | first name · `dietary_preference` or "any" · allergies or "none" |
| `WEEK` | `activities` (anchor … +7) | `weekStartFor(anchor)` · [`week-character.md`](week-character.md) · up to 8 workouts as `MM-DD title Nm` |
| `RACE` | `events` (anchor … +21, first) | name · date · `daysOut = date − anchor` in whole days; "RACE none" |
| `HOLIDAYS` | `holidays.ts` (static US rules, anchor … +13) | name · date · today/tomorrow/Nd; federal dates take the Sat→Fri / Sun→Mon observed shift, cultural dates do not |
| `TARGETS` | `daily_macro_targets` | today's `kcal ≥C ≥P F · formulas session_kcal · meal budget planningKcal (lunch+dinner ≈ lunchDinnerKcal)` · the week as `MM-DD:C/P/kcal` · `race-week ≥NC` — arithmetic in [`daily-targets.md`](daily-targets.md) |
| `WEATHER` | Open-Meteo (geocoded race location, 6 h cache) | today · race day; "n/a" without a race location — the profile has no location (Q-AC2) |
| `LOGGED TODAY` | `meal_logs` (anchor day) | count · Σ carbs |
| `PLAN` | [`../domain/plan.md`](../domain/plan.md) | status · servings left · `batch on/off/never chosen` · `coverage dinners only / dinners and lunches / every meal / never chosen` (edge) |
| `RECENT` (edge) | `activities` (anchor −2 … anchor, done) | the first session with ≥ 75 min OR intensity matching /high\|race\|hard\|threshold/, ordered by duration desc; skipped when status matches /cancel\|skip\|missed/ |
| `SEASON` (edge) | `season.ts` | in-season produce for the anchor month (US temperate, not regional) · `BUDGET about $N/week` when `weekly_budget_usd` is set |
| `LAST WEEK` (edge) | `plan_debriefs` (latest) | `completed of planned planned meals happened (skipped: reason)`; "no debrief yet" |
| `MEMORIES` | `user_memories` | recall by embedding of the latest user text (6) ∪ most recent (10), capped at 10, first 8 rendered; edge appends `(source · date)` |

**In a planning conversation the PLAN line describes the conversation's own draft**, not the Plan tab's active
plan (`chat.ts` overrides `ctx.plan` after `getConversationPlan`). `batchKnown` is true only when a `setting`
memory exists — a plan row's `batch_cooking` defaults to true at insert and cannot tell "chosen" from "default".

## Rules

- **AC-1 · Deterministic and model-free.** No model call builds the block; the only network calls are the
  macros back-fill (T-2), geocoding/weather (best-effort, null on failure) and the memory embedding.
- **AC-2 · Anchor day is the athlete's local day.** `anchor_date` from the client, else `localDate(timezone)`,
  else UTC today. Around midnight and on weekend boundaries the two differ; the client's wins.
- **AC-3 · The block is the only athlete data the planning model sees up front.** Everything else is a tool.
- **AC-4 · Numbers in the block are the only numbers the model may quote** (guardrails H1).

## Worked example (TARGETS)

`tdee 3200 · session_kcal 560 · carb_g 344 · prot_g 117 · fat_g 90` →
`planningKcal = 3200 − 560 = 2640`, `lunchDinnerKcal = round(2640 × 0.55) = 1452`,
line: `TARGETS (daily-macros service) today 3200kcal ≥344C ≥117P 90F · formulas 560kcal · meal budget 2640kcal (lunch+dinner ≈1452)`.
Race on Sat with Wed/Thu/Fri carb targets 380/420/460 → `race-week ≥460C`.

## Deviations

- **D-12** — the prototype context lacks RECENT / SEASON / BUDGET / LAST WEEK / coverage; the persona it mirrors
  references them. Edge is authoritative; prototype to catch up.

## Conformance

Pending extraction (**Q-AC1**): the budget arithmetic, `daysOut`, the RECENT selection and `contextBlock`
formatting live inside the DB-bound builder. Extract `deriveTargets(rows)` / `pickRecentSession(rows)` /
`contextBlock` into a pure module (the `plan-math.ts` precedent) so `vectors/planning/athlete-context.json` can
exist. Until then the edge `context.test.ts` and the contract fixtures (`tests/fixtures/opener.json`) are the
only guard.
