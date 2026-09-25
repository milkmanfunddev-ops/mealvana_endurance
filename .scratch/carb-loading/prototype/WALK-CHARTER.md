# Walk charter — fuel-timeline-standalone.html

One charter per landed version; overwrite with each landing. QA verifies the
charter against the artifact and hunts beyond it.

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
