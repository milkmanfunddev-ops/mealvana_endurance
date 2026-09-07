# Design SSOT — Component: Staples Card

**Status:** RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.
**Source:** the `staples` part (`diagnoseStaples`).
**Code:** not verified in this pass — no implementing widget file is named here.
**Scope:** changed 2026-09-02 from auto-add to suggest-only; composed into the Plan tab's no-plan state.

**What this file owns:** the staples card's row ordering, tick-to-draft behavior, log-only inertness, and the
compact Plan-tab variant (SC-1..SC-5) — used by the Plan tab's no-plan state and planning chat.

## State model

```
meals  : (MealRef & {timesLogged, ticked})[≤6]
ticked : DERIVED = in the draft (chat) / from the part (Plan tab, no plan)
inert  : id starts with "log:"          # a log-only staple that matched nothing in the library
```

## Contracts

| # | Contract |
|---|---|
| SC-1 | **Rows are "what you already eat", ordered most-logged first** (top 5 from 30 days of logs, then saved meals), each with a count ("7×") or "saved" and the library id tag when matched. |
| SC-2 | **Ticked = in the draft. Tapping adds or removes** (`pick_meals` / `unpick_meal`, servings 4) — nothing is ever added for the athlete. |
| SC-3 | **Log-only rows are inert:** a `log:<name>` ref has no library or saved id to add, so its tick is not tappable. |
| SC-4 | **Empty: "Nothing logged yet. Log a few meals or save one and Vana plans around them."** |
| SC-5 | **Compact variant on the Plan tab** ("Your staples · tap to add") only when there is no plan. |

## Conformance

Goldens: 3 rows (one matched, one saved, one log-only), empty. Widget: SC-2 write, SC-3 negative.
