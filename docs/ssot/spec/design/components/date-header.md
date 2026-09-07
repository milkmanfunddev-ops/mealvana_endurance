# Design SSOT — Component: Date Header

**Status: RATIFIED v1 (Xuan, 2026-09-06 — ruling-desk block of 2026-09-06). Ships as
`home-shell@v1`.**
**Component contract** — owns the header's two states, the title/summon behaviour and the
adjacent-day affordance. It replaces the persistent `ViewTabs` + `WeekStrip` block on the home
surface — that recomposition is the surface's business
([`../surfaces/macro-dashboard.md`](../surfaces/macro-dashboard.md), home-shell recomposition,
2026-09-06).
**Tokens / material:** [`../tokens.md`](../tokens.md) §Materials — the compact row carries **NO
material of its own**; only its circular buttons take the `glass` recipe (RULED Xuan 2026-09-06
**#2**, on-device review of the first Rad build — reverses the same-day row-takes-glass ruling.
The export's blur-14 blackberry fade stays superseded, and no band replaces it: a full-width
backdrop region reads as a slab, not glass).
**Companion artifact:** `New Homepage with updated navbar calendar and chat.html` (walked live
2026-09-06) — illustrates; this file governs.
**Ruling source:** [`../../../intake/2026-09-06-date-header-component.md`](../../../intake/2026-09-06-date-header-component.md) (RESOLVED).

## States — Q1 (RULED as filed, + the weekday variant pinned)

| State | Contract |
|---|---|
| `REST` | One Sansita page-title line, tappable, with the settings gear right. Title copy: **"Today, {Month D} ˅"** when the shown date is the current day; **"{Weekday}, {Month D} ˅"** otherwise (pinned 2026-09-06 — observed in the export as "Wednesday, August 12 ˅"; the weekday replaces "Today", nothing else changes) |
| `COMPACT` | Sticky bandless row on scroll: floating `glass` calendar button left · short centred date ("Aug 31, 2026") · floating `glass` gear right. Content scrolls under the buttons and the date directly — the row paints NO material (see Tokens note above) |

**Summon parity (RULED):** the REST title tap and the COMPACT calendar button summon **the same
calendar sheet** ([`calendar-sheet.md`](calendar-sheet.md)). Two entry points, one component,
one state.

## Adjacent-day navigation — Q2 (RULED: chevrons adopted)

Slim `‹ ›` chevrons flank the REST-state title ("‹ Today, August 31 ˅ ›"), giving
yesterday/tomorrow in one tap — restoring what the WeekStrip's removal took away. Not drawn in
the export; this text governs.

**Hard constraint (RULED, verbatim):** **no screen-level horizontal swipe over the timeline.**
Horizontal gestures there belong to the workout card's ratified G1–G4 set
([`workout-card.md`](workout-card.md) v3); a day-pager under those cards would make the G3
zero-translation guarantee untestable.

## Surface composition — Q3 (RULED as filed)

`ViewTabs` + `WeekStrip` leave the home surface (both stay in the widget library; other surfaces
may still compose them, and `WeekStrip` may be reused inside the calendar sheet's month-grid
context). The `BY MONTH` tab's month view is superseded **on this surface** by the calendar
sheet. The authoritative composition table lives in the surface spec's home-shell recomposition
section.

## Conformance (design vectors)

- **Goldens (L1):** REST (today copy), REST (non-today weekday copy), COMPACT — at
  token-resolved colors, the compact row BANDLESS with floating `glass` buttons (ruling #2).
- **Gesture manifest (L2):** title tap → sheet summoned; compact calendar button → the same
  sheet; chevron taps → adjacent-day navigation (date changes, no sheet); scroll transition
  REST ⇄ COMPACT (thresholds pinned in the manifest); **negative test:** a horizontal drag over
  the timeline region produces zero screen-level day change (the workout card's G-set still owns
  the gesture).
- Goldens regenerate only after this spec changes; commits cite the change.

## Open ratification questions
- *(none — Q1–Q3 RULED 2026-09-06)*
