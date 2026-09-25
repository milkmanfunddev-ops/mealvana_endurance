# Walk charter — fuel-timeline-standalone.html

One charter per landed version; overwrite with each landing. QA verifies the
charter against the artifact and hunts beyond it.

## Pipeline contract (amended 2026-09-24, per QA's incomplete-landing find)

The landed HTML is now a TRUE single-file bundle — "sha matches" and "artifact
runs" are the same claim again. Per version the bundle inlines: the dc-runtime
(`support.js`, verbatim), the eight dc-import component dependencies (as
base64 `data:` URLs in a `window.__resources` remap, each with its duplicate
`@font-face` rules stripped — the main document declares every family), and
the eight fonts as `data:` URIs (sourced from this repo's `assets/fonts/`;
`Apercu-Regular` maps to `Apercu Regular.otf`, Compadre to the Demo cut —
same families the design project ships). Only React/ReactDOM/Babel still come
from unpkg (SRI-pinned; network needed). Two shas per landing: the DESIGN
SOURCE sha (the project's `Fuel Timeline -standalone source-.html`, byte-equal
with the design project) and the BUNDLE sha (this file). The bundler script
sits beside this charter (`bundle-standalone.py`) so the transform is
reproducible and auditable.

## v22 (2026-09-25) — Q-D9/Q-D10/F6 ruling conformance
- source sha256/16 `254af8cf3349ef3e` (design project, verified byte-equal)
- bundle sha256/16 `f1c232d958a98bfe` (880,302 bytes, committed bundler)

Three deltas over v21 (qa c7ef9ff rulings):
1. **Q-D10 strip** — the sparkle button and the "Today's Fuel" insight box no
   longer render on loading days (any loading day, including the clock-free
   future day). Regular day keeps both, unchanged. The six-slot scaffold is
   untouched — it is loading-day-driven, sparkle-independent (Q-CL7), so
   stripping the button changes nothing about the slots.
2. **Q-D9 register conformance** — the expanded LOAD face stands as ruled
   (option B, no structural change). Its to-go string now conforms to the
   registered form: "N g to go" with to-go = max(target − eaten, 0) — at
   547/544 it reads "0 g to go". NOTE for re-extraction: v21 rendered the
   UNREGISTERED string "Target met" in that state; it is removed.
3. **CE-9 backdrop-abort** — an outside/backdrop tap on the re-pick dialog
   (both variants: Keep/Reset and the single-button notice) dismisses it:
   plan untouched, chooser stays open beneath. No Cancel button added. The
   dialog card swallows its own taps (stopPropagation). The DELETE confirm is
   unchanged — it is not a re-pick dialog and already carries Cancel.

## v21 (2026-09-25) — V20-R1 fix
- source sha256/16 `0caf27d1bfc27473` (design project, verified byte-equal)
- bundle sha256/16 `2afe613779653c3e` (880,020 bytes, committed bundler)

One delta over v20: **V20-R1** — the chooser overlay moves z-25 → z-27, so
"Change protocol" from the plan summary (z-26) now opens ABOVE it (stacks,
does not replace: closing the chooser returns to the summary; selection still
closes both per the ruled flow). Confirm dialogs stay z-28, above the
chooser. Per qa's method note, the harness now carries a static paint-order
assertion (summary < chooser < confirm/delete within the event layer) next to
the state-flow checks, so this class of red is caught at build time, not at
walk time. F6 (no-abort modality) deliberately untouched — awaits Xuan's
ruling. Chevron/E1 suppression and sparkle/"Today's Fuel" also untouched —
pending Xuan's word, flagged by qa for the dashboard extraction.

## v20 (2026-09-25) — desk-conforming revision
- source sha256/16 `58c4d6471347eae2` (design project, verified byte-equal)
- bundle sha256/16 `2ed6df9b7be7fd0a` (the landed file, 880,020 bytes; built
  with the committed bundle-standalone.py)

Deltas over v19 — the four desk reversals (G12–G15), everything else stands:
1. **G12** — plan summary is a full PAGE only; the sheet variant and the
   "Summary: Page | Sheet" A/B pills are REMOVED (F2 moot).
2. **G13/F3+F4** — the re-pick confirm: edits relabel per the TARGET protocol
   WITH the date — picking 2-Day from the edited 3-Day reads "You edited:
   Day 1 (Fri, Sep 26) — you set 620 g." When EVERY edit falls outside the
   new window (picking 1-Day) the dialog is a single-button notice: title
   "Edited target won't carry over", body "On the 1-Day protocol, Fri,
   Sep 26 falls outside the window — your 620 g target goes away. Day targets
   reset to protocol.", button "Switch to 1-Day" (proceeds). These notice
   strings are DRAFTS per the desk ruling — they fold into the register at
   re-extraction.
3. **G14/CE-7** — the breakdown page (dashboard surface) gains a
   navigation-only "Manage plan ›" footer under the PROTOCOL strip: it closes
   the breakdown and opens the plan summary on the event surface (plan-state
   control forced to "Plan" if it was "No plan" — on a real carb day a plan
   exists by definition). Read-only holds; nothing on the breakdown mutates.
4. **G15/F1** — the Set Up row's subtitle enumerates only the feasible set:
   "3-, 2-, and 1-day protocols" / "2- and 1-day protocols" / "1-day
   protocol" (empty on race day — the row is the window-passed state anyway).
   F5 (selection-time feasibility re-check) is app-side; the prototype
   re-derives feasibility on every render, so its onSelect gate is already
   evaluation-at-tap.

## v19 bundle (2026-09-24)
- source sha256/16 `b6da90768caf5413` (design project, verified byte-equal)
- bundle sha256/16 `d666740ddcfee1ec` (the landed file, 882,718 bytes)
- Smoke-tested served over localhost in Chrome: hydrates fully (no raw
  mustaches), Day Header dep loads from the resource map, fonts render,
  Event page surface + entry row respond.

## v19 (2026-09-24) — sha256/16 `b6da90768caf5413`

Delta over v18: the ENTRYWAY extension for desk ratification (CE-1..CE-8
rendering candidates). Everything in the v18 section below still holds.

### New prototype-only controls (outside the phone frame)
- Surface pills: **Dashboard | Event page** (always visible). Event page is a
  full-cover layer inside the phone; the dashboard beneath is untouched.
- When Event page: **5 days out | 2 days out | 1 day out | Race day** (CE-8
  input), **No plan | Plan | Plan, edited targets**, and the A/B fork
  **Summary: Page | Summary: Sheet**.

### Event surface states (all against race = Sun Sep 28, weight 68.0 kg)
- Header: "Ironman 70.3 Augusta · Sunday, Sep 28 · Race in N days /
  Race tomorrow / Race day".
- Entry row (CE-1): no-plan+feasible = "Set Up Carb Loading" (orange border,
  opens chooser); no-plan+race-day = inert "Carb loading window has passed"
  (CE-8); plan-exists = summary row "Carb Loading · <protocol>" + window +
  per-day targets, opens the plan summary.
- Chooser (CE-8 gated): three cards — 3-Day Classic 8·8·10 g/kg
  (Sep 25–27, 544/544/680 g), 2-Day Quick 9·11 (Sep 26–27, 612/748), 1-Day 11
  (Sep 27, 748). Infeasible cards render dimmed WITH the reason "Needs N days
  before race day" — never hidden; tapping them is a no-op. Current plan's
  card carries a "Current plan" tag. Point-value copy throughout (CL-12).
- Plan summary (A/B fork): A = full page, B = bottom sheet w/ drag bar +
  backdrop; identical content — per-day rows (Day N · date · grams ·
  g/kg, EDITED chip on edited days), "Change protocol ›" (disabled on race
  day with "Nothing fits before race day"), "Remove carb loading plan" in
  dragonfruit.
- Re-pick confirm (CE-4, only when edited targets exist and a DIFFERENT
  protocol is chosen): "Keep your edited targets?" lists the edits ("Day 2 —
  you set 620 g"; day number re-labels per the target protocol's window);
  when the new window drops the edited date it says so ("…falls outside the
  window — that target goes away"). Buttons: Keep my targets / Reset to
  protocol. Keep migrates by date (620 carried onto 2-Day's Sep 26; dropped
  on 1-Day); same protocol re-tap and no-edit re-picks regenerate quietly,
  no dialog.
- Delete confirm: "Remove carb loading plan?" — "Targets and schedule are
  deleted. Food you've already logged stays in your log." Remove
  (dragonfruit) / Cancel. Removing returns the entry row to Set Up state.

Not represented: CE-7 "Manage plan ›" breakdown footer (desk item, not
built); the post-selection today-CTA snackbar (CE-2's conditional toast —
prototype has no snackbar layer).

## v18 (2026-09-24) — sha256/16 `ebcb2f16a4b064bf`

Delta over v17: Q-CL11 conformance only — ramp anchors are the running sum of
ROUNDED slot targets (Option R); owed(t) is fractional mid-window (no
whole-gram rounding in the math; display strings round); the 22:00 anchor is
forced to the day target. No visual/interaction change; all demo readouts
identical to v17.

### Prototype-only controls (outside the phone frame)
- `enableTracking` / `carbLoadingDay` editor toggles (data-props). Default:
  regular day — the regular-day dashboard must be byte-identical in behavior
  to the pre-carb prototype.
- 7 day pills: 7 AM · 3 PM · 7 PM · 9 PM · 10 PM · ◂ Day 1 · Day 3 ▸. Each
  reseeds the day's log; Day 1 = past/outcome, Day 3 = future/planned (680 g).

### States the artifact holds (carb day)
- **Energy card LOAD face** (All lens, replaces net-balance face): collapsed =
  label row + 26px loader (faded track, uneven orange fill, cream pace tick) +
  pace words; expanded (chevron) = eaten-of-target, 5px detail bar, Full
  Breakdown button. Copy register v1 verbatim: "N g behind pace" / "N g ahead
  of pace" / "On pace" / "<target> g / planned" / "Loaded" + "N of N g".
  Expected readouts: 7am 45 behind · 3pm 31 behind · 7pm 69 behind · 9pm 26
  behind (band 25.85 — relative band max(5% owed, 10 g)) · 10pm Loaded
  547/544 · Day 1 "521 g / of 544 g" · Day 3 "680 g / planned".
- **Six slot timeline groups** (Breakfast 6:00 / Morning Snack 9:00 / Lunch
  12:00 / Afternoon Snack 3:00 / Dinner 6:00 / Evening Snack 9:00; ride node
  4:15 between AS and Dinner; no Recovery group on loading days). Card
  states: empty = header-only (whole surface opens interior); filled =
  summary; chevron peek = read-only receipt + "Edit in <slot> ›".
- **Slot interior page** (tap a slot card): search + barcode featured, curated
  Recommended (white glyphs on teal discs), formulas (emoji disc, neutral),
  My Foods, logged receipt with ×N stepper (−/+/remove), custom-food footer.
- **Breakdown page** (Full Breakdown on LOAD face): read-only overlay —
  header "Carb Load · Day N of 3", hero pace + loader recap, electrolyte
  macro strip (carbs figure in electrolyte = the OPEN D7 desk item, do not
  treat as ratified), BY MEAL six rows (current window ringed, today only),
  PROTOCOL chips 544/544/680. Chips NAVIGATE protocol days (ring follows,
  current-day chip returns to the today-view you left, same-chip no-op);
  back chevron restores the day the page was opened from.
- **Regular day**: breakdown unreachable even with stale state; all carb
  surfaces absent; sparkle + "Today's Fuel" box still render on carb days —
  ruled OUT of release-1, prototype not yet stripped (open with Xuan).
