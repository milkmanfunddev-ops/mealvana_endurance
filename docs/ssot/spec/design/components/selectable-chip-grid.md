# Design SSOT — Component: Selectable Chip Grid

**Status: PROPOSED v1 (Lee, 2026-09-03) — awaiting Xuan.** Drafted for the Vana chatbot update
(`docs/new_mealplanning/vana-chatbot-update-plan.md` §4.2, Phase 7 item 1). Not yet on a
spec-review page; no reference rendering — the MealBuddy frames show the *interaction* (a
multi-pick grid with a trailing add), the Kyle prototype's `.k-choice` chip shows the *look*.
**Component contract** — a wrapping grid of **toggle chips** the athlete can tick on and off in
any combination, with an optional trailing **`+` chip** that opens an inline text entry for an
item the grid did not offer. A **multi-select input**, not a status: it never ranks, groups or
colours items by meaning. **What the items are, and what happens when the athlete commits the
selection**, is the surface's (the pantry card's "Use these"; any future multi-pick surface).
**Tokens:** [`../tokens.md`](../tokens.md) — the electrolyte selection accent already carried by
Vana's single-pick chip, neutral otherwise (see *Token usage*).
**Data authority:** the host. The grid holds no state of its own — the items and the selected
set are passed in, every change is reported back, and the host decides what to keep.

## State model

```
items     : [label]                 # host-owned, ordered; labels are unique
selected  : {label}                 # host-owned; a subset of items
enabled   ∈ { true, false }         # false once the host has committed the selection
allowCustom ∈ { true, false }       # whether the trailing + chip shows
entry     ∈ { closed, open }        # the + chip's inline text field (component-local)
```

Per chip: `unselected` · `selected` · `disabled` (the grid's `enabled = false` disables every
chip at once — there is no per-chip disable).

## Behaviour

- **SCG-1 · Toggle, never radio.** Tapping a chip flips it. Any number may be selected, including
  none. The component reports the whole new set on every change (`onChanged(Set)`), so the host
  never has to diff.
- **SCG-2 · The `+` chip is last, and is not an item.** With `allowCustom`, a trailing chip
  labelled `+` follows the last item. Tapping it swaps the chip for an inline single-line text
  entry (placeholder from the host's copy, e.g. "Something else…") with a submit affordance.
  Submitting non-empty text reports it (`onAddCustom(text)`) and closes the entry; the host
  appends the item and — by convention — selects it. Submitting empty text, or dismissing, just
  closes the entry. The grid does not itself add the item: the host owns `items`.
- **SCG-3 · Disabled is inert and reads as spent.** `enabled = false` greys every chip (the same
  spent state as the single-pick chip strip), hides the `+`, closes any open entry, and ignores
  taps. Selected chips keep their tick so the committed selection stays legible.
- **SCG-4 · No selection cap.** The component enforces no maximum. A surface that needs one
  applies it in the host (and says so in its copy).
- **SCG-5 · Labels are the identity.** Two chips never share a label; the host de-duplicates a
  custom entry that matches an existing item (case-insensitive) rather than adding a twin.

## Layout

- **SCG-L1 · Wrap, never scroll.** Chips wrap to as many rows as the content needs inside the
  host's width; the grid never scrolls horizontally. At the narrowest supported width
  (iPhone SE, 320 pt) a chip is never wider than the host — a long label ellipsises on one line.
- **SCG-L2 · Chip form is the Vana choice chip.** Pill radius, the same padding and type as the
  single-pick chip (`.k-choice`), so a multi-pick grid and a single-pick strip read as one family.
  A selected chip carries a leading check glyph so the fill is not the only signal.
- **SCG-L3 · The entry takes the `+` chip's place.** The inline field opens in the flow of the
  wrap (full row width), not as a sheet or dialog.

## Token usage

- **Unselected:** electrolyte outline at 60 % over a faint electrolyte wash, electrolyte label —
  exactly the single-pick chip's resting state.
- **Selected:** solid electrolyte fill, blackberry label and check — the single-pick chip's
  chosen state. This is the **selection accent**, already in use across Vana's chips; it signifies
  "chosen", not activity, not fuel, not daily intake (tokens.md meaning contracts, Q-D3/Q-D8).
- **Disabled:** neutral (`cream` / `blackberry` per theme) at low alpha — no accent.
- **No `orange`, no `dragonfruit`, no `yolk`.** Nothing here is judged. Both themes.

## Traceability

The grid renders the labels it is given and reports selections; it invents no ordering, no
grouping and no colour meaning. The pantry surface feeds it `pantry.items[].name` with
`selected` as the initial set; a custom entry becomes a plain item with no provenance mark.

## Conformance (design vectors)

- **Widget (L2):** SCG-1 — tapping toggles and `onChanged` carries the full set; SCG-2 — the `+`
  opens an entry, submitting non-empty text calls `onAddCustom` and closes it, empty text does
  not; SCG-3 — disabled ignores taps and hides `+`; SCG-L1 — a long label inside a 320 pt host
  builds without overflow; both themes build without exception.
  `test/shared/widgets/kyle_design/selectable_chip_grid_test.dart`.
- **Golden (L1):** none yet — the pantry card golden lands with the Phase 7 goldens once the
  fixtures settle.
- **A golden may only be regenerated after this spec changes** — never to make a red test pass.

## Open for ratification

- **Q-SCG1** — whether a selected chip should carry the check glyph (drafted: yes, SCG-L2) or
  rely on fill alone as the single-pick chip does.
- **Q-SCG2** — whether the custom entry should also offer a "clear all" affordance on the grid.
  Drafted: no — the pantry's item count is small enough to untick by hand.
