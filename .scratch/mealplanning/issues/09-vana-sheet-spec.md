# 09: Vana sheet spec

**What to build:** A component spec for the Vana sheet exists in the design SSOT so the widget can be built once under its spec name. Drafted in the QA repo from the existing glass surface and tab-bar tokens: a bottom-corner launcher, a sheet that rises over the current screen leaving it visible, a full-screen affordance, and the states (closed, open, streaming, error). Synced into this repo's design SSOT mirror by the design-sync process. No Flutter code in this ticket.

**Blocked by:** None (can start immediately)

**Status:** spec written; NOT synced (2026-09-09)

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

