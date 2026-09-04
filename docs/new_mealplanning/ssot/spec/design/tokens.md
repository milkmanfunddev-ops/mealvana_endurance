# Design SSOT — Tokens (meal-planning meaning contracts)

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.**
**Authority for values:** `docs/ssot/spec/design/tokens.md` (RATIFIED v1, Xuan 2026-08-14; Q-D8/Q-D9 2026-08-26)
— the one place raw values live. This file adds **meaning** rows the meal-planning surfaces rely on and that
the ratified registry does not yet carry. Values below are quoted from the app's `slot_palette.dart` /
`macro_palette.dart` only so the row is checkable; they are not a second registry.

| Token / role | Value (app constant) | Meaning contract (proposed) |
|---|---|---|
| slot **breakfast** | `orange` #F78B14 | the breakfast slot chip and nothing else on these surfaces — **conflict:** `orange` is ratified as *daily energy & intake accent*; a slot label is a category, not an intake accent → **Q-TK1** |
| slot **lunch** | `electrolyte-dark` #3FD4C0 | the lunch slot chip — **conflict** with `electrolyte` = per-workout fuel / burn side → **Q-TK1** |
| slot **dinner** | `kMacroColorProtein` #8E6FD8 (purple, not in the ratified registry) | the dinner slot chip → **Q-TK1** (an unregistered hue) |
| slot **snack** | `dragonfruit` #DC2597 | the snack slot chip — **conflict** with `dragonfruit` = destructive / out-of-range caution → **Q-TK1** |
| slot **untagged** | #9E9E9E | a slot with no type |
| **selection accent** | `electrolyte` | "chosen" on a chip / picker tick / selected card — Vana's single-pick chips already use it; extended to the multi-pick grid (`selectable-chip-grid.md`); signifies *chosen*, not fuel, not activity |
| **destructive on these surfaces** | `dragonfruit` | Remove / Delete / Forget buttons and the swipe-left reveal — consistent with the ratified contract |
| **Vana** | `VanaAvatar` (electrolyte ring; pulsing = thinking) | the assistant's presence; no mascot (update plan §4 guardrail) |
| macro pills | neutral text-on-surface | signify nothing (`macro-pill-row.md` token usage) |

**Q-TK1 is the load-bearing question:** the four slot colours reuse three meaning-bound tokens for a
categorical purpose. Either the registry gains a "category labels may borrow hues without meaning" rule, or the
slot palette is re-ratified as its own four-token set. Until ruled, the slot chips are a recorded deviation
(D-19) rather than a contract.
