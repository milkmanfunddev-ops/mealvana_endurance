# Design SSOT — Surface: Carb-Loading Entryway (event page · chooser · plan summary)

**Status: RATIFIED (Xuan, 2026-09-25, ruling-desk block — every desk call ruled; see §Desk
rulings below). Extraction basis: prototype v19 walk (bundle sha `b6da90768caf5413`); behavior
authority = `spec/fueling/carb-loading-entryway.md` RATIFIED v1. Where a §Desk ruling reverses
the walked artifact (container, F3, F4, F1), THE RULING is the contract and the prototype owes
a conforming revision.**

## Desk rulings (Xuan, 2026-09-25 — pasted block applied verbatim)
- **Container: full PAGE; the sheet variant is RETIRED.** (F2 becomes moot — no sheet, no
  stacking trap.)
- **F3:** the re-pick confirm relabels edits per the TARGET protocol, **with the date** —
  "Day 1 (Fri, Sep 26) — you set 620 g". Supersedes the walked source-label behavior; the walk
  charter's description becomes the ruled one.
- **F4:** when EVERY edit falls outside the new window, the dialog collapses to a
  **single-button notice** (outcome stated; no vacuous Keep/Reset pair).
- **CE-7 — YES:** the breakdown page carries a navigation-only **"Manage plan ›" footer** to
  the plan summary; read-only holds (navigation, not mutation). Closes the entryway behavior
  spec's CE-7 OPEN row.
- **F1 fix:** the Set Up row's subtitle reflects the feasible protocol set for the day (or
  drops the enumeration).
- **Copy register v1 = the v19 strings verbatim (§copy register below), AMENDED by the rulings
  above where they touch a string:** the F3 dialog line gains the target-relabel + date form,
  F4 adds the single-notice strings (to be drafted app-side against this ruling and folded on
  extraction of the conforming prototype), and F1 replaces the static subtitle.
- **F5:** feasibility re-checked at selection time (midnight-rollover guard) — rides handback
  G9.
Walk method: charter-verified then hunted beyond (16 states captured; shots accompany the desk
artifact). NOT walked: the Reset-to-protocol outcome (dialog itself walked; outcome
harness-verified by app-38 only) · the 2-days-out chooser state · CE-3's today-CTA snackbar
(not represented in the prototype, per charter).

## Verified against the ruled behavior (all pass)
CE-1 two-state row · CE-2 summary content (stored targets incl. edits, one-decimal g/kg — 620 →
"9.1 g/kg", the Q-CL10 stored-rate display) · CE-3 pop-to-event-details, no stack surgery ·
CE-4 all dialog paths (quiet no-edit re-pick, quiet same-protocol re-tap, Keep-migrate 620 →
2-Day Sep 26, drop note on 1-Day, exactly two buttons) · CE-5 delete confirm with the ruled
Path-A copy, dragonfruit, returns row to the correct no-plan state for the day · CE-8 gate at
1-day-out (dimmed cards with reasons, taps no-op) and race day (inert window-passed row;
Change protocol disabled with its own copy). Chooser numbers reproduce the ratified math
verbatim (544/544/680 · 612/748 · 748).

## Truths screenshots can't hold
- **E-1 · Sheet (B) modality:** the bottom-sheet summary is modal — backdrop tap dismisses; while
  it is open, everything beneath (chooser included) is untappable. See F2.
- **E-2 · Confirm-dialog day labels are SOURCE-plan labels:** "Day 2 — you set 620 g" under the
  3-Day; the same Sep 26 edit reads "Day 1" once the current plan is the 2-Day. Consistent in
  the artifact; contradicts the walk charter's claim of target-protocol relabeling. See F3.
- **E-3 · State propagation:** selection/edit/delete flow back to the entry row instantly (row
  shows stored targets, e.g. "544 / 620 / 680 g"); the event layer is a full cover — the
  dashboard beneath stays mounted.
- **E-4 · Every gate is rendered, not hidden:** infeasible protocol cards, race-day Change
  protocol, and the window-passed row all remain visible with reason copy; nothing disappears.

## Copy register (candidates for the P-3 register; v19 verbatim)
`Set Up Carb Loading` + subtitle `3-, 2-, and 1-day protocols` (see F1) · `Carb loading window
has passed` + `Race day is today — fuel the race from the dashboard.` · `Needs N days before
race day` · `Nothing fits before race day` · `Choose a protocol` + footer `Targets are per day,
from your body weight. You can edit any day's target after setup.` · `CURRENT PLAN` · `EDITED` ·
`Keep your edited targets?` · `You edited: Day N — you set N g.` · `On the <protocol>, <Day,
date> falls outside the window — that target goes away.` · `Keep my targets` / `Reset to
protocol` · `Remove carb loading plan?` + `Targets and schedule are deleted. Food you've already
logged stays in your log.` · `Remove` / `Cancel` · header `Race in N days` / `Race tomorrow` /
`Race day`.

## Findings register (the desk rules each)
| # | Class | Finding |
|---|---|---|
| F1 | design-fix | Entry-row subtitle "3-, 2-, and 1-day protocols" is static — at 1 day out it advertises protocols the chooser will refuse. Candidate: subtitle reflects feasible set, or drops the enumeration. |
| F2 | A/B cost (feeds the fork) | In Sheet (B), "Change protocol" opens the chooser UNDER the still-open sheet; the athlete's next tap dismisses the sheet before the chooser is usable. Page (A) transitions cleanly. Either fix B's stacking or count it against B at the fork. |
| F3 | charter erratum / micro-ruling | Dialog labels edited days by the SOURCE plan (artifact) vs target-protocol relabel (charter claim). Pick one; artifact behavior is coherent and arguably better (the athlete knows the day by its current name). |
| F4 | micro-ruling | When every edit falls outside the new window, Keep and Reset converge — a vacuous two-choice dialog. Option: collapse to a single-button notice in that case. |
| F5 | app-side note | Feasibility is evaluated when the chooser opens; a midnight rollover mid-chooser could stale the gate. One re-check at selection time closes it (implementation note, rides G9). |

## Conformance (staged with the bundle)
L1 goldens: the 6 canonical states (no-plan row, gated chooser, summary A, confirm w/ drop note,
delete confirm, window-passed row). L2: E-1 modality, E-3 propagation (row reflects stored
targets after each mutation), copy strings verbatim once the register is ratified, F1's
resolution, CE-8 no-op taps.

## v20 re-walk (QA, 2026-09-25 — bundle sha `2ed6df9b7be7fd0a`)
Desk deltas verified against the ruled contract:
- **G12 ✓** — A/B pills and sheet path gone; summary opens as a full page.
- **G13 ✓ (content)** — F3 exact: "You edited: Day 1 (Fri, Sep 26) — you set 620 g." (target
  relabel + date); F4 exact: single-button notice, draft strings "Edited target won't carry
  over" / "…your 620 g target goes away. Day targets reset to protocol." / "Switch to 1-Day".
- **G14 ✓** — "Manage plan ›" under the PROTOCOL strip navigates breakdown → plan summary
  (event surface); read-only holds; D7 electrolyte strip untouched as ruled.
- **G15 ✓** — subtitle variants verified at 5/2/1 days out.

**V20-R1 — RESOLVED in v21 (bundle sha `2afe613779653c3e`, app 8d547ca0; QA re-walk 2026-09-25): chooser z 25→27, stack-above — back chevron returns to the summary, a selection collapses both to the event row (walked physically end-to-end incl. the F3 dialog at z-28 and Keep-migration to 620/748). app-38 harness gained a static paint-order assertion (summary < chooser < dialogs) — the whole defect class now caught pre-landing. Original finding:** the chooser layer mounts at `z-index: 25`, the
plan-summary page at `z-index: 26` — from the summary, "Change protocol" opens the chooser
UNDERNEATH the page and the athlete sees nothing happen (three physical taps, ref-tap, and
programmatic click all visually dead; verified by peeling the summary layer, which revealed the
open chooser and working dialogs behind it). The Set-Up path is unaffected (no summary mounted).
Same defect class as retired F2, reborn in the page container; violates the ruled "transitions
cleanly". G13's dialogs were verified BEHIND this red via QA instrumentation. Fix owed in v21.

**F6 — RULED (Xuan, 2026-09-25, interview: option A — backdrop-tap aborts both dialogs; folded as behavior spec CE-9; app gate G16). Original finding:** neither re-pick dialog offers an abort — outside-tap is
inert and every button mutates the plan (the F4 notice's only button commits the destructive
switch). An accidental protocol tap cannot be backed out of. Candidate fixes (a Cancel action,
or backdrop-dismiss = abort) touch the ruled "exactly two choices, no third option" anatomy, so
this is filed, not fixed.

**Carried to the LOAD-face extraction (out of entryway scope):** the LOAD face still renders an
expand chevron + expanded state (ruled E1-suppressed / collapsed-only); sparkle + "Today's
Fuel" box still render (ruled excluded; prototype not yet stripped — open with Xuan).
