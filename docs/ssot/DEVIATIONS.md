# QA — Deviation Register

Behaviors observed in the app's code/UI that the **SSOT has NOT ratified**.

**Principle: implementation is not authorization.** Discovering that code does X is a reason
to log X *here*, NOT to rewrite the SSOT to say X. The SSOT stays the team's intended truth.
Resolving a deviation — fold it into the SSOT, or change the code — is a **deliberate,
separate decision**, never automatic just because the code implements it.

| status | meaning |
|---|---|
| `documented` | logged; SSOT deliberately NOT evolved; awaiting a future team decision |
| `pending-ruling` | surfaced; not yet decided how to treat |
| `resolved` | decision made (folded into SSOT, or code changed) — see note |

Conformance vectors that pin a deviation are marked `status: characterization` — a tripwire
so we notice if the behavior changes, **not** an endorsement of it as truth.

---

## D-001 — Pre-workout: fasted → zero pre-workout fuel
> **RULED (Xuan, 2026-09-03): the fasted state is RETIRED** — class-c contract change staged in
> the food-recommendation bundle (toggle removed, `is_fasted` deprecated on the wire, fasted
> branches removed). This deviation closes by removal; ledger P17/P11 close with it.
> Authority: RULING-DESK 2026-09-03 · `intake/2026-08-31-fasted-food-suppression-mechanism.md`.
- **Status:** `documented` (2026-07-26). SSOT deliberately NOT evolved.
- **Observed:** with the "Fasted Workout" toggle on, `calculatePreWorkoutTargets` returns
  all-zero pre-workout carbs/protein/fat/sodium/water and `meal_type='fasted'`.
- **Code:** `app/lib/features/nutrition_plan/data/offline_macro_calculator.dart:106`.
  **UI:** Create New Activity Plan → Running / Riding / Brick → "Fasted Workout" toggle
  (`presentation/widgets/new_activity/shared/fasted_toggle.dart`; Swimming forces it off).
- **SSOT status:** the pre-workout **carbs** SSOT (the Carb Section drawer) does not mention a
  fasted mode. **Fasted training has not been discussed by the team** — it appears to have
  shipped without ratification, and was not caught until this QA pass.
- **Decision (Xuan, 2026-07-26):** document only. Do NOT change or evolve the SSOT now.
  Revisit as a deliberate future decision.
- **Conformance:** pinned by the `fasted-all-zero` vector, marked `status: characterization`.
- **Open (only if the team later rules to keep it):** fold into the SSOT + update the results
  drawer to explain the fasted case (today the fasted guidance lives only on the *input* screen).
- **Observed 2026-08-26 (sim-explore, app `feature/pre-workout-before-card` @ `8bac1c1e`):** the
  engine returns zero/`tiers: []` and the BEFORE card renders "No carbs this session" (FC-4 ✓), but
  the food selector still places a carbohydrate food (Applesauce Pouch, 11 g) in the fasted snack.
  Known gap, **not** an app bug (Xuan, 2026-08-27) — resolved by the food-recommendation
  ratification together with this deviation. Ledger: `bundles/pre-workout-macros.deferred.md` P17.

## D-004 — Brick anomalies (UNCONFIRMED — need harness/code to adjudicate)
- **Status:** `pending-ruling` (2026-07-28). Two observations from the brick sim sweep (Ravi,
  swim/run/bike). **NOT yet confirmed as bugs** — the sim can't distinguish a real defect from a
  display/semantic quirk here; verify with the automated generate-plan harness (exact target vs
  `[low,high]`) or a code trace before acting.
- **D-004a — Brick macro-summary fluids look like ml labeled "oz".** On the brick "Adjust Your
  Macros" screen the FLUIDS row read PRE **250oz** / DURING **1356oz** / POST **1934oz** —
  implausible as oz (250oz ≈ 7.4 L pre-workout). As **ml** they're sane: 250 ml ≈ 8 oz, 1356 ml ≈
  46 oz, 1934 ml ≈ 65 oz. The brick **plan detail** (next screen) showed the sane **8oz** BEFORE,
  so the suspected unit-label bug is isolated to the **brick macro-summary aggregate** display,
  not the per-phase plan. Single-sport summaries convert ml→oz correctly (~34oz). Likely a
  brick-only ml-vs-oz display bug. VERIFY in the macro-summary widget.
- **D-004b — Brick per-segment DURING macros read below their range bars.** DURING RUN (3rd leg,
  27 min) showed **carbs 15g vs range [20,27]** and **sodium 100mg vs range [143,215]** — two
  macros pinned below the range low, with only "1 cup Sports Drink" delivered (no gap-fill topping
  it up). Could be (i) a real **H6** violation (gap-fill didn't fire for a brick sub-segment), or
  (ii) an honest **H1** shortfall the bar is displaying (marker pinned left) with no explicit
  warning text, or (iii) range-bar semantics I misread. VERIFY: does the brick During path run the
  same gap-fill as single-sport? Is a shortfall emitted? This is exactly what the automated
  invariant harness is for (reads exact target + `[low,high]`).
- **Open:** run both through the (not-yet-built) generate-plan invariant harness or trace the
  brick During + macro-summary code. Do NOT file app tasks until confirmed.

## D-003 — Safety-violating pin honored with NO warning (H2/D1 not implemented)
- **Status:** `pending-ruling` (2026-07-28). Surfaced by the generate-plan sim bug-hunt (Ravi).
  **Safety-relevant** — awaiting Xuan's ruling on whether to change the code (implement the
  D1/H2 warning) or evolve the SSOT.
- **Observed (sim + code, both confirmed):** a pinned pre-workout formula that contains an
  allergen on the athlete's list is **served in the plan with no warning of any kind**. Ravi
  (`allergies: [dairy, gluten]`) pinned the **Oatmeal** template (data-tagged with the `gluten`
  allergen — `_shared/nutrition/__fixtures__/dev-food-catalog.json:2879-2891`). The no-pin plan
  correctly excluded oatmeal and served **Banana**; after pinning, the regenerated plan served
  **"3 cups Oatmeal"** as the Full Meal, shown with a plain green ✓ in the "pins honored" banner
  and **no allergen badge / warning triangle / alert text** on the food card.
- **Code:** the pin-override path bypasses the allergen filter
  (`generate-macros-v4/pre-workout.ts:1006-1008` — `pinOverrideActive ? pinnedForPhase :
  getEligibleTemplates(...)`; policy comment lines 994-997 "bypassing dietary/dislike/allergen
  filters … in-scope pins are honored unconditionally"), and the emitted `pin_decision` object
  (~lines 1236-1250) carries only `used_pin / pinned_template_id / pinned_template_name /
  fallthrough_reason / pin_set_size` — **no safety/allergen field**. A repo-wide grep found no
  pin-safety-warning emission anywhere. So the warning half of D1/H2 is **not implemented** —
  this is a spec-vs-implementation GAP, not a UI dropping an existing flag.
- **What DOES work (not a deviation):** **H3 pin priority PASSES** — the pin correctly overrode
  the algorithm's safe choice (Banana → Oatmeal), scaled to hit the carb target (3 cups → 81g).
  The failure is strictly the missing *warning* the ratified D1/H2 requires.
- **SSOT status:** contradicts `spec/recommendation/generate-plan.md` **H2** ("any
  safety-violating pinned formula MUST always carry a visible warning") and **D1** ("a pinned
  formula violating safety will ALWAYS have a warning sign … if a user still pins it, it
  overrides safety"). The override half is honored; the warning half is absent.
- **Secondary (timing caveat, not the finding):** the pin's effect needs a **full fresh
  generation** — the local pin write uploads to Supabase non-blocking, so an immediate
  regenerate right after pinning can still show the pre-pin plan (observed: Full Meal stayed
  Banana on the first quick regenerate, became Oatmeal on a fresh Generate→Create). A QA-harness
  caveat (confirm the pin synced before asserting) and a possible minor UX papercut.
- **Open:** Xuan's ruling — implement the D1/H2 warning (recommended, safety) vs. re-open D1.
  If code is to change, it's a Lee task (emit an allergen-violation flag on `pin_decision` +
  render a warning badge). Note the two pin surfaces (see the memory / sim-nav): the Formula
  Library card "Pin formula" (bookmark) and the plan "Pin your favorite formula" both write the
  same `formula_pins` store and both feed generation.

## D-002 — Pre-workout carbs: 0.5 g/kg floor below the cited research minimum
- **Status:** `resolved` — **ACCEPTED into the SSOT** (Xuan, 2026-07-26).
- **Observed:** `carbPerKg = max(0.5, min(hoursBefore, 4.0))` — for lead times < 30 min the
  floor is 0.5 g/kg, below the drawer's cited basis (Kerksick 1–4 g/kg).
- **Code:** `offline_macro_calculator.dart:131`.
- **Decision (Xuan, 2026-07-26):** ACCEPT — fold into the SSOT as a Mealvana design-choice
  minimum for very short lead times (some carbs beat none). Now a ratified constant (see the
  spec constants table); its vector reclassified `status: ratified`. This was the deliberate
  act that evolving the SSOT requires — not an automatic absorption of code behavior.

## D-005 — Twin split: the dashboard renders server AND client numbers in one total
- **Status:** `pending-ruling` (2026-08-22). Registered as the **verification target** for the
  Engineering SSOT (`PLAN.md` Phase 6). Close this entry only by re-observing the app, never by
  reading the diff.
- **Observed (prod TestFlight 1.24.0 + the 2026-08-22 fix, athlete's own account, Aug 29):**
  one "Today's Energy" card sums four numbers from the edge function — fuel target 3,037,
  Resting 1,064, Daily movement 275, Digestion 304 — with three computed by the local Dart twin:
  Long run 1,173, Foam rolling 117, Workout row 1,290. The engine's own answer for that same
  workout row (~1,394) sits unused in the cached `daily_macro_targets` row on the device. The
  two disagree by ~104 kcal, visible to the athlete as a projected burn of 2,933 against a
  3,037 target.
- **Mechanism (both halves verified in code):**
  1. **Lossy response.** `pipeline.ts:587` maps each `ResolvedSessionData` down to source TAGS
     only (`kcal_source`, `if_source`, `tss_source`, `duration_source`), discarding the
     per-session `session_kcal`, `duration_hr` and `intensity_factor` it just computed. The
     client is sent a day-level total and provenance labels, never per-session values — so it
     *cannot* display the engine's per-card number.
  2. **Unused cached total.** `targets.sessionKcal` (the engine's day total, already on device)
     is referenced exactly once in `dashboard_assembler.dart:464`, and only for weekly carb
     periodization. The Active Energy workout total is summed from locally-computed cards at
     `dashboard_assembler.dart:362–370`.
  3. **No fallback semantics.** Grep of `lib/features/macro_dashboard/` for
     `connectivity` / `isOnline` / `hasNetwork` returns nothing. The twin is not an offline
     backup on this surface; it is the sole source, online and offline alike.
- **Why it is a deviation and not merely a bug:** nobody chose this. The intended architecture —
  stated by the spec owner, 2026-08-22: *"I always thought the local dart is only the offline
  backup and never used if internet is on"* — is not what ships, and no SSOT states the rule
  either way. Implementation is not authorization; the rule gets ratified, then the code conforms.
- **Consequence worth noting:** closing this largely DISSOLVES the open zoneless-IF question
  (`intake/2026-08-20-zoneless-if-default-engine-vs-display.md`) for the online case — if the
  dashboard renders the engine's number there is no second opinion left to diverge, and the
  ~104 kcal goes to zero by construction. The IF ruling still governs the fallback rung.
- **Verification when the Engineering SSOT ships (all three must hold):**
  1. The engine's response carries per-session results keyed by `activity_id` (already threaded
     at `index.ts:202`) — purely additive, so old clients are unaffected.
  2. On a day with a fresh (non-invalidated) cached calculation, every displayed session figure
     is the engine's, and the sum of displayed session kcal equals `targets.sessionKcal`.
  3. The local twin still prices a just-added or offline workout, is labelled as an estimate,
     and is superseded the moment a recalculation lands.
- **Related:** `ops/data/bug-reports/2026-08-22-dashboard-prices-distance-sessions-at-flat-60min.md`
  (the duration half of this same split, fixed 2026-08-22 by sharing the ladder — which removed
  the 649 kcal error but not the architecture that allowed it).

## D-006 — White surfaces on the light theme (design; brand rule says never white)

- **status:** `documented` — RULED (Xuan, 2026-08-25, Q-SA1 in `spec/design/source-authority.md`):
  a deviation to log, not a rule to revise.
- **Where:** `app/lib/theme/kyle_design/app_colors.dart` — `surfaceLight = #FFFFFF`,
  `surfaceLightSecondary = #F9F9F9`; light-mode cards and sheets render on white.
- **What the SSOT says:** the design library's golden rule 2 — *"Cream bg + Blackberry text, or
  Blackberry bg + Cream text. Never white."* Cream is `--me-cream` in `spec/design/tokens.md`.
- **Why it is a deviation and not a bug:** the app's light theme was built on Material's white
  surfaces before the Endurance palette existed; nobody chose white against the rule. The rule
  stands; the code does not conform; resolving it is a deliberate light-theme pass, not a hotfix.
- **Surfaced by:** the 2026-08-25 brand-fidelity audit (app-side).

## D-007 — Brick: SKIPPED legs are silently linkable
- **Status:** `documented` (2026-08-31). **Spec now rules against it** — `spec/domain/brick.md`
  R5 (Xuan, 2026-08-31): a SKIPPED leg may not be linked.
- **Observed:** `brick_eligibility.dart` / `brick_selection_controller.dart` apply only the
  sport-set + not-already-a-brick filters; a `status = skipped` workout passes and can become a
  leg of a fueled brick.
- **Resolution path:** app fix per the 2026-08-31 handback; pinned by a `brick-eligibility`
  vector (R5 negative case) once `spec-to-vectors` runs on the domain slice.

## D-008 — Brick: transition identity keyed by sport pair; consumer looks up positionally
- **Status:** `documented` (2026-08-31). **Spec now rules against it** — `spec/domain/brick.md`
  R8: transition identity is positional; the sport pair is a label only.
- **Observed:** `generate-macros-v4/brick-workout.ts:286-292,449-456` names swim→bike `T1`,
  bike→run `T2`, else `T{i+1}`; `generate-nutrition-plan-v3/brick-handler.ts:519` looks up
  `T{i+1}` positionally. A plain **bike→run** brick (one transition, index 0) emits `T2`, the
  consumer asks for `T1`, misses, and falls to zero-default transition targets
  (`brick-handler.ts:66-73` logs the fallback). Repeat legs (R2, now legal) additionally
  collide: bike→run→bike emits `T2`,`T2` and the name-keyed map keeps only the last.
- **Resolution path:** app/edge fix per the 2026-08-31 handback (emit positional ids, keep the
  pair as a label field) + the R8 producer-shaped seam test. The fuel *amounts* at transitions
  stay owned by the in-progress transition-nutrition slice — this entry is identity only.

## D-018 — Fueling-window state resets per activity (implemented ahead of its ruling)
- **Status:** `implemented-pending-ruling` (2026-09-03). Xuan's call: fix now, rule later.
- **Observed / shipped:** `resetFuelingWindowForNewActivity()` on all four sport input
  controllers, invoked once at create-screen entry (app `7418566f`, branch
  `feature/food-recommendation-v1`). It clears the `*ManuallySet` flag and re-derives the §3a
  default for the activity being created.
- **Why it is not a self-ratification:** the fix sits in the **intersection of every option** the
  open ruling could take — per-activity reset (a) and values-sticky-but-flags-reset (b) both
  require it, and even (c) "ratify today's behaviour" was written requiring the window to still
  re-clamp. It touches ONLY the fueling window; the lifetime of the other form state
  (title / temperature / humidity flags) is untouched and remains the ruling's to decide.
- **SSOT status:** `create-flow-fueling-controls.md` CF-1 says a manual change persists — it does
  not say for how long. That gap is the open question, not a contradiction, so no ratified
  contract was changed to match code.
- **Un-deferred by:** `intake/2026-09-03-form-state-reset-semantics.md` (Q-CA2). When ruled, this
  entry either folds into CF-9 as ratified behaviour or the implementation is amended to match a
  different choice.

