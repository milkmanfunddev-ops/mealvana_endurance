# 09: Vana sheet spec

**Status:** ready-for-human
**Blocked by:** A confirmation from Lee — Q-VS1 and Q-VS2 below
**Next:** Confirm the two answers the export gave, then mirror. Ticket 10 cannot start until this is confirmed.

**What to build:** A component spec for the Vana sheet exists in the design SSOT so the widget can be built once under its spec name. Drafted in the QA repo from the existing glass surface and tab-bar tokens: a bottom-corner launcher, a sheet that rises over the current screen leaving it visible, a full-screen affordance, and the states (closed, open, streaming, error). Synced into this repo's design SSOT mirror by the design-sync process. No Flutter code in this ticket.

- [x] Spec written in the QA repo under the design components, versioned, citing the tokens it composes
- [ ] Synced verbatim into this repo's SSOT mirror; nothing edited app-side
- [x] Launcher placement, exclusions, and full-screen affordance are stated in the spec
- [ ] Design-sync reports clean

**Notes (2026-09-09).** `spec/design/components/vana-sheet.md` in the QA repo, committed there as
`22449ff`. Status PROPOSED with four questions for Xuan: the sheet's rest height, the launcher's
mark, whether the launcher collapses with the tab bar on scroll, and whether the FAB clearance rule
extends to the Plan tab's swipe rows.

It fills a slot that was already reserved. `tab-bar.md` Q2 ruled a named, empty utility slot at the
bottom-right corner and named "the deferred AI companion" as the known candidate, inheriting the old
FAB's clearance rule; the sheet occupies it additively, so `tab-bar.md` needs no re-ratification.
The scrim comes from `calendar-sheet.md`, whose ruling made it inheritable by every future summoned
glass surface.

**Not synced, and the sync should not be run blind.** The design specs in the QA repo are eight days
behind this repo's `docs/ssot/` mirror: the mirror holds fifteen component specs, the QA repo six.
Missing from the QA repo are brick-leg-builder, calendar-sheet, date-header, during-card,
formula-pin-surface, macro-pill-row, meal-image-mosaic, selectable-chip-grid and tab-bar — including
the two this spec cites. A verbatim mirror sync in that state would delete nine ratified specs from
this repo. Reconcile the two first; then mirror.

`/design-sync` is also not the mirror: it publishes the design-system package to the claude.ai
design project. That is an outward-facing publish and is Lee's to run.

**Revised 2026-09-10 against `docs/New Homepage with updated navbar calendar and chat.html`**
(QA repo commit `9ffd92e`). The export answers two of the four questions and adds five contracts the
first draft did not have.

Answered by the export, needing only confirmation:
- **Q-VS1 rest height** — three heights, `auto` / 75% / 100%, the grabber dragging between them.
- **Q-VS2 the launcher's mark** — a speech-bubble outline drawn as a path, not a Font Awesome glyph.
  That makes it the first branded glyph on the shell, which is worth confirming deliberately rather
  than by omission.

Still open: **Q-VS3** (does the launcher collapse with the tab bar on scroll — the export only shows
the bar retracting while Vana *speaks*, which is the deferred proactive behaviour) and **Q-VS4** (does
the FAB clearance rule extend to the Plan tab's swipe rows).

Added from the export: the sheet condenses back into the launcher rather than sliding away; the status
chip; the message treatments; the quick replies and how they retire; the composer's send state.
