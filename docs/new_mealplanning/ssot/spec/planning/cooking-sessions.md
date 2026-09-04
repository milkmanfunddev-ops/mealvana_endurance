# SSOT — Cooking Sessions

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.**
**Engine:** `defaultSession(batchCooking, meal, existing)` — edge `plan-math.ts` ≡ prototype `plan.ts`;
`setBatchCooking` (the re-derive) in both `plan.ts`; `sessionDates(weekStart)` — edge `opener.ts` only (D-12).
**Consumers:** `PlanMeal.session`; the Review sheet grouping; the check-in opener's cook date; the client's
reminder scheduling (`PlanReminderService`, 18:00 the evening before cook day).

## Definitions

- **Session** — `cook-sun` (the Sunday batch cook) · `topup-wed` (the midweek top-up) · `fresh-fri` (made fresh)
  · `null` (no session — batch cooking off, "make the night of").
- **Batch cooking** — a `setting` memory `batch_cooking` (default true when never chosen; asked once by the
  persona). A plan row copies it at insert (`meal_plans.batch_cooking`).

## Constants

```
SUNDAY_CAP   = 2       # batch meals that cook on Sunday before the next one tops up Wednesday
COOK_SUN     = weekStart + 0
TOPUP_WED    = weekStart + 3
FRESH_FRI    = weekStart + 5
```

## The algorithm

```
defaultSession(batchCooking, meal, existing):
  if !batchCooking       → null
  if !meal.batch         → "fresh-fri"                     # the catalog says this meal does not batch
  sundays = count(existing.session == "cook-sun")
  return sundays >= 2 ? "topup-wed" : "cook-sun"           # no Wednesday cap

setBatchCooking(plan, on):                                  # the re-derive on toggle
  plan.batch_cooking = on
  sunday = 0
  for m in plan.meals (stored order):
    batch = library meal's batch flag (saved meals count as batch=true)
    m.session = !on ? null : !batch ? "fresh-fri" : (sunday >= 2 ? "topup-wed" : "cook-sun"); if batch and on: sunday++
```

`addMeal` assigns `defaultSession` only when the caller passes no session; a re-added (undo) meal keeps its
previous session. `swapMeal` keeps the session. `setSession` is a free override (`set_session` action).

## Invariants

1. `batchCooking == false ⇒ every session == null` after the re-derive, and `defaultSession` returns null.
2. `meal.batch == false ⇒ fresh-fri` regardless of Sunday's count.
3. The third and every later batch meal is `topup-wed` (`many-sundays-still-wednesday`).
4. Only `cook-sun` rows count toward the cap (`sunday-count-ignores-other-sessions`).
5. Session dates are fixed offsets from the Sunday week start; the athlete's real cook day is **not** modelled
   (Q-CS1).

## Worked example — the re-derive

Plan order `[batch, batch, batch, non-batch]`, toggled ON → `[cook-sun, cook-sun, topup-wed, fresh-fri]`;
toggled OFF → `[null, null, null, null]`. Not vectored: the re-derive reads each meal's `batch` flag from the
library (DB) — pending extraction (Q-CS2).

## Deviations

- **D-12** — `sessionDates` and the opener variants exist only on the edge twin.
- The re-derive treats a **saved** meal as `batch = true` unconditionally (`?? true`) — Q-CS3.

## Conformance

Vectors: `vectors/planning/cooking-sessions.json` (9: 8 `defaultSession` on both TS twins, 1 `sessionDates`
edge-only). Green 2026-09-03.
