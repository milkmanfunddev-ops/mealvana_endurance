# APP-SIDE HANDBACK — carb-loading release-1 ratification (interview 2026-09-24)

Addressee: Xuan's app-side coding session (app-38 relays; Xuan ships the code). Resolve
`$APP_ROOT` via `mealvana_endurance/workspace.env` / `find_workspace`.

**Context:** `spec/fueling/carb-loading.md` is RATIFIED v1 (this batch's commit). Vectors do NOT
exist yet — spec-to-vectors runs next, then ship-bundle tags `carb-loading@v1` with the
EXPECTED-RED vector set. **Reds marked "@v1-staged" below land on qa main at land-bundle; until
the tag exists they are named, not yet executable — do not count those items as carried until
the tag lands them.** Immediately-executable items are marked LIVE.

- [ ] **Mirror re-sync (LIVE):** `$APP_ROOT/docs/ssot` → verbatim mirror of this qa batch
      commit; update `SSOT_SOURCE.txt` pin. Red (LIVE): `conformance/run_dart.sh` mirror
      byte-identity check fails until synced.
- [ ] **G1 — D-021 mapper fix (LIVE):** `carb_loading_mapper.dart:60-74` — missing split fields
      must default at FRACTION scale (0.25/0.10/0.25/0.15/0.20/0.05) or reject the row; never
      16.67. Red (LIVE, invent here): add app unit test
      `test/features/carb_loading/carb_loading_mapper_test.dart::missing_split_fields_hydrate_as_fractions`
      — red against current code, green after the fix.
- [ ] **G2 — pace ramp engine** (CL-5..CL-11: 3-h grid 6/9/12/15/18/21 close 22:00; slot-weighted
      piecewise-linear owed(t); band = max(5% owed, 10 g); eaten = all-day logs; completion;
      loader fill/tick; device-local time). Red (@v1-staged):
      `qa/vectors/fueling/carb-loading.json` slices `ramp-checkpoints`, `pace-band`,
      `completion`, `day-variants` — worked examples W1–W10 are the oracle anchors.
- [ ] **G3 — 1-Day protocol:** chooser card + `_getCarbProtocolForDay` branch at **11.0 g·kg⁻¹**
      (`protocolDays == 1`). Red (@v1-staged): vector slice `protocol-1day` (67.99 kg → 748 g;
      slots 187/75/187/112/150/37).
- [ ] **G4 — point-value copy (CL-12/§2a):** replace the 2-Day "8–10 / 10–12" advert, the
      protocol card "7–9", the Edit Target "8-12g/kg" help with actual per-day rates; face
      strings verbatim per §2a. Red (@v1-staged): copy-register conformance rows + qa-smoke
      drawer ⇄ engine check.
- [ ] **G5 — LOAD face + breakdown page** per `energy-card.md` §LOAD-face amendment and the
      v17 prototype (extraction to `spec/design/` follows; implement against the extraction,
      not the prototype directly — reuse-the-library rule applies). Red (@v1-staged): L1 goldens
      (LOAD today/future/past), L2 rows named in the amendment.
- [ ] **G6 — edited-day-target behavior (Q-CL10):** stored `carbTargetGrams` drives slots,
      checkpoints, ramp, copy; rate copy shows stored g/kg. Red (@v1-staged): vector slice
      `edited-day-target`.
- [ ] **Directive (research, no red — feeds the OPEN desk ruling):** per Xuan verbatim —
      research the best Flutter libraries for glow materials "so it can match the Claude design
      or even exceed Claude design's aesthetic value". Output feeds the desk's amendment-(c)
      A/B; do not implement glow before that ruling.
- [ ] **Test plan:** `docs/feature-test-plans/carb-loading.md` does not exist yet — created via
      qa-test-plan at ship; rows flip ⬜→✅ per its rules then.

**Still open on the QA side (not gates):** amendment (c) glow + D7 electrolyte-vs-orange (desk,
A/B on the v17 face); `intake/2026-09-24-carb-loading-daily-macros-collision.md` (Formula 8 vs
protocol targets — venue and bundle are Xuan's call).

---

## Appendix — interview decision log (verbatim authority)
# Ruling interview — carb-loading release-1 (2026-09-24)

Batch: Q-CL1..10 (spec/fueling/carb-loading.md §8) + intake amendments (a), (b), (d).
Amendment (c) glow materials routed to the DESK (visual — needs the A/B on the v15 face).

Queue (dependency order):
1. Q-CL2 — adopt shipping rates as-is (gate for all protocol items)
2. Q-CL3 — 1-day protocol: add or record absent
3. Q-CL4 + Q-CL5 — rate copy (2-day ranges; old 7–9 / 8–12 contradiction)
4. Q-CL8 — eaten scope (gate for ramp vectors)
5. Q-CL1 — dead-band constant
6. Q-CL9 — slot clock times (confirm) + Q-CL7 sparkle-independence (riding confirm)
7. Q-CL10 — edited day target re-derivation + gPerKg display
8. Amendment (a) — macro-dashboard S-5 scope guard
9. Amendment (b) — energy-card v2 confirms + Q-CL6 Full Breakdown destination
10. Amendment (d) — copy register casing/format + placement

## Decisions
(appended verbatim as they land)
- **Q-CL2 — RULED (adopt):** shipping rates ratified as-is: 3-Day Classic 8/8/10, 2-Day Quick
  9/11 g·kg⁻¹; Mealvana design choices, cited with the low-edge literature note.
  ("Adopt as is")
- **Q-CL3 — RULED (add):** a 1-Day protocol IS added, per the ACSM/contemporary recommendation
  (10–12 g·kg⁻¹ per 24 h band; Bussau 2002 single-day evidence). Point rate = pending sub-gap
  Q-CL3a this turn. ("and also add the 1-day carb loading protocol according to the ACSM
  recommendation")
- **Q-CL3a — RULED: 1-Day protocol rate = 11.0 g·kg⁻¹** (band midpoint; restatement verified
  correct). ("11 is the middle of the 10-12 acsm standards")
- **Q-CL4 + Q-CL5 — RULED: point-value copy.** All protocol/help copy states the actual per-day
  rates (Classic 8/8/10, Quick 9/11, 1-Day 11); range language dropped; fixes the 8–10/10–12
  advert, the 7–9 card, and the 8–12 help text in one rule. ("Option one.")
- **Q-CL8 — RULED: eaten = ALL carbs logged on the loading day** (slot-tagged or not); CL-11
  confirmed as written; cards-vs-face divergence is by design. ("All-day logs")
- **Q-CL1 — RULED (principle): dead-band is RELATIVE — ±5% of owed(t)**, not a fixed gram count
  ("it should be, say, ±5% of that specific time. Target is not a slot target, but a specific
  time target, because every single time, the target is moving"). FLOOR sub-gap still open (my
  proposal max(5%, 10 g)).
- **PACE BASIS — re-opened and RE-RULED: Option A, the slot-weighted gradual ramp** (D8 stands;
  flat-uniform fill rejected again after the 8:00/16:10 comparison). ("let's pick option A")
- **CL-5 AMENDED: Breakfast slot time = 6:00 am** (was 7:30 design default); other slots
  unchanged (MS 10:00, L 12:30, AS 15:00, D 19:00, ES 21:00, close 22:00). Breakfast window
  becomes 6:00–10:00. ("let the breakfast time be 6am. I think that's more reasonable")
- **Q-CL1 floor — RULED: 10 g.** band = max(5% of owed(t), 10 g). ("floor of 10g")
- **CL-5 RE-RULED (full schedule):** Breakfast 6:00 · Morning Snack 9:00 · Lunch 12:00 ·
  Afternoon Snack 15:00 · Dinner 18:00 · Evening Snack 21:00; close 22:00 (unmentioned, kept —
  flagged in the lock-in for objection). ("morning snack at 9am. lunch at noon. after snack
  stays at 3pm. dinner at 6pm. evening snack at 9pm")
- **Q-CL10 — RULED: both yes.** An edited day target re-derives slots + checkpoints + ramp from
  the stored value; copy shows the stored per-day rate (the engine's number), not the protocol
  constant. ("both yes")
- **Q-CL9 — riding confirm taken silently:** slot times are fixed ruled values in release-1;
  configurability = future work. (No objection raised.)
- **Amendments (a) + (b1–b3) — stand as confirmations of the 2026-09-19/09-24 rulings** (S-5
  exception for the LOAD face; fourth face surface-chosen; E1 suppressed; P-1
  remember-not-clear). No objection raised.
- **Q-CL6 / amendment (b4) — RULED: close the gap in this refactoring.** The read-only
  carb-loading breakdown page moves INTO release-1 scope (exclusion list amended); E2's
  destination = that page; app-38 is asked to drive its design. ("I think this is a real gap
  that I actually would like to close at this refactoring. Would you send this gap back to the
  app agent... and ask it to help drive the design for this full breakdown page")
- **Amendment (d) — RULED: adopt the prototype's rendered strings VERBATIM as copy-register v1**
  (v16 is the extraction target): "N g behind pace" · "N g ahead of pace" · "On pace" ·
  "<target> g / planned" · "LOADED" / "N of N g"; N = whole grams; register lives in the
  carb-loading design surface spec, cross-ref intraday-display pattern; plus point-value
  protocol copy rows per Q-CL4/5. ("adopt verbatim")
- **Q-CL7 — riding confirm taken silently:** the six-slot scaffold is loading-day-driven,
  sparkle-independent; sparkle stays excluded from release-1. (No objection raised.)
- **DESK ADDITION (not interview):** v16 breakdown page renders carb macro strip in
  `electrolyte` — the D7 collision joins the desk batch with amendment (c) glow/orange ruling.
- **NOTE:** extraction target updated v15 → v16 (app-38, commit c7fb742b, sha f1444a55789b460b).

## Close-out (list CONFIRMED by Xuan — "I confirm the list")
- **Glow (amendment c, desk item):** handback carries Xuan's directive — the code agent researches
  the best Flutter libraries for glow materials "so it can match the Claude design or even exceed
  Claude design's aesthetic value". The MEANING contract still gets its desk A/B.
- **NEW GAP filed, not ruled:** intake/2026-09-24-carb-loading-daily-macros-collision.md —
  loading-day carb target vs daily-macros Formula 8 (premise verified: day −1-only 9.0 floor vs
  protocol 8/8/10 · 9/11 · 11; no floor days −3/−2; protein/fat/kcal never rebalance). Xuan
  chooses venue + bundle.
- **Extraction target:** v15 → v16 → **v17** (app-38: breakdown PROTOCOL chips navigate protocol
  days, ruled by Xuan directly with app-38; read-only holds; back chevron restores origin; spec
  commit c4f8e6e5). On the lookout for further iterations app-38 announces.

## Post-close addendum — Q-CL11 (ruled during vector emission)
- **Q-CL11 — RULED: Option R.** Ramp anchors = running sum of the ROUNDED slot targets; the
  22:00 anchor is forced to the day target (companion rule for edited targets whose rounded
  slots sum ±2 g off). Exact-fraction reading rejected — it flipped W7's verdict
  (516.8/25.84/on-pace vs 517/25.85/behind) and failed 3 worked examples. ("Option R (rounded
  anchors)") Caught by the spec-to-vectors oracle discipline; folded into CL-6 + §8 row.
  G2/G6 implication for app: v16/v17 already match R; the 22:00 CLAMP on edited targets is NEW.

## Entryway batch addendum (interview 2026-09-24, later — behavior RATIFIED, rendering OPEN)
Decisions Q-CE1..CE6 + CE-8 (verbatim log above this section's parent file's appendix tail):
- New app gates, all @v1-staged (reds land with the carb-loading@v1 tag):
  - [ ] **G7 — entry row + plan summary surface** (CE-1/CE-2): two states; summary opens the
        plan surface; bare chooser-Edit retired. Red: test-plan rows `entry-row-two-state`,
        `summary-opens-plan-surface`.
  - [ ] **G8 — post-selection routing** (CE-3): pop to event details, no pushReplacement;
        conditional today-CTA snackbar. Red: test-plan row `post-select-stack-shape`.
  - [ ] **G9 — chooser feasibility gate** (CE-8): choosable iff daysUntilRace >= protocolDays;
        race day = none (window-passed copy); disabled-with-reason cards. Red: vector family
        `chooser-feasibility` — LANDED 00d2834 in vectors/fueling/carb-loading-entryway.json (own file; supersedes the join-carb-loading.json wording) + test-plan row.
  - [ ] **G10 — re-pick migration** (CE-4/CE-4a): quiet-when-unedited; two-choice confirm;
        migrate-by-date; stable day-row identity update-in-place by plan+date. Red: vector
        family `repick-migration` — LANDED 00d2834 in vectors/fueling/carb-loading-entryway.json + test-plan rows.
  - [ ] **G11 — delete UI** (CE-5): dragonfruit register, Path-A-honest copy. Red: test-plan
        row `delete-plan-food-survives`.
- **Rendering NOT ratified:** summary surface / confirm dialog / disabled-card pixels await the
  prototype extension → desk. Implementation of G7–G11 pixels is gated on that desk ruling;
  behavior contracts above are final.


## Desk-sitting addendum (2026-09-25 — rendering RATIFIED; three reversals vs prototype v19)
Rulings: entryway rendering RATIFIED with container = PAGE (sheet retired); F3 target-relabel +
date; F4 single-notice when all edits drop; CE-7 footer YES; F1 feasible-set subtitle; copy
register v1 (v19 verbatim, amended by F1/F3/F4); F5 rides G9. Glow = GENERAL emphasis material
w/ usage rules (tokens.md §Materials); D7 = electrolyte stays on the breakdown macro strip
(named Q-D3 exception).
- [ ] **G12 — plan summary = PAGE** (retire the sheet fork in prototype + app). Red
      (@v1-staged): L1 golden `summary-page`, L2 `no-sheet-variant`.
- [ ] **G13 — confirm-dialog revisions** (F3 target-relabel + date; F4 single-notice variant;
      draft the F4 strings against the ruling for register fold). Red (@v1-staged): L2 rows
      `repick-dialog-target-labels`, `repick-single-notice-all-dropped` + copy-register rows.
- [ ] **G14 — CE-7 footer** on the breakdown page (navigation-only). Red (@v1-staged): L1
      golden `breakdown-footer`, L2 `footer-navigates-not-mutates`.
- [ ] **G15 — F1 subtitle** reflects the feasible set (or drops the enumeration). Red
      (@v1-staged): L2 `entry-row-subtitle-feasibility`.
- [ ] **G9 amendment — F5:** feasibility re-checked at selection time (midnight rollover).
- [ ] **G-glow note:** glow implementation may proceed per tokens.md §Materials `glow` (general,
      per-surface naming rule); D7 electrolyte strip stands — do NOT recolor.
Prototype: a conforming revision (v20) is owed for G12/G13/G14/G15; QA re-walks the deltas on
landing.


## Q-D batch addendum (2026-09-25 interview — Q-D9 B · Q-D10 strip · F6 abort; read-back confirmed)
- [ ] **G16 — dialog backdrop-abort (CE-9):** outside-tap dismisses BOTH re-pick dialogs with no
      mutation; chooser stays. Red (@v1-staged): L2 rows `repick-dialog-backdrop-abort`,
      `repick-notice-backdrop-abort` (negative: plan unchanged after abort).
- [ ] **Prototype v22 chores (app-38, before goldens freeze):** strip sparkle + "Today's Fuel"
      from loading days (Q-D10); add the CE-9 backdrop-abort to both dialogs. Q-D9 needs NO
      prototype change — the built expansion is now the ruled contract; its two strings are
      registered (`N g to go` clamp-at-0, `pace N g by now`).
- [ ] **Energy-card conformance rewrite lands with the bundle:** E1-toggles-on-LOAD and plain
      P-1 replace the old suppression rows; expanded-face goldens added.
