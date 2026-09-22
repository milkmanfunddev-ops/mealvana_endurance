# Design SSOT — Component: Overflow Menu

**Status: PROPOSED v1 (Lee, 2026-09-22) — authored app-side, awaiting Xuan.** Written from paywall
ticket 15 (decisions mp-493 §4 and §6, mp-494, mp-497 §4, approved as mp-499). No reference
rendering yet.

**Component contract** — everything secondary on a screen, behind one ⋯ button in its top corner.
It owns the button, the menu's placement, its material and how it opens and closes. It never owns
which entries exist (the screen decides, per state) or what an entry does.

**Tokens / material:** [`../tokens.md`](../tokens.md) §Materials — the button is `glass` chrome (a
40 px circle). The menu is a summoned surface: the `glass-sheet` recipe (its own backdrop chain,
the `blackberry` 30 % veil, the cream 4 → 1 % fill, the rim) with every corner at 20 px, over the
standard sheet scrim (`blackberry` 60 %). Words in `cream`; a destructive entry in `dragonfruit`
(the Q-D2 delete treatment).

## Contracts

- **OM-1 — one button.** A 40 px `glass` circle with the ⋯ glyph in the page's ink, read as a
  button with the screen's label ("More options").
- **OM-2 — the menu.** A tap opens the menu 8 px under the button with its trailing edge on the
  button's, kept 16 px inside the screen. It lists exactly the screen's entries in the screen's
  order, one per row, each row at least 48 px high, hairlines (`cream` 12 %) between rows. The
  scrim darkens the page in both themes, so the menu reads the same in light and dark.
- **OM-3 — choose, then run.** Choosing an entry closes the menu first, then runs the entry, so a
  confirmation it opens sits on the page. A tap on the scrim, or back, closes the menu and runs
  nothing.
- **OM-4 — destructive.** An entry marked destructive wears `dragonfruit`.
- **OM-5 — motion.** The menu fades in over 150 ms (ease-out). With Reduce Motion it is there on
  the next frame.

## Implementation

`lib/shared/widgets/kyle_design/buttons/overflow_menu_button.dart` — `OverflowMenuButton`,
`OverflowMenuEntry`. Tests: `test/shared/widgets/kyle_design/overflow_menu_button_test.dart`.

## Open questions for Xuan

- **Q-OM1** — a pull-down under the button (v1, as Bevel does) or an action sheet from the bottom
  edge? The pull-down keeps the menu next to the button that opened it.
- **Q-OM2** — should the rows carry leading glyphs (restore arrow, person, bin)? v1 is words only.
