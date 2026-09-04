# Design SSOT — Component: Shopping List

**Status:** RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.
**Source:** the `shopping_list` part and the Shopping tab; prototype `ShoppingList` in `widgets.tsx`.
**Code:** Dart `ShoppingListScreen`.
**Scope:** numbers authority `../../planning/shopping-list.md` — the component invents no quantity.

**What this file owns:** the shopping list's grouping, checked/have distinction, the inline chat summary card,
and share (SL-1..SL-5); quantities themselves are owned by `../../planning/shopping-list.md`.

## State model

```
items    : ShoppingItem[]  {aisle, name, qty, checked, have, fromMealIds}
grouped  : by aisle, in AISLE_ORDER (server order preserved)
```

## Contracts

| # | Contract |
|---|---|
| SL-1 | **Grouped by aisle**, aisle heading = the server's string; items in server order. |
| SL-2 | **`checked` and `have` are different things.** Checked = bought / in the cart (strikethrough); have = already in the house (the "have it" chip replaces the quantity). Toggling either writes `toggle_shopping {name, field, value}` and both survive a rebuild (P-8). |
| SL-3 | **The inline part in chat is a summary card** (item count = items not `have`; the aisles; "skipped X, Y" for `have`) linking to the tab — the full list is the tab. |
| SL-4 | **Share is the OS share sheet with plain text** (Dart `PlanShareService`; web: copy) — no email/PDF/calendar (⚖️ Q-3). |
| SL-5 | **Empty: "No list yet — confirm a batch and Vana builds it."** |

## Conformance

Goldens: two-aisle list with one checked and one have; the inline summary card. Widget: SL-2 writes both fields.
