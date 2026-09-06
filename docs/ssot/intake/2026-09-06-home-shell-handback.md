# APP-SIDE HANDBACK — home-shell@v1 rulings applied (2026-09-06)

Companion to the four RESOLVED intake files of 2026-09-06 (tab-bar, date-header,
calendar-sheet, glass-material). Execute verbatim. Resolve `$APP_ROOT` / `$QA_ROOT` via
`mealvana_endurance/workspace.env` (`find_workspace`) — never hardcode. The qa pin for the
mirror is the commit this file lands in:
`git -C $QA_ROOT log -1 --format=%H -- intake/2026-09-06-home-shell-handback.md`.

**Sequencing:** items 1–2 run now; items 3–7 are implementation work against the
`home-shell@v1` tag — wait for `ship-bundle` to cut it (the specs are ratified on
`qa/home-shell`; the tag is the freeze). Implementation lands on a NEW screen (dev-visible),
not on the shipped dashboard.

- [ ] 1. Re-sync `$APP_ROOT/docs/ssot` as a **verbatim mirror** of the qa pin above; update
      `SSOT_SOURCE.txt` to that commit. New files in the mirror: `spec/design/components/
      tab-bar.md`, `date-header.md`, `calendar-sheet.md`; changed: `spec/design/tokens.md`
      (§Materials), `spec/design/surfaces/macro-dashboard.md` (home-shell recomposition,
      staged), `bundles/daily-macros-dashboard.yaml` (note only).
- [ ] 2. Re-run the existing conformance suites (deno vectors runner; Dart intraday / parity /
      design suites) and report the count — **expect no change** (this batch adds contracts, it
      moves no vector or manifest of the tagged bundles; a diff here is a defect in the sync,
      not the specs).
- [ ] 3. **Glass material constants** in `lib/theme/kyle_design/` — ONE registry, no second
      token class: `glass` (blur 4 · saturate 1.8 · brightness 1.12 · cream 7→2% fill · rim ·
      lift) and `glass-sheet` (top radius 24 · cream 4→1% · **scrim blackberry 60%
      rgba(56,22,51,.6)**), per `docs/ssot/spec/design/tokens.md` §Materials. Compact header
      row uses `glass` (not a fade).
- [ ] 4. **TabBar v2** in `lib/shared/widgets/kyle_design/navigation/`: expanded/collapsed +
      scroll morph (thresholds into the gesture manifest); left anchor + named empty
      bottom-right utility slot (FAB clearance rule); house glyph on Fuel Timeline; **the full
      tab-switch effect is contractual** — highlight travel + finger-tracking drag + refraction
      in transit (Impeller `ImageFilter.shader`), spec'd by observable properties; mid-transit
      goldens. Goldens: expanded 3-item + 5-item, collapsed, morph, mid-transit frames.
- [ ] 5. **DateHeader** in `kyle_design/navigation/`: REST ("Today, …" / weekday variant) +
      COMPACT (glass row); both summon paths open the same CalendarSheet; ‹ › chevrons for
      adjacent day; **no screen-level horizontal swipe over the timeline** (negative test
      required). Goldens: REST today, REST weekday, COMPACT.
- [ ] 6. **CalendarSheet** in `kyle_design/navigation/`: three-slot cells; dot ← workout-card
      v3 states (PLANNED hollow orange 2px / DONE filled electrolyte / SKIPPED + rest **no
      dot** / multi-workout best-state); tint ← ≥1 athlete food log (binary v1) — **build the
      per-day fueling-log rollup derivation** (file the ops sibling if it needs backend);
      today = cream-FILLED, selected = ring; dismissal set: grabber pull w/ snap-back + scrim
      tap + day tap. Goldens: dense month (channels diverging), sparse month, enlarged
      cell-spec card. Gesture manifest: CS-1…CS-6 incl. snap-back negative.
- [ ] 7. Home-surface recomposition on the NEW screen per `macro-dashboard.md` §home-shell
      recomposition (ViewTabs + WeekStrip leave; BY MONTH superseded). Then `/design-sync`.
- [ ] 8. Golden-regeneration commits cite the spec change (house rule); flip the matching rows
      in `docs/feature-test-plans/` when a described test becomes a pinned test.
