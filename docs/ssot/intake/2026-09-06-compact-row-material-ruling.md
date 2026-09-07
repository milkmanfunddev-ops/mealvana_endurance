# RULING #2 — the compact header row carries NO material; buttons only (RESOLVED)

**Ruled: Xuan, 2026-09-06 (evening — on-device review of the first Rad build).**
**Status: RESOLVED — applied same day to `spec/design/components/date-header.md`,
`spec/design/tokens.md` §Materials, and the app (feature/home-shell-v1).**

## The ruling

The compact date-header row paints **no material of its own**. Only its two circular buttons
(calendar, gear) take the `glass` recipe — as floating chrome, full recipe including lift. The
centred short date renders directly over the page. This **reverses** the same-day ruling #1
("the row takes the glass recipe like its buttons"); the export's blur-14 blackberry fade
remains superseded, and **no band replaces it**.

## Why (the on-device evidence, in order)

1. First Rad build: the row + buttons compounded glass-on-glass (~3.2× saturation) — fixed
   app-side (nested chrome stops re-filtering), but the row still read as a slab.
2. Making the whole home scroll under the chrome (energy card + filter row joined the scroll)
   gave the glass real backdrop texture — better, but a visible band remained at the top.
3. Xuan: "There is still a visible band at the top, which is incorrect. I only want the
   minimized calendar button and gear button to have the glass effect, not the entire band."
   Root observation: a full-width region-bound backdrop filter over mostly-flat ground is
   indistinguishable from a painted rectangle — the glass vocabulary works for capsules and
   circles floating over content, not for edge-to-edge bands.

## Conformance impact

- `date_header_compact` golden re-blessed from the bandless rendering (spec change cited).
- No gesture-manifest change: dh1–dh6 ids, assertions and pins are unaffected (dh3's COMPACT
  assertions name the buttons and the centred date, which survive; "content scrolls under"
  now means under the floating buttons directly).
