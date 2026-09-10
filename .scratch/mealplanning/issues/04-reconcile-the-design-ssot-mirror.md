# 04: Reconcile the design SSOT mirror

**Status:** ready-for-human
**Blocked by:** None, but it needs someone who knows which repo is the truth.
**Next:** Establish which side is canonical, then reconcile. Ticket 05 cannot mirror anything until this is done.

**What to build:** One design SSOT again, instead of two that disagree.

**The problem.** `docs/ssot/spec/design/components/` in this repo holds **fifteen** component specs.
`../mealvana_endurance_qa/spec/design/components/` holds **six**. The QA repo's last design commit is
2026-09-01; this repo's mirror carries content from 2026-09-09.

Present here and missing there: `brick-leg-builder`, `calendar-sheet`, `date-header`, `during-card`,
`formula-pin-surface`, `macro-pill-row`, `meal-image-mosaic`, `selectable-chip-grid`, `tab-bar`.

`CLAUDE.md` says the QA repo is the source and `docs/ssot/` is a verbatim mirror never edited
app-side. If that is taken literally today, a sync **deletes nine ratified specs** from this repo —
including `tab-bar.md` and `calendar-sheet.md`, which the new Vana sheet spec cites as its slot
authority and its scrim precedent.

**This is a question about which repo is telling the truth**, and it is not an agent's to answer.
Either those nine were authored app-side against the rule, or the QA repo is simply behind and needs
what this repo has.

- [ ] Establish which side is canonical for those nine specs
- [ ] Reconcile so both sides agree, without losing a ratified spec
- [ ] Confirm or correct the rule in `CLAUDE.md`, so the next sync is safe to run blind
- [ ] Note it: `/design-sync` is a different thing — it publishes the design-system package to the
      claude.ai design project, and is an outward-facing publish rather than this mirror

**Full history:** `../archive/issues-2026-09-10/09-vana-sheet-spec.md`
