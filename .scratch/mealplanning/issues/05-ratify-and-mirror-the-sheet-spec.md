# 05: Ratify and mirror the Vana sheet spec

**Status:** ready-for-human
**Blocked by:** 04 (the mirror must be safe to run), and two confirmations from Lee
**Next:** Confirm the two answers below, then mirror. Ticket 06 builds a design-bearing widget and cannot start until this spec carries a ratified name.

**What to build:** The Vana sheet's component spec, ratified and mirrored, so the widget can be built
once under its spec name with a header comment citing the spec path and version — which is this
repo's rule for any design-bearing widget.

**Where it is.** Written and committed in the QA repo at
`spec/design/components/vana-sheet.md` (`22449ff`), then revised against the design export
(`9ffd92e`). Status PROPOSED.

It fills a slot that was already reserved: `tab-bar.md` Q2 ruled a named, empty utility slot at the
bottom-right corner and named "the deferred AI companion" as the known candidate, inheriting the old
FAB's clearance rule. The sheet occupies it additively, so `tab-bar.md` needs no re-ratification.

## The two confirmations

The design export answered both; they need a deliberate yes rather than passing by.

- **Q-VS1 — rest height.** Three heights: `auto` for a sheet that is one message and a dismiss, 75%
  at rest with a card and replies, 100% expanded, with the grabber dragging between them.
- **Q-VS2 — the launcher's mark.** A speech-bubble outline drawn as a path, not a Font Awesome glyph.
  **This makes it the first branded glyph on the shell**, which is a real decision.

Still open, and neither blocks a passive build: **Q-VS3** (does the launcher collapse with the tab bar
on scroll — the export only shows the bar retracting while Vana *speaks*, which is ticket 09's
deferred behaviour) and **Q-VS4** (does the FAB clearance rule extend to the Plan tab's swipe rows).

## Wording to carry into the spec when it is ratified (from 08, 2026-09-11)

Ticket 08 built the heights and settled three readings the spec text does not yet say:

- **VS-4:** the stream never resizes the sheet, but the athlete's first send grows an `auto` sheet
  to 75 % once. `auto` is as tall as what it holds, so holding it through the turn would resize it
  with every word.
- **Three heights:** "a dismiss" is any single reply; a receipt part counts as a card.
- **Anatomy / VS-9:** "transform origin at the launcher's own corner" means the launcher's centre,
  which is where the export's `transform-origin` sits.
- **VS-7:** from 100 %, a short drag down collapses to the rest height and a drag 90 px past the
  rest line dismisses. 100 % stops under the status bar.

- [ ] Q-VS1 and Q-VS2 confirmed, and the spec moved from PROPOSED to RATIFIED with a version
- [ ] Mirrored into this repo's SSOT, nothing edited app-side
- [ ] Design-sync reports clean

**Full history:** `../archive/issues-2026-09-10/09-vana-sheet-spec.md`
