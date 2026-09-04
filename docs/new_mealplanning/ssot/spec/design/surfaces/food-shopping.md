# Design SSOT — Surface: Food → Shopping

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.** Prototype `routes/food.shopping.tsx`; Dart
`ShoppingListScreen`. **Composition:** shopping-list v1.

| # | Contract |
|---|---|
| FS-1 | **Shows the active plan's list** (confirmed first, else the newest draft's — the draft list is rebuilt on every edit, so a draft has a list too). |
| FS-2 | **Aisle groups, checked strikethrough, "have it" chip** (shopping-list SL-1/2). |
| FS-3 | **Share** → OS share sheet / copy (SL-4). "Send to Reminders" / "Order pickup" are the walkthrough's future labels — not built (VP-S2 class). |
| FS-4 | **Empty: "No list yet — confirm a batch and Vana builds it."** |

Conformance: golden (two aisles, one checked, one have); Patrol plan flow (5 rows + have-it + Share).
