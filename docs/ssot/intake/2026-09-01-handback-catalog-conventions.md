# APP-SIDE HANDBACK — catalog conventions ruling (2026-09-01)

Scope: gated INSIDE the brick-transition bundle's implementation. Resolve `$APP_ROOT` via
`workspace.env` / `find_workspace`. Authority: `spec/domain/catalog-conventions.md` v1 (this
branch); intake sources stamped on `qa/food-recommendation`.

- [ ] **One catalog migration, replayable dev + prod** (catalogs verified row-identical
      2026-09-01): zero `fluid_ml` on electrolyte_tablet / electrolyte_packet /
      electrolyte_drink_mix / high_sodium_electrolyte_mix / carb_drink_mix / high_carb_drink_mix;
      set `is_indivisible = true` on energy_gel and single-serve sticks/packets. Leave
      sports_drink_mix, pickle_juice_shot, oatmeal, fruit/rice untouched (C1 rationale).
- [ ] **Pairing scope extension (C2)** in `supabase/functions/_shared/nutrition/electrolyte-water-pairing.ts`
      AND its Dart mirror `lib/features/nutrition_plan/application/client_plan/electrolyte_water_pairing.dart`
      — same commit, twin-sync rule; add the `requires_water` derivation the team prefers.
- [ ] **Transition selection constraints (C4):** whole-unit rounding + max-2-items in the
      transition path (`generate-nutrition-plan-v3/brick-handler.ts` LP options currently
      maxFoodItems=3, maxServingsCap=2 — align to the ruled 2 + water).
- [ ] **Fluid accounting (C1/A3):** delivered-fluid sums count drinkable rows + food-embedded
      water as catalogued; with the C1 zeros in place the double-count disappears — verify the
      P13-class overshoot (44 oz) no longer reproduces on a 240-min plan.
- [ ] Re-run conformance suites via `qa/conformance/run_dart.sh` per slice and report counts
      (no vector regeneration required — food-composition vectors are suitability-function
      vectors, engine null, untouched by catalog data).
- [ ] Cross-refs for context: ops bugs `../ops/data/bug-reports/2026-08-31-server-electrolyte-pick-diverges-from-dart-fix.md`
      (twin reconciliation — same files touched; consider one pass) and this branch's transition
      spec once ratified.
