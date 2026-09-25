# Walk charter — fuel-timeline-standalone.html

One charter per landed version; overwrite with each landing. QA verifies the
charter against the artifact and hunts beyond it.

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
