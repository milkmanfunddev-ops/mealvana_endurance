import 'dart:math' as math;

/// Offline calculator for macro recommendations when the edge function is
/// unavailable.
///
/// **Authority is split, and it is not "whatever the edge function does".**
///
/// * The **pre-workout** surfaces — [OfflineMacroCalculator.calculatePreWorkoutHydration]
///   and [OfflineMacroCalculator.calculatePreWorkoutCarbs] — implement the ratified
///   SSOTs directly. The edge function
///   (`supabase/functions/generate-macros-v4/pre-workout.ts`) is a *mirror* of the
///   same specs, not the source. Where the two disagree, the spec wins and the
///   conformance vectors say so:
///     - `docs/ssot/spec/fueling/pre-workout-hydration.md` v6
///     - `docs/ssot/spec/fueling/pre-workout-carbs.md`     v2
///     - `docs/ssot/spec/fueling/pre-workout-sodium.md`    v3
///     - vectors: `docs/ssot/vectors/fueling/pre-workout-{hydration,carbs,sodium}.json`
///
/// * **During-workout** and **post-workout** math still mirrors the edge function
///   exactly (`single-sport.ts`, `brick-workout.ts`,
///   `_shared/nutrition/sweat-hydration.ts`) and is untouched by the v6/v2/v3
///   pre-workout bundle.
///
/// **The pre-workout engine never rounds.** Its outputs are exact doubles;
/// rounding is a display concern owned by the consumer. The only place an int
/// appears is the legacy [calculatePreWorkoutTargets] map boundary, which rounds
/// at the very last step so existing consumers keep working.
class OfflineMacroCalculator {
  static const double _miToKm = 1.60934;
  static const double _mlToFlOz = 0.033814;
  static const double _mphToMPerMin = 26.8224;

  // ============================================================================
  // DURATION CARB BANDS (mirrors getDurationCarbBand in single-sport.ts)
  // ============================================================================

  /// Returns [baseLow, baseHigh] g/hr raw band for a given duration in minutes.
  static List<int> getDurationCarbBand(double durationMin) {
    if (durationMin < 60) return [0, 30];
    if (durationMin < 90) return [30, 60];
    if (durationMin < 150) return [45, 60];
    if (durationMin < 240) return [60, 90];
    return [80, 100];
  }

  /// Gut-training multiplier (mirrors getGutTrainingMultiplier).
  static double getGutTrainingMultiplier(String gutTraining) {
    switch (gutTraining) {
      case 'low':
        return 0.7;
      case 'high':
        return 1.2;
      default:
        return 1.0; // 'moderate' or unknown
    }
  }

  /// Sport carb ceiling g/hr (mirrors getSportCarbCeiling).
  static int getSportCarbCeiling(String activityType) {
    switch (activityType) {
      case 'running':
        return 70;
      case 'cycling':
        return 120;
      case 'swimming':
        return 0;
      default:
        return 70;
    }
  }

  /// Calculate during-workout carb rate (mirrors calculateDuringWorkoutCarbRate).
  ///
  /// Returns a map with keys matching the edge-function response shape:
  ///   rate_gph, band_low, band_high, raw_band_low, raw_band_high,
  ///   gut_multiplier, sport_ceiling.
  static Map<String, dynamic> calculateDuringWorkoutCarbRate({
    required double durationMin,
    required String activityType,
    required String gutTraining,
  }) {
    final band = getDurationCarbBand(durationMin);
    final baseLow = band[0].toDouble();
    final baseHigh = band[1].toDouble();
    final gutMult = getGutTrainingMultiplier(gutTraining);
    final scaledLow = baseLow * gutMult;
    final scaledHigh = baseHigh * gutMult;
    final carbRate = (scaledLow + scaledHigh) / 2.0;
    final sportCeiling = getSportCarbCeiling(activityType);
    final finalRate = math.min(carbRate, sportCeiling.toDouble());

    // Mirror the edge fn: the band obeys the sport ceiling like the rate
    // does (otherwise the target can sit below its own displayed range), and
    // a fully-bound band widens its low end by the ±12.5% phase convention
    // instead of collapsing to a knife-edge point.
    var bandLow = math.min(scaledLow, sportCeiling.toDouble());
    final bandHigh = math.min(scaledHigh, sportCeiling.toDouble());
    if (bandLow >= bandHigh && bandHigh > 0) {
      bandLow = bandHigh * 0.875;
    }

    return {
      'rate_gph': (finalRate * 10).round() / 10.0,
      'band_low': bandLow.round(),
      'band_high': bandHigh.round(),
      'raw_band_low': baseLow.round(),
      'raw_band_high': baseHigh.round(),
      'gut_multiplier': gutMult,
      'sport_ceiling': sportCeiling,
    };
  }

  // ===========================================================================
  // TRANSITION CARBS — SSOT: docs/ssot/spec/fueling/transition-nutrition.md v1
  // (RATIFIED Xuan 2026-09-01). Conformance vectors:
  // docs/ssot/vectors/fueling/transition-nutrition.json.
  // Twin: calculateTransitionCarbDose in
  // supabase/functions/generate-macros-v4/brick-workout.ts — change both or
  // neither.
  // ===========================================================================

  /// T-1 constants (spec §Constants — Mealvana design choices, notes L2/L3/L5).
  static const double transitionPreBufferMin = 15.0;
  static const Map<String, double> transitionSettleMin = {
    'cycling': 10.0,
    'running': 15.0,
    // Oracle convention: the rate into a swim is 0, so the gap never matters.
    'swimming': 0.0,
  };

  /// Flat by ratified default (Q-TN4 open: gut-scaled clamp).
  static const int transitionClampG = 30;

  /// Silent default when no stop time arrives (Q-TN3 open: form input).
  static const double transitionMinDefault = 3.0;

  /// The transition carb dose for the gap after segment [transitionIndex].
  ///
  /// T-1: `dose_g = clamp(round(rate_gph × effective_gap_min / 60), 0, 30)`;
  /// band `[0, 30]` on every transition; 0 is a legitimate value.
  ///
  /// T-2 (rate source — no new rate math): the during-carbs core for the
  /// NEXT segment — band keyed by cumulative event time THROUGH that
  /// segment, gut multiplier, midpoint, next sport's ceiling. The brick
  /// ×0.8 penalty and personal overrides do NOT apply here.
  ///
  /// T-3: a zero-intake previous leg (swim: ceiling 0) contributes its whole
  /// duration to the gap INSTEAD OF the 15-min pre-buffer.
  ///
  /// T-4: whole grams (half-away-from-zero — Dart's `round()`).
  static TransitionCarbDoseResult calculateTransitionCarbDose({
    required List<TransitionDoseSegment> segments,
    required int transitionIndex,
    String gutTraining = 'moderate',
    double? transitionMin,
  }) {
    final prev = segments[transitionIndex];
    final next = segments[transitionIndex + 1];
    final tMin = transitionMin ?? transitionMinDefault;

    double cumThroughNextMin = 0.0;
    for (int i = 0; i <= transitionIndex + 1; i++) {
      cumThroughNextMin += segments[i].durationMin;
    }
    final band = getDurationCarbBand(cumThroughNextMin);
    final gutMult = getGutTrainingMultiplier(gutTraining);
    final midpoint = ((band[0] * gutMult) + (band[1] * gutMult)) / 2.0;
    final nextSport = next.sport.toLowerCase();
    final rate = math.min(midpoint, getSportCarbCeiling(nextSport).toDouble());

    final prevSport = prev.sport.toLowerCase();
    final leadInMin = getSportCarbCeiling(prevSport) == 0
        ? prev.durationMin
        : transitionPreBufferMin;
    final settleMin =
        transitionSettleMin[nextSport] ?? transitionSettleMin['running']!;
    final effectiveGapMin = leadInMin + tMin + settleMin;

    final rawDose = rate * effectiveGapMin / 60.0;
    final dose = rawDose.round().clamp(0, transitionClampG);

    return TransitionCarbDoseResult(
      doseG: dose,
      bandLowG: 0,
      bandHighG: transitionClampG,
      rateGPerH: rate,
      effectiveGapMin: effectiveGapMin,
      transitionMin: tMin,
    );
  }

  // ============================================================================
  // PRE-WORKOUT CARBOHYDRATE — SSOT: docs/ssot/spec/fueling/pre-workout-carbs.md v2
  // ============================================================================

  /// Minutes before the workout at which the `meal` tier opens.
  ///
  /// SSOT: pre-workout-carbs.md v2 — `TIER_MEAL_MIN = 120.0`. Basis: Tougas/ANMS
  /// gastric-emptying normals (a low-fat solid meal is 30–60 % retained at 2 h).
  ///
  /// Numerically equal to [tRef] for an **unrelated** reason. Pinned equal by
  /// [assertCrossSpecPin]; neither is derived from the other.
  static const double tierMealMin = 120.0;

  /// Minutes before the workout at which the `top_off` tier closes.
  /// SSOT: pre-workout-carbs.md v2 — `TIER_TOPOFF_MAX = 30.0` (Mealvana design
  /// choice; cited practice is 10–15 min, J&G p. 491 — 30 errs early).
  static const double tierTopOffMax = 30.0;

  /// Outer edge of Thomas 2016's carbohydrate window, in minutes.
  /// SSOT: pre-workout-carbs.md v2 — `WINDOW_MAX = 240.0`.
  static const double windowMax = 240.0;

  /// Tier shares when a meal window exists (t >= [tierMealMin]): 60 / 30 / 10.
  /// SSOT: pre-workout-carbs.md v2 — Mealvana design choice, Xuan 2026-08-03.
  static const double shareMeal = 0.60;
  static const double shareSnack = 0.30;
  static const double shareTopOff = 0.10;

  /// Tier shares when no meal window exists: 75 / 25.
  /// SSOT: pre-workout-carbs.md v2 — Mealvana design choice, Xuan 2026-08-03.
  static const double shareSnackNoMeal = 0.75;
  static const double shareTopOffNoMeal = 0.25;

  /// ±12.5 % — the one tolerance, used for every carbohydrate number: each
  /// tier's food-match window and (in the design_choice regime) the plan band.
  /// SSOT: pre-workout-carbs.md v2 — `TIER_TOL = 0.125` (design choice,
  /// explicitly not research).
  static const double tierTol = 0.125;

  /// Lower edge of Thomas 2016 Table 2's carbohydrate window, in minutes.
  /// SSOT: pre-workout-carbs.md v2 — the `inWindow` lower test.
  static const double citedWindowMinMin = 60.0;

  /// Minimum workout duration for Thomas 2016 Table 2's "before exercise
  /// >= 60 min" situation. Inclusive.
  /// SSOT: pre-workout-carbs.md v2.
  static const double citedMinWorkoutMin = 60.0;

  /// Cited dose band, g/kg. SSOT: pre-workout-carbs.md v2 — Thomas 2016
  /// Table 2, verbatim (origin Burke 2011 Table II).
  static const double carbBandLowGPerKg = 1.0;
  static const double carbBandHighGPerKg = 4.0;

  /// Pre-workout carbohydrate plan.
  ///
  /// SSOT: `docs/ssot/spec/fueling/pre-workout-carbs.md` v2 (RATIFIED,
  /// Xuan 2026-08-04). Conformance vectors:
  /// `docs/ssot/vectors/fueling/pre-workout-carbs.json`.
  ///
  /// Exact doubles — **this function never rounds.**
  ///
  /// Shape of the algorithm:
  ///   * `isFasted` short-circuits **first** → zeros, empty tiers,
  ///     `targetBasis: 'none'` (D-001, shipped, still unratified).
  ///   * `carbPerKg = min(t / 60, 4.0)` — v1's `max(0.5, …)` floor is REMOVED
  ///     (D-002 superseded, Xuan 2026-08-03).
  ///   * Three-way tier split by lead time; the `top_off` tier is always
  ///     present, even carrying 0 at t = 0 (distinguishable from the fasted
  ///     path, which emits no tiers at all).
  ///   * Plan band is Thomas's cited `[1, 4] g/kg` only when BOTH the lead time
  ///     is inside `[60, 240]` and the workout is >= 60 min; otherwise ±12.5 %
  ///     of the total, tagged `design_choice`.
  static PreWorkoutCarbResult calculatePreWorkoutCarbs({
    required double bodyWeightKg,
    required double timeBeforeWorkoutMin,
    required double workoutDurationMin,
    bool isFasted = false,
  }) {
    assert(_crossSpecPinHolds, _crossSpecPinMessage);

    // D-001 — fasted returns nothing at all, and does so BEFORE any tier work.
    // Empty `tiers` + basis 'none' is what distinguishes it from the t = 0 path.
    if (isFasted) {
      return const PreWorkoutCarbResult(
        carbsG: 0.0,
        carbsLowG: 0.0,
        carbsHighG: 0.0,
        tiers: <PreWorkoutCarbTier>[],
        targetBasis: 'none',
      );
    }

    final t = math.max(timeBeforeWorkoutMin, 0.0);
    final bw = bodyWeightKg;

    // No 0.5 g/kg floor — the plain diagonal of Thomas's cited box, running to
    // 0 at t = 0 ("you can drink at the gun, not eat").
    final carbPerKg = math.min(t / 60.0, carbBandHighGPerKg);
    final total = bw * carbPerKg;

    final double meal;
    final double snack;
    final double topOff;
    if (t >= tierMealMin) {
      meal = shareMeal * total;
      snack = shareSnack * total;
      topOff = shareTopOff * total;
    } else if (t >= tierTopOffMax) {
      meal = 0.0;
      snack = shareSnackNoMeal * total;
      topOff = shareTopOffNoMeal * total;
    } else {
      meal = 0.0;
      snack = 0.0;
      topOff = total; // only window open
    }

    // Tier membership (invariant 6): `meal` iff t >= 120; `snack` iff t >= 30;
    // `top_off` always. Ordered furthest-out first.
    final tiers = <PreWorkoutCarbTier>[
      if (t >= tierMealMin) _carbTier('meal', meal),
      if (t >= tierTopOffMax) _carbTier('snack', snack),
      _carbTier('top_off', topOff),
    ];

    // Plan band. `WINDOW_MAX`'s upper test cannot fire false while the app caps
    // input at 240 (D-016 notwithstanding) — it is kept as the guard that stops
    // a raised input maximum silently escaping Thomas's window.
    final inWindow =
        t >= citedWindowMinMin &&
        t <= windowMax &&
        workoutDurationMin >= citedMinWorkoutMin;

    final double carbsLowG;
    final double carbsHighG;
    final String targetBasis;
    if (inWindow) {
      carbsLowG = carbBandLowGPerKg * bw;
      carbsHighG = carbBandHighGPerKg * bw;
      targetBasis = 'evidenced_band';
    } else {
      carbsLowG = total * (1.0 - tierTol);
      carbsHighG = total * (1.0 + tierTol);
      targetBasis = 'design_choice';
    }

    return PreWorkoutCarbResult(
      carbsG: total,
      carbsLowG: carbsLowG,
      carbsHighG: carbsHighG,
      tiers: List.unmodifiable(tiers),
      targetBasis: targetBasis,
    );
  }

  /// Build one carbohydrate tier with its ±[tierTol] food-match window.
  /// `composition` mirrors `tier`; its *value set* is owned by
  /// `docs/ssot/spec/fueling/pre-workout-food-composition.md`, not by this file.
  static PreWorkoutCarbTier _carbTier(String tier, double carbsG) {
    return PreWorkoutCarbTier(
      tier: tier,
      carbsG: carbsG,
      rangeLowG: carbsG * (1.0 - tierTol),
      rangeHighG: carbsG * (1.0 + tierTol),
      composition: tier,
    );
  }

  // ============================================================================
  // PRE-WORKOUT TARGETS (legacy map shape; carbs delegate to the v2 SSOT)
  // ============================================================================

  /// Calculate pre-workout macro targets with low/high ranges.
  ///
  /// **Carbohydrate is no longer computed here** — `carbs_g` / `carbs_low_g` /
  /// `carbs_high_g` delegate to [calculatePreWorkoutCarbs]
  /// (SSOT: `docs/ssot/spec/fueling/pre-workout-carbs.md` v2) and are rounded to
  /// int **only at this map boundary**, so the legacy consumers of this shape
  /// keep working. The engine itself stays exact.
  ///
  /// Everything else in the map (protein / fat / meal_type / water_* / sodium_*)
  /// is out of the v6/v2/v3 pre-workout bundle's scope, still feeds food
  /// selection, and is deliberately unchanged.
  ///
  /// [workoutDurationMin] is only used to decide whether the carbohydrate plan
  /// band may be tagged `evidenced_band` (Thomas 2016 scopes its band to
  /// sessions >= 60 min). When it is null the band falls back to ±12.5 % of the
  /// total — which is exactly what the legacy v1 code produced.
  ///
  /// The **occasion boundaries follow the tier boundaries** — [tierMealMin]
  /// (120 min) and [tierTopOffMax] (30 min), read from those constants so they
  /// cannot drift from the tier definitions again. v1 branched at 2.5 h / 1.0 h,
  /// which made this map say `snack` at a 120-min lead while the engine opened
  /// the `meal` tier. The edge-function mirror has moved to 120/30 as well.
  ///
  /// The per-branch **formulas** below are untouched legacy behaviour — no
  /// ratified SSOT governs pre-workout protein / fat / water / sodium, and this
  /// bundle does not introduce one. Only the boundary moved.
  ///
  ///   - fasted     → all zeros, meal_type='fasted'
  ///   - full_meal  (≥120 min): protein=0.25g/kg [0.15–0.35], fat=0.4g/kg
  ///   - snack      (30–120 min): protein=0.15g/kg [0–0.25], fat=5g
  ///   - top_up     (<30 min):  protein=0 [0–10g], fat=0
  static Map<String, dynamic> calculatePreWorkoutTargets({
    required double weightKg,
    required double hoursBefore,
    required bool isFasted,
    String sweatSodiumCat = 'average',
    String envLabel = 'normal',
    double? workoutDurationMin,
  }) {
    if (isFasted) {
      return {
        'carbs_g': 0,
        'carbs_low_g': 0,
        'carbs_high_g': 0,
        'protein_g': 0,
        'protein_low_g': 0,
        'protein_high_g': 0,
        'fat_g': 0,
        'sodium_mg': 0,
        'sodium_low_mg': 0,
        'sodium_high_mg': 0,
        'water_ml': 0,
        'water_low_ml': 0,
        'water_high_ml': 0,
        'meal_type': 'fasted',
      };
    }

    // Carbs — SSOT: docs/ssot/spec/fueling/pre-workout-carbs.md v2.
    // Delegated, exact, then rounded once here at the map boundary.
    final carbPlan = calculatePreWorkoutCarbs(
      bodyWeightKg: weightKg,
      timeBeforeWorkoutMin: hoursBefore * 60.0,
      workoutDurationMin: workoutDurationMin ?? 0.0,
      isFasted: false, // the fasted path returned above
    );
    final carbs = carbPlan.carbsG.round();
    final carbsLow = carbPlan.carbsLowG.round();
    final carbsHigh = carbPlan.carbsHighG.round();

    // Sodium base by sweat category
    final baseSodium = sweatSodiumCat == 'low'
        ? 300
        : sweatSodiumCat == 'medium'
        ? 450
        : 600;
    final envBump = (envLabel == 'hot' || envLabel == 'very_hot') ? 100 : 0;
    final mealSodium = baseSodium + envBump;
    final snackSodium = ((baseSodium + envBump) * 0.5).round();
    final topUpSodium = envBump + 100;

    int protein;
    int proteinLow;
    int proteinHigh;
    int fat;
    int sodium;
    int sodiumLow;
    int sodiumHigh;
    int hydration;
    int hydrationLow;
    int hydrationHigh;
    String mealType;

    // The occasion boundaries are the TIER boundaries, read from the same named
    // constants the tier split uses — NOT fresh literals, and no longer v1's
    // 2.5 h / 1.0 h. At a 120-min lead the engine opens the `meal` tier, so the
    // map must say `full_meal`; at a 30-min lead the engine opens `snack`, so
    // the map must say `snack`. Anything else has the map contradicting the
    // tiers it is now built from — and diverging from the edge-function mirror,
    // which has already moved to 120/30.
    //
    // Only the BOUNDARY is governed by the SSOT here. The protein / fat /
    // water / sodium formulas inside each branch are out-of-bundle legacy
    // behaviour that no ratified spec covers; they are deliberately unchanged.
    final timeBeforeMin = hoursBefore * 60.0;

    if (timeBeforeMin >= tierMealMin) {
      // Full meal — the `meal` tier is open (SSOT: pre-workout-carbs.md v2
      // TIER_MEAL_MIN).
      protein = (weightKg * 0.25).round();
      proteinLow = (weightKg * 0.15).round();
      proteinHigh = (weightKg * 0.35).round();
      fat = (weightKg * 0.4).round();
      sodium = mealSodium + snackSodium + topUpSodium;
      hydration = (weightKg * 6.5).round();
      mealType = 'full_meal';
      sodiumLow = 200;
      sodiumHigh = 2000;
      hydrationLow = math.max(200, (hydration * 0.50).round());
      hydrationHigh = math.max(600, (hydration * 1.50).round());
    } else if (timeBeforeMin >= tierTopOffMax) {
      // Snack — no meal window, but the `snack` tier is open (SSOT:
      // pre-workout-carbs.md v2 TIER_TOPOFF_MAX).
      protein = (weightKg * 0.15).round();
      proteinLow = 0;
      proteinHigh = (weightKg * 0.25).round();
      fat = 5;
      sodium = snackSodium + topUpSodium;
      hydration = (weightKg * 5.5).round();
      mealType = 'snack';
      sodiumLow = 100;
      sodiumHigh = 1000;
      hydrationLow = math.max(150, (hydration * 0.50).round());
      hydrationHigh = math.max(500, (hydration * 1.50).round());
    } else {
      // Top-up — only the `top_off` tier is open.
      protein = 0;
      proteinLow = 0;
      proteinHigh = 10;
      fat = 0;
      sodium = topUpSodium;
      hydration = 250;
      mealType = 'top_up';
      sodiumLow = 0;
      sodiumHigh = 400;
      hydrationLow = 0;
      hydrationHigh = 500;
    }

    return {
      'carbs_g': carbs,
      'carbs_low_g': carbsLow,
      'carbs_high_g': carbsHigh,
      'protein_g': protein,
      'protein_low_g': proteinLow,
      'protein_high_g': proteinHigh,
      'fat_g': fat,
      'sodium_mg': sodium,
      'sodium_low_mg': sodiumLow,
      'sodium_high_mg': sodiumHigh,
      'water_ml': hydration,
      'water_low_ml': hydrationLow,
      'water_high_ml': hydrationHigh,
      'meal_type': mealType,
    };
  }

  // ============================================================================
  // POST-WORKOUT (mirrors post-workout functions in single-sport.ts)
  // ============================================================================

  /// Post-workout carbs (mirrors calculatePostWorkoutCarbs).
  static int calculatePostWorkoutCarbs({
    required double weightKg,
    required double durationH,
    required bool isFasted,
  }) {
    final durationMultiplier = durationH > 2 ? 1.2 : 1.0;
    final fastedMultiplier = isFasted ? 1.2 : 1.0;
    return (weightKg * durationMultiplier * fastedMultiplier).round();
  }

  /// Post-workout protein (mirrors calculatePostWorkoutProtein).
  static int calculatePostWorkoutProtein({
    required double weightKg,
    required double durationH,
    required bool isFasted,
  }) {
    double proteinPerKg;
    if (durationH <= 0.75) {
      proteinPerKg = 0.25;
    } else if (durationH <= 1.5) {
      proteinPerKg = 0.30;
    } else if (durationH <= 2.5) {
      proteinPerKg = 0.35;
    } else {
      proteinPerKg = 0.40;
    }
    if (isFasted) proteinPerKg += 0.05;
    return math.min(40, math.max(20, (weightKg * proteinPerKg).round()));
  }

  /// Post-workout fat (mirrors calculatePostWorkoutFat).
  static int calculatePostWorkoutFat(double weightKg) {
    return (weightKg * 0.2).round();
  }

  /// Post-workout hydration (mirrors calculatePostWorkoutHydration).
  ///
  /// Returns {sodium_mg, hydration_ml}.
  static Map<String, int> calculatePostWorkoutHydration({
    required double durationH,
    required double actualSweatRateLph,
    required int sodiumConcMgPerL,
    required int duringHydrationMl,
  }) {
    final totalSodiumLossMg = actualSweatRateLph * sodiumConcMgPerL * durationH;
    final duringSodiumMg =
        (actualSweatRateLph * sodiumConcMgPerL * 0.6 * durationH).round();
    final sodiumDeficitMg = totalSodiumLossMg - duringSodiumMg;
    final postSodiumMg = math.max(
      300,
      math.min(700, (sodiumDeficitMg * 0.5).round()),
    );
    final totalHydrationLossMl = actualSweatRateLph * 1000.0 * durationH;
    final hydrationDeficitMl = totalHydrationLossMl - duringHydrationMl;
    final postHydrationMl = math.max(500, (hydrationDeficitMl * 1.5).round());

    return {'sodium_mg': postSodiumMg, 'hydration_ml': postHydrationMl};
  }

  // ============================================================================
  // MET & ENERGY (mirrors MET/energy functions in single-sport.ts)
  // ============================================================================

  /// Running MET from pace in min/mile (mirrors runningMETFromPace).
  static double runningMETFromPace(double paceMinPerMile) {
    final speedMph = 60.0 / paceMinPerMile;
    final speedMPerMin = speedMph * _mphToMPerMin;
    final vo2 = speedMph >= 4.0
        ? 0.2 * speedMPerMin + 3.5
        : 0.1 * speedMPerMin + 3.5;
    return vo2 / 3.5;
  }

  /// Cycling MET from speed (mirrors cyclingMETFromSpeed).
  static double cyclingMETFromSpeed(double speedKph, String terrain) {
    double met;
    if (speedKph <= 16) {
      met = 6.0;
    } else if (speedKph <= 19) {
      met = 8.0;
    } else if (speedKph <= 22) {
      met = 10.0;
    } else if (speedKph <= 25) {
      met = 12.0;
    } else if (speedKph <= 30) {
      met = 14.0;
    } else {
      met = 16.0;
    }
    if (terrain == 'rolling') {
      met *= 1.1;
    } else if (terrain == 'hilly') {
      met *= 1.25;
    }
    return met;
  }

  /// Swimming MET from pace (mirrors swimmingMETFromPace).
  static double swimmingMETFromPace({
    required double pacePer100m,
    required String poolOrOpenWater,
    required double waterTempC,
  }) {
    double met;
    if (pacePer100m >= 180) {
      met = 6.0;
    } else if (pacePer100m >= 150) {
      met = 8.0;
    } else if (pacePer100m >= 120) {
      met = 10.0;
    } else if (pacePer100m >= 90) {
      met = 11.0;
    } else {
      met = 13.0;
    }
    if (poolOrOpenWater == 'open_water') met *= 1.15;
    if (waterTempC < 20) {
      met *= 1.1;
    } else if (waterTempC > 28) {
      met *= 0.95;
    }
    return met;
  }

  /// Gross calories (mirrors calculateGrossCalories).
  static int calculateGrossCalories({
    required double weightKg,
    required double durationMin,
    required double met,
  }) {
    return (met * 3.5 * weightKg / 200.0 * durationMin).round();
  }

  /// Net calories (mirrors calculateNetCalories).
  static int calculateNetCalories({
    required String activityType,
    required double weightKg,
    required double distanceKm,
    double? speedKph,
  }) {
    if (activityType == 'running') {
      return (1.0 * weightKg * distanceKm).round();
    } else if (activityType == 'cycling') {
      final speed = speedKph ?? 25.0;
      double costPerKgKm;
      if (speed <= 20) {
        costPerKgKm = 0.3;
      } else if (speed <= 25) {
        costPerKgKm = 0.35;
      } else if (speed <= 30) {
        costPerKgKm = 0.4;
      } else {
        costPerKgKm = 0.5;
      }
      return (weightKg * distanceKm * costPerKgKm).round();
    } else if (activityType == 'swimming') {
      return (3.5 * weightKg * distanceKm).round();
    }
    return (1.0 * weightKg * distanceKm).round();
  }

  // ============================================================================
  // SPORT ENTRY POINTS — produce a Map<String, dynamic> matching the edge
  // function's `macros` response object so _parseMacroTargets() can parse it
  // without modification.
  // ============================================================================

  /// Backward-compatible entry point used by the legacy [MacroRepository]
  /// offline path. Parses the string/unit inputs and delegates to the
  /// server-parity [calculateRunningMacros], returning the legacy
  /// `{success, macros}` envelope.
  static Map<String, dynamic> calculateMacros({
    required double weight,
    required String weightUnit,
    required double height, // kept for API compatibility (unused)
    required String heightUnit, // kept for API compatibility (unused)
    required double runDistance,
    required String distanceUnit,
    required String runPace,
    required String paceUnit,
    required double timeBeforeRunMin,
    required String gutTraining,
    required int age, // kept for API compatibility (unused)
    required String gender, // kept for API compatibility (unused)
    bool isFasted = false,
  }) {
    final weightKg = weightUnit.toLowerCase() == 'kg'
        ? weight
        : weight * 0.45359237;
    final distanceMiles = distanceUnit.toLowerCase().startsWith('k')
        ? runDistance / _miToKm
        : runDistance;
    final paceMinPerMile = _parsePaceToMinPerMile(runPace, paceUnit);
    final macros = calculateRunningMacros(
      weightKg: weightKg,
      distanceMiles: distanceMiles,
      paceMinPerMile: paceMinPerMile,
      hoursBefore: timeBeforeRunMin / 60.0,
      isFasted: isFasted,
      gutTraining: gutTraining,
    );
    return {'success': true, 'macros': macros};
  }

  /// Parse a pace string (`"MM:SS"` or decimal minutes) plus its unit into
  /// minutes-per-mile.
  static double _parsePaceToMinPerMile(String pace, String unit) {
    double minutes;
    if (pace.contains(':')) {
      final parts = pace.split(':');
      minutes =
          (double.tryParse(parts[0].trim()) ?? 0) +
          (double.tryParse(parts.length > 1 ? parts[1].trim() : '0') ?? 0) /
              60.0;
    } else {
      minutes = double.tryParse(pace.trim()) ?? 0;
    }
    // min/km → min/mile
    if (unit.toLowerCase().contains('km')) minutes *= _miToKm;
    return minutes;
  }

  /// Offline fallback for running macro calculation.
  static Map<String, dynamic> calculateRunningMacros({
    required double weightKg,
    required double distanceMiles,
    required double paceMinPerMile,
    required double hoursBefore,
    required bool isFasted,
    required String gutTraining,
    String sweatRateCategory = 'medium',
    String sweatSodiumCat = 'average',
    double? tempC,
    double? humidityPct,
    bool isIndoor = false,
    double? knownSweatRateMlPerHour,
    double? knownSodiumConcMgPerL,
  }) {
    const activityType = 'running';
    final distanceKm = distanceMiles * _miToKm;
    final durationMin = distanceMiles * paceMinPerMile;
    final durationH = durationMin / 60.0;
    final speedKph = (60.0 / paceMinPerMile) * _miToKm;
    final met = runningMETFromPace(paceMinPerMile);

    return _buildMacrosMap(
      activityType: activityType,
      weightKg: weightKg,
      distanceKm: distanceKm,
      durationMin: durationMin,
      durationH: durationH,
      met: met,
      speedKph: speedKph,
      hoursBefore: hoursBefore,
      isFasted: isFasted,
      gutTraining: gutTraining,
      sweatRateCategory: sweatRateCategory,
      sweatSodiumCat: sweatSodiumCat,
      tempC: tempC,
      humidityPct: humidityPct,
      isIndoor: isIndoor,
      knownSweatRateMlPerHour: knownSweatRateMlPerHour,
      knownSodiumConcMgPerL: knownSodiumConcMgPerL,
    );
  }

  /// Offline fallback for cycling macro calculation.
  static Map<String, dynamic> calculateCyclingMacros({
    required double weightKg,
    required double distanceMiles,
    required double speedMph,
    required String terrain,
    required double hoursBefore,
    required bool isFasted,
    required String gutTraining,
    String sweatRateCategory = 'medium',
    String sweatSodiumCat = 'average',
    double? tempC,
    double? humidityPct,
    bool isIndoor = false,
    double? knownSweatRateMlPerHour,
    double? knownSodiumConcMgPerL,
  }) {
    const activityType = 'cycling';
    final distanceKm = distanceMiles * _miToKm;
    final speedKph = speedMph * _miToKm;
    final durationMin = (distanceMiles / speedMph) * 60.0;
    final durationH = durationMin / 60.0;
    final met = cyclingMETFromSpeed(speedKph, terrain);

    return _buildMacrosMap(
      activityType: activityType,
      weightKg: weightKg,
      distanceKm: distanceKm,
      durationMin: durationMin,
      durationH: durationH,
      met: met,
      speedKph: speedKph,
      hoursBefore: hoursBefore,
      isFasted: isFasted,
      gutTraining: gutTraining,
      sweatRateCategory: sweatRateCategory,
      sweatSodiumCat: sweatSodiumCat,
      tempC: tempC,
      humidityPct: humidityPct,
      isIndoor: isIndoor,
      knownSweatRateMlPerHour: knownSweatRateMlPerHour,
      knownSodiumConcMgPerL: knownSodiumConcMgPerL,
    );
  }

  /// Offline fallback for swimming macro calculation.
  static Map<String, dynamic> calculateSwimmingMacros({
    required double weightKg,
    required int distanceMeters,
    required int paceSecondsper100m,
    required String poolOrOpenWater,
    required double hoursBefore,
    String sweatRateCategory = 'medium',
    String sweatSodiumCat = 'average',
    double waterTempC = 26.0,
    double? knownSweatRateMlPerHour,
    double? knownSodiumConcMgPerL,
  }) {
    const activityType = 'swimming';
    final distanceKm = distanceMeters / 1000.0;
    final durationMin = (distanceMeters / 100.0) * paceSecondsper100m / 60.0;
    final durationH = durationMin / 60.0;
    final met = swimmingMETFromPace(
      pacePer100m: paceSecondsper100m.toDouble(),
      poolOrOpenWater: poolOrOpenWater,
      waterTempC: waterTempC,
    );
    // Pool = indoor for sweat-rate purposes
    final isIndoor = poolOrOpenWater == 'pool';

    return _buildMacrosMap(
      activityType: activityType,
      weightKg: weightKg,
      distanceKm: distanceKm,
      durationMin: durationMin,
      durationH: durationH,
      met: met,
      speedKph: null,
      // Swimming doesn't support fasted in the service, always false
      hoursBefore: hoursBefore,
      isFasted: false,
      gutTraining: 'moderate',
      sweatRateCategory: sweatRateCategory,
      sweatSodiumCat: sweatSodiumCat,
      tempC: null,
      humidityPct: null,
      isIndoor: isIndoor,
      knownSweatRateMlPerHour: knownSweatRateMlPerHour,
      knownSodiumConcMgPerL: knownSodiumConcMgPerL,
    );
  }

  // ============================================================================
  // SHARED BUILD HELPER
  // ============================================================================

  static Map<String, dynamic> _buildMacrosMap({
    required String activityType,
    required double weightKg,
    required double distanceKm,
    required double durationMin,
    required double durationH,
    required double met,
    required double? speedKph,
    required double hoursBefore,
    required bool isFasted,
    required String gutTraining,
    required String sweatRateCategory,
    required String sweatSodiumCat,
    required double? tempC,
    required double? humidityPct,
    required bool isIndoor,
    required double? knownSweatRateMlPerHour,
    required double? knownSodiumConcMgPerL,
  }) {
    // Pre-workout targets
    final pre = calculatePreWorkoutTargets(
      weightKg: weightKg,
      hoursBefore: hoursBefore,
      isFasted: isFasted,
      sweatSodiumCat: sweatSodiumCat,
      // Lets the carbohydrate plan band claim Thomas 2016's cited [1,4] g/kg
      // when the session is >= 60 min. SSOT: pre-workout-carbs.md v2.
      workoutDurationMin: durationMin,
    );

    // During-workout carbs
    final duringCarbs = calculateDuringWorkoutCarbRate(
      durationMin: durationMin,
      activityType: activityType,
      gutTraining: gutTraining,
    );
    final duringCarbRate = (duringCarbs['rate_gph'] as num).toDouble();
    final duringCarbTotal = (duringCarbRate * durationH).round();

    // During-workout hydration
    final duringHydration = calculateDuringWorkoutHydration(
      durationMin: durationMin,
      weightKg: weightKg,
      sweatRateCategory: sweatRateCategory,
      sweatSodiumCat: sweatSodiumCat,
      tempC: tempC,
      humidityPct: humidityPct,
      isIndoor: isIndoor,
      sport: activityType,
      knownSweatRateMlPerHour: knownSweatRateMlPerHour,
      knownSodiumConcMgPerL: knownSodiumConcMgPerL,
    );

    // Post-workout
    final postCarbs = calculatePostWorkoutCarbs(
      weightKg: weightKg,
      durationH: durationH,
      isFasted: isFasted,
    );
    final postProtein = calculatePostWorkoutProtein(
      weightKg: weightKg,
      durationH: durationH,
      isFasted: isFasted,
    );
    final postFat = calculatePostWorkoutFat(weightKg);
    final postHydration = calculatePostWorkoutHydration(
      durationH: durationH,
      actualSweatRateLph: duringHydration.sweatRateLph,
      sodiumConcMgPerL: duringHydration.sodiumConcMgPerL,
      duringHydrationMl: duringHydration.hydrationTotalMl,
    );

    // Energy
    final caloriesGross = calculateGrossCalories(
      weightKg: weightKg,
      durationMin: durationMin,
      met: met,
    );
    final caloriesNet = calculateNetCalories(
      activityType: activityType,
      weightKg: weightKg,
      distanceKm: distanceKm,
      speedKph: speedKph,
    );

    // Low/high bands
    final bandLow = duringCarbs['band_low'] as int;
    final bandHigh = duringCarbs['band_high'] as int;
    final postCarbsLow = (postCarbs * 0.8).round();
    final postCarbsHigh = (postCarbs * 1.2).round();
    final postProteinLow = (postProtein * 0.8).round();
    final postProteinHigh = (postProtein * 1.2).round();
    final postSodium = postHydration['sodium_mg']!;
    final postSodiumLow = (postSodium * 0.7).round();
    final postSodiumHigh = (postSodium * 1.3).round();
    final postWater = postHydration['hydration_ml']!;
    final postWaterLow = (postWater * 0.8).round();
    final postWaterHigh = (postWater * 1.2).round();

    final durSodiumRate = duringHydration.sodiumRateMgph;
    final durSodium = (durSodiumRate * durationH).round();
    final durWaterRate = duringHydration.hydrationRateMlph;
    final durWater = (durWaterRate * durationH).round();

    final massNormRate = weightKg > 0
        ? (duringCarbRate / weightKg * 100).round() / 100.0
        : 0.0;

    return {
      'success': true,
      'algorithm_version': 'v4_offline',
      'activity_type': activityType,
      // Duration & distance
      'duration_min': (durationMin * 100).round() / 100.0,
      'duration_h': (durationH * 10000).round() / 10000.0,
      'distance_km': (distanceKm * 1000).round() / 1000.0,
      // Energy
      'calories_gross_kcal': caloriesGross,
      'calories_net_kcal': caloriesNet,
      'MET': (met * 100).round() / 100.0,
      // Pre-workout
      'pre_run_carbs_g': pre['carbs_g'],
      'pre_run_carbs_low_g': pre['carbs_low_g'],
      'pre_run_carbs_high_g': pre['carbs_high_g'],
      'pre_run_protein_g': pre['protein_g'],
      'pre_run_protein_low_g': pre['protein_low_g'],
      'pre_run_protein_high_g': pre['protein_high_g'],
      'pre_run_fat_g': pre['fat_g'],
      'pre_run_sodium_mg': pre['sodium_mg'],
      'pre_run_sodium_low_mg': pre['sodium_low_mg'],
      'pre_run_sodium_high_mg': pre['sodium_high_mg'],
      'pre_run_water_ml': pre['water_ml'],
      'pre_run_water_low_ml': pre['water_low_ml'],
      'pre_run_water_high_ml': pre['water_high_ml'],
      'pre_run_meal_type': pre['meal_type'],
      'pre_run_carbs_rule': 'offline_fallback',
      'pre_run_hydration_tier': null,
      'pre_run_selections': null,
      // During-workout
      'during_rate_g_per_h': duringCarbRate,
      'during_total_g': duringCarbTotal,
      'during_band_low_g_per_h': bandLow,
      'during_band_high_g_per_h': bandHigh,
      'during_raw_band_low_g_per_h': duringCarbs['raw_band_low'],
      'during_raw_band_high_g_per_h': duringCarbs['raw_band_high'],
      'during_gut_multiplier': duringCarbs['gut_multiplier'],
      'during_sport_ceiling_g_per_h': duringCarbs['sport_ceiling'],
      'during_sodium_rate_mg_per_h': durSodiumRate,
      'during_sodium_total_mg': durSodium,
      'during_sodium_low_mg': (durSodium * 0.8).round(),
      'during_sodium_high_mg': (durSodium * 1.2).round(),
      'during_water_rate_ml_per_h': durWaterRate,
      'during_water_total_ml': durWater,
      'during_water_low_ml': (durWater * 0.85).round(),
      'during_water_high_ml': (durWater * 1.15).round(),
      'during_mass_norm_rate_g_per_h': massNormRate,
      'during_abs_clamp_range_g_per_h': [bandLow, bandHigh],
      // Post-workout
      'post_run_carbs_g': postCarbs,
      'post_run_carbs_low_g': postCarbsLow,
      'post_run_carbs_high_g': postCarbsHigh,
      'post_run_protein_g': postProtein,
      'post_run_protein_low_g': postProteinLow,
      'post_run_protein_high_g': postProteinHigh,
      'post_run_fat_g': postFat,
      'post_run_sodium_mg': postSodium,
      'post_run_sodium_low_mg': postSodiumLow,
      'post_run_sodium_high_mg': postSodiumHigh,
      'post_run_water_ml': postWater,
      'post_run_water_low_ml': postWaterLow,
      'post_run_water_high_ml': postWaterHigh,
      // Hydration detail
      'sweat_rate_lph': duringHydration.sweatRateLph,
      'sodium_conc_mg_per_l': duringHydration.sodiumConcMgPerL,
      'effective_sweat_rate_lph': duringHydration.effectiveSweatRateLph,
      'replacement_pct': duringHydration.replacementPct,
      'floor_ml_hr': duringHydration.floorMlHr,
      'ceiling_ml_hr': duringHydration.ceilingMlHr,
      'safety_flags': duringHydration.safetyFlags,
      'is_tested': duringHydration.isTested,
      'is_tested_sodium': false,
      'temp_c': tempC,
      'humidity_pct': humidityPct,
      'is_indoor': isIndoor,
    };
  }

  static double _clamp(double value, double min, double max) {
    return math.max(min, math.min(max, value));
  }

  /// Convert ml to fl oz for display
  static double mlToFlOz(double ml) => ml * _mlToFlOz;

  /// Convert fl oz to ml for storage
  static double flOzToMl(double flOz) => flOz / _mlToFlOz;

  // ===========================================================================
  // HYDRATION & SODIUM — Dart mirror of generate-macros-v4 edge function
  //
  // Sources:
  //   supabase/functions/_shared/nutrition/sweat-hydration.ts
  //   supabase/functions/generate-macros-v4/single-sport.ts
  //   supabase/functions/generate-macros-v4/pre-workout.ts
  //   supabase/functions/generate-macros-v4/brick-workout.ts
  //
  // These functions are pure / dependency-free (no HTTP, no Riverpod, no async).
  // They mirror the edge-function algorithm exactly so offline output matches
  // what the server would return.
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // Constants (mirrors sweat-hydration.ts)
  // ---------------------------------------------------------------------------

  static const Map<String, double> _sweatRateLph = {
    'light': 0.90,
    'medium': 1.28,
    'heavy': 1.66,
  };

  static const Map<String, int> _sodiumConcMgPerL = {
    'low': 650,
    'average': 825,
    'medium': 825, // legacy alias for 'average'
    'high': 1000,
  };

  static const double swimmingSweatModifier = 0.4;

  static const double _tempBaselineC = 22.0;
  static const double _tempCoefficient = 0.04;
  static const double _tempMultMin = 0.50;
  static const double _tempMultMax = 1.80;

  static const double _humidityBaselinePct = 50.0;
  static const double _humidityCoefficient = 0.002;
  static const double _humidityMultMin = 1.0;
  static const double _humidityMultMax = 1.10;

  static const double _indoorMultiplier = 1.30;

  static const double _overallRateMin = 0.3;
  static const double _overallRateMax = 3.0;

  static const Map<String, int> _giCeilingMlHr = {
    'running': 800,
    'cycling': 1200,
    'swimming': 0,
  };

  static const int _transitionFluidMl = 300;

  // ---------------------------------------------------------------------------
  // Base lookups
  // ---------------------------------------------------------------------------

  /// Base sweat rate for a sweater category.
  /// LIGHT=0.90, MEDIUM=1.28, HEAVY=1.66 L/hr. Defaults to MEDIUM.
  static double baseSweatRateFromCategory(String category) {
    return _sweatRateLph[category.toLowerCase()] ?? _sweatRateLph['medium']!;
  }

  /// Sodium concentration for a loss category.
  /// LOW=650, AVERAGE=825 (medium alias), HIGH=1000 mg/L. Defaults to average.
  static int sodiumConcentrationFromCategory(String category) {
    return _sodiumConcMgPerL[category.toLowerCase()] ??
        _sodiumConcMgPerL['average']!;
  }

  // ---------------------------------------------------------------------------
  // Replacement % by total workout duration
  // ---------------------------------------------------------------------------

  /// Duration-scaled replacement percentage lookup.
  ///
  /// <60 min  → 0.30
  /// 60–90    → 0.50  (inclusive of 90, per Example 2)
  /// 91–150   → 0.60
  /// 151–239  → 0.70
  /// 240+     → 0.80
  static double replacementPctForDuration(double durationMin) {
    if (durationMin < 60) return 0.30;
    if (durationMin <= 90) return 0.50;
    if (durationMin <= 150) return 0.60;
    if (durationMin < 240) return 0.70;
    return 0.80;
  }

  // ---------------------------------------------------------------------------
  // Effective sweat rate
  // ---------------------------------------------------------------------------

  /// Calculate effective sweat rate in L/hr, mirroring the edge function.
  ///
  /// Formula:
  ///   base = knownSweatRateMlPerHour/1000  OR  sweatRateLph[baseCategory]
  ///   tempMult     = clamp(1.0 + (tempC - 22)*0.04, 0.50, 1.80)
  ///   humidityMult = clamp(1.0 + max(0, h-50)*0.002, 1.0, 1.10)
  ///   indoorMult   = 1.30 if isIndoor else 1.0
  ///   effective    = round3dp(clamp(base * tempMult * humidityMult * indoorMult, 0.3, 3.0))
  static double calculateActualSweatRate({
    required String baseCategory,
    double? tempC,
    double? humidityPct,
    bool isIndoor = false,
    double? knownSweatRateMlPerHour,
  }) {
    // Base rate: known rate overrides category base (but still gets multipliers)
    final baseRate = knownSweatRateMlPerHour != null
        ? knownSweatRateMlPerHour / 1000.0
        : baseSweatRateFromCategory(baseCategory);

    // Temperature multiplier (baseline 22°C)
    final t = tempC ?? _tempBaselineC;
    final rawTempMult = 1.0 + (t - _tempBaselineC) * _tempCoefficient;
    final tempMult = _clamp(rawTempMult, _tempMultMin, _tempMultMax);

    // Humidity multiplier (baseline 50%)
    final h = humidityPct ?? _humidityBaselinePct;
    final rawHumidityMult =
        1.0 + math.max(0.0, h - _humidityBaselinePct) * _humidityCoefficient;
    final humidityMult = _clamp(
      rawHumidityMult,
      _humidityMultMin,
      _humidityMultMax,
    );

    // Indoor multiplier
    final indoorMult = isIndoor ? _indoorMultiplier : 1.0;

    // Effective rate with overall clamp, rounded to 3 decimal places
    final rawRate = baseRate * tempMult * humidityMult * indoorMult;
    final clamped = _clamp(rawRate, _overallRateMin, _overallRateMax);
    return (clamped * 1000).round() / 1000.0;
  }

  // ---------------------------------------------------------------------------
  // During-workout hydration (single-sport)
  // ---------------------------------------------------------------------------

  /// Result from [calculateDuringWorkoutHydration].
  static const String _shortWorkoutGateFlag =
      'No structured hydration plan needed.';
  static const String _ceilingLtFloorFlag =
      'Even at maximum intake, you will exceed 2% BW loss.';

  /// Calculate during-workout hydration targets for a single-sport session.
  ///
  /// Returns a record with fields matching the edge-function result shape.
  static DuringWorkoutHydrationResult calculateDuringWorkoutHydration({
    required double durationMin,
    required double weightKg,
    required String sweatRateCategory,
    required String sweatSodiumCat,
    double? tempC,
    double? humidityPct,
    bool isIndoor = false,
    String sport = 'running',
    double? knownSweatRateMlPerHour,
    double? knownSodiumConcMgPerL,
  }) {
    final safetyFlags = <String>[];

    // Effective sweat rate
    final effectiveSweatRateLph = calculateActualSweatRate(
      baseCategory: sweatRateCategory,
      tempC: tempC,
      humidityPct: humidityPct,
      isIndoor: isIndoor,
      knownSweatRateMlPerHour: knownSweatRateMlPerHour,
    );
    final effectiveSweatRateMlph = effectiveSweatRateLph * 1000.0;

    // Sodium concentration
    final sodiumConcMgPerL =
        knownSodiumConcMgPerL?.round() ??
        sodiumConcentrationFromCategory(sweatSodiumCat);

    // Swim-only: no drinking possible
    if (sport.toLowerCase() == 'swimming') {
      return DuringWorkoutHydrationResult(
        hydrationRateMlph: 0,
        sodiumRateMgph: 0,
        hydrationTotalMl: 0,
        sodiumTotalMg: 0,
        sweatRateLph: effectiveSweatRateLph,
        sodiumConcMgPerL: sodiumConcMgPerL,
        effectiveSweatRateLph: effectiveSweatRateLph,
        replacementPct: 0,
        floorMlHr: 0,
        ceilingMlHr: 0,
        safetyFlags: const [],
        isTested: knownSweatRateMlPerHour != null,
      );
    }

    final durationH = durationMin / 60.0;
    final giCeiling = _giCeilingMlHr[sport.toLowerCase()] ?? 800;

    // Ceiling = min(sport GI, 100% sweat rate)
    final ceilingMlHr = math.min(giCeiling, effectiveSweatRateMlph).round();

    // Replacement % by total duration
    final replacementPct = replacementPctForDuration(durationMin);

    // Short-workout gate: duration < 60 AND temp < 30
    final temp = tempC ?? 22.0;
    final gateTriggered = durationMin < 60 && temp < 30.0;

    if (gateTriggered) {
      final recommended = (effectiveSweatRateMlph * replacementPct).round();
      safetyFlags.add(_shortWorkoutGateFlag);
      final sodiumRate = ((recommended / 1000.0) * sodiumConcMgPerL).round();
      return DuringWorkoutHydrationResult(
        hydrationRateMlph: recommended,
        sodiumRateMgph: sodiumRate,
        hydrationTotalMl: (recommended * durationH).round(),
        sodiumTotalMg: (sodiumRate * durationH).round(),
        sweatRateLph: effectiveSweatRateLph,
        sodiumConcMgPerL: sodiumConcMgPerL,
        effectiveSweatRateLph: effectiveSweatRateLph,
        replacementPct: replacementPct,
        floorMlHr: 0,
        ceilingMlHr: ceilingMlHr,
        safetyFlags: List.unmodifiable(safetyFlags),
        isTested: knownSweatRateMlPerHour != null,
      );
    }

    // Standard path
    // Total sweat loss over duration
    final totalLossMl = effectiveSweatRateMlph * durationH;

    // 2% BW floor
    final maxDeficitMl = weightKg * 1000.0 * 0.02;
    final rawFloorMlHr = (totalLossMl - maxDeficitMl) / durationH;
    final floorMlHr = math.max(0.0, rawFloorMlHr).round();

    // Pct-based recommendation
    final pctBasedMlHr = (effectiveSweatRateMlph * replacementPct).round();

    // Apply floor
    int recommendedMlHr = math.max(pctBasedMlHr, floorMlHr);

    // Apply ceiling
    if (ceilingMlHr < floorMlHr) {
      safetyFlags.add(_ceilingLtFloorFlag);
    }
    recommendedMlHr = math.min(recommendedMlHr, ceilingMlHr);

    // Safety check: realized deficit
    final totalIntakeMl = recommendedMlHr * durationH;
    final netDeficitMl = totalLossMl - totalIntakeMl;
    if (weightKg > 0) {
      final deficitPct = netDeficitMl / (weightKg * 1000.0);
      if (deficitPct > 0.03) {
        final pctStr = (deficitPct * 100).toStringAsFixed(1);
        safetyFlags.add('Significant dehydration expected (>$pctStr% BW).');
      }
    }

    final sodiumRateMgph = ((recommendedMlHr / 1000.0) * sodiumConcMgPerL)
        .round();

    return DuringWorkoutHydrationResult(
      hydrationRateMlph: recommendedMlHr,
      sodiumRateMgph: sodiumRateMgph,
      // Spec: hydrationTotalMl = fluid rate × duration (was incorrectly
      // using sodiumRateMgph, producing mg-in-ml unit confusion).
      hydrationTotalMl: (recommendedMlHr * durationH).round(),
      sodiumTotalMg: (sodiumRateMgph * durationH).round(),
      sweatRateLph: effectiveSweatRateLph,
      sodiumConcMgPerL: sodiumConcMgPerL,
      effectiveSweatRateLph: effectiveSweatRateLph,
      replacementPct: replacementPct,
      floorMlHr: floorMlHr,
      ceilingMlHr: ceilingMlHr,
      safetyFlags: List.unmodifiable(safetyFlags),
      isTested: knownSweatRateMlPerHour != null,
    );
  }

  // ---------------------------------------------------------------------------
  // PRE-WORKOUT HYDRATION — SSOT: docs/ssot/spec/fueling/pre-workout-hydration.md v6
  // PRE-WORKOUT SODIUM    — SSOT: docs/ssot/spec/fueling/pre-workout-sodium.md    v3
  // ---------------------------------------------------------------------------

  /// ml — start-line anchor. SSOT: pre-workout-hydration.md v6 —
  /// `A0_ML = 250.0` (Jeukendrup & Gleeson 2019 p. 493).
  static const double a0Ml = 250.0;

  /// ml — gastric volume tolerated at t = 0. SSOT: pre-workout-hydration.md v6 —
  /// `R_CEILING = 400.0` (NATA 2017: "Maintaining 400 to 600 mL of fluid in the
  /// stomach optimizes gastric emptying").
  static const double rCeiling = 400.0;

  /// per minute — first-order gastric emptying coefficient, 3.2 h⁻¹.
  /// SSOT: pre-workout-hydration.md v6 — `K = 3.2 / 60` (Mudie 2014).
  ///
  /// **MUST be computed**, never written as the rounded literal 0.0533333 —
  /// the spec says so explicitly and the clearance vectors are pinned to 1e-3 ml.
  static const double k = 3.2 / 60;

  /// min — lower edge of Thomas 2016's fluid window.
  /// SSOT: pre-workout-hydration.md v6 — `T_REF = 120.0`.
  ///
  /// Numerically equal to [tierMealMin] for an **unrelated** reason (this one is
  /// epistemic — the edge of a position statement's authority; that one is
  /// physiological). Pinned equal by [assertCrossSpecPin], never derived from it.
  static const double tRef = 120.0;

  /// ml/kg — dark-urine correction target. SSOT: pre-workout-hydration.md v6 —
  /// `TOPUP_ML_KG = 4.0` (ACSM 2007, midpoint of its 3–5 band).
  static const double topUpMlKg = 4.0;

  /// ml/kg — top of ACSM 2007's 3–5 correction band.
  /// SSOT: pre-workout-hydration.md v6 — `TOPUP_HIGH_ML_KG = 5.0`.
  static const double topUpHighMlKg = 5.0;

  /// ml/kg — ACSM 2007's own maximum for the same protocol (5–7 + 3–5).
  /// SSOT: pre-workout-hydration.md v6 — `PLAN_CAP_ML_KG = 12.0`.
  static const double planCapMlKg = 12.0;

  /// ml/kg — Thomas 2016's cited band, verbatim ("5-10 ml/kg BW").
  /// SSOT: pre-workout-hydration.md v6.
  static const double citedFluidLowMlKg = 5.0;
  static const double citedFluidHighMlKg = 10.0;

  /// ml/kg — the target above [tRef]: the midpoint of Thomas's band.
  /// SSOT: pre-workout-hydration.md v6 (Mealvana rule — no source names a point
  /// inside the range).
  static const double citedFluidTargetMlKg = 7.5;

  /// °C — assumed ambient when `tempC` is null.
  /// SSOT: pre-workout-hydration.md v6 inputs table.
  static const double defaultTempC = 22.0;

  /// °C — the gate's heat carve-out. SSOT: pre-workout-hydration.md v6 —
  /// gate fires when `workoutDurationMin < 60 AND tempC < 30`.
  static const double gateTempC = 30.0;

  /// min — the gate's duration carve-out (Mealvana proxy for NATA 2017's
  /// recreational carve-out). SSOT: pre-workout-hydration.md v6.
  static const double gateWorkoutMin = 60.0;

  /// Cross-spec pin — SSOT: pre-workout-hydration.md v6 invariant 10 and
  /// pre-workout-carbs.md v2 invariant 10.
  ///
  /// [tRef] and [tierMealMin] are two different constants that happen to hold
  /// the same value for two unrelated reasons. Either may move without the
  /// other; what may NOT happen is one silently drifting while code assumes
  /// they agree. Enforced three ways, loudest first:
  ///   1. compile time — the const [_crossSpecPin] below,
  ///   2. debug runtime — `assert` at the head of both pre-workout functions,
  ///   3. release runtime — [assertCrossSpecPin], for the conformance harness.
  static const bool _crossSpecPinHolds = tRef == tierMealMin;
  static const String _crossSpecPinMessage =
      'CROSS-SPEC PIN BROKEN: pre-workout-hydration.T_REF ($tRef) != '
      'pre-workout-carbs.TIER_MEAL_MIN ($tierMealMin). '
      'See pre-workout-hydration.md v6 invariant 10.';

  /// Build-time guard. A const constructor whose `assert` fails is a
  /// **compile-time error**, so a divergence here breaks the build rather than
  /// shipping two disagreeing tier boundaries.
  // ignore: unused_field
  static const _CrossSpecPin _crossSpecPin = _CrossSpecPin(tRef, tierMealMin);

  /// Runtime form of the cross-spec pin, for conformance runners (which run in
  /// release mode where `assert` is stripped). Throws [StateError] on
  /// divergence.
  static void assertCrossSpecPin() {
    if (!_crossSpecPinHolds) throw StateError(_crossSpecPinMessage);
  }

  /// Pre-workout hydration plan, and the (deliberately absent) pre-workout
  /// sodium target.
  ///
  /// SSOT: `docs/ssot/spec/fueling/pre-workout-hydration.md` v6 (RATIFIED,
  /// Xuan 2026-08-04) and `docs/ssot/spec/fueling/pre-workout-sodium.md` v3
  /// (RATIFIED, Xuan 2026-08-03). Conformance vectors:
  /// `docs/ssot/vectors/fueling/pre-workout-{hydration,sodium}.json`.
  ///
  /// Exact doubles — **this function never rounds.**
  ///
  /// Three things a reader is most likely to get wrong, all load-bearing:
  ///   * **The gate returns `null`, not `0`.** `null` means "no statement is
  ///     made"; below [tRef] `fluidLowMl` is `0.0`, which means "nothing is
  ///     required". A consumer that conflates them misreports both.
  ///   * **Sodium is `null` on every path.** Mealvana sets no pre-workout sodium
  ///     target — a deliberate decision, not an omission. A `0` is a failure.
  ///   * **`hydrationCheck` never touches the band.** It moves `fluidMl` only,
  ///     and only inside the `t >= T_REF` branch, because the band is shown from
  ///     entry (t−240) while the check is answered at t−120.
  ///
  /// [timeBeforeWorkoutMin] is the lead time **captured at plan generation and
  /// frozen** — it is not re-read from the clock. A recompute triggered by a
  /// late-arriving [hydrationCheck] MUST reuse the original value.
  static PreWorkoutHydrationResult calculatePreWorkoutHydration({
    required double bodyWeightKg,
    required double workoutDurationMin,
    required double timeBeforeWorkoutMin,
    double? tempC,
    HydrationCheck hydrationCheck = HydrationCheck.unknown,
  }) {
    assert(_crossSpecPinHolds, _crossSpecPinMessage);

    final temp = tempC ?? defaultTempC;

    // Gate — ours (a NATA 2017 recreational-carve-out proxy), NOT part of
    // Thomas 2016's scope. Returns nulls and an empty tier list, never zeros.
    if (workoutDurationMin < gateWorkoutMin && temp < gateTempC) {
      return const PreWorkoutHydrationResult(
        gateTriggered: true,
        fluidMl: null,
        fluidLowMl: null,
        fluidHighMl: null,
        tiers: <PreWorkoutFluidTier>[],
        regime: 'gated',
        targetBasis: 'none',
        hydrationCheckUsed: null,
        sodiumMg: null,
        sodiumLowMg: null,
        sodiumHighMg: null,
      );
    }

    final t = math.max(timeBeforeWorkoutMin, 0.0);
    final bw = bodyWeightKg;

    // A0 guard: binds only below 33.3 kg, where the flat 250 ml anchor would
    // otherwise exceed the cited target itself.
    final a0 = math.min(a0Ml, citedFluidTargetMlKg * bw);

    /// Linear taper from the start-line anchor up to the cited target at T_REF.
    /// Mealvana design choice — no source covers the final two hours.
    double f(double x) =>
        a0 + (citedFluidTargetMlKg * bw - a0) * math.min(x, tRef) / tRef;

    final double fluidMl;
    final double fluidLowMl;
    final double fluidHighMl;
    final String regime;
    final String targetBasis;
    final String hydrationCheckUsed;
    final List<PreWorkoutFluidTier> tiers;

    if (t >= tRef) {
      // `unknown` normalises to `pale` HERE AND ONLY HERE (PROVISIONAL —
      // pre-workout-hydration.md v6 notes §2.5). Below T_REF the raw value is
      // echoed back untouched, because it changes nothing there.
      final effectiveCheck = hydrationCheck == HydrationCheck.unknown
          ? HydrationCheck.pale
          : hydrationCheck;
      hydrationCheckUsed = effectiveCheck.wireValue;

      final mealMl = citedFluidTargetMlKg * bw; // consumed in [t, 120]
      // ACSM 2007 places the correction at ~2 h, i.e. in the snack window.
      final topUpMl = effectiveCheck == HydrationCheck.dark
          ? topUpMlKg * bw
          : 0.0;
      final snackMl = topUpMl;
      const topOffMl = 0.0; // the gel chase is carbohydrate delivery, not this

      fluidMl = mealMl + snackMl;
      fluidLowMl = citedFluidLowMlKg * bw;
      // NOT conditioned on hydrationCheck (invariant 8b): this states what the
      // protocol can sanction, not what this athlete's reading turned out to be.
      fluidHighMl = math.min(
        citedFluidTargetMlKg * bw + topUpHighMlKg * bw,
        planCapMlKg * bw,
      );
      regime = 'cited';
      targetBasis = 'evidenced_band';
      tiers = <PreWorkoutFluidTier>[
        PreWorkoutFluidTier(tier: 'meal', fluidMl: mealMl),
        PreWorkoutFluidTier(tier: 'snack', fluidMl: snackMl),
        const PreWorkoutFluidTier(tier: 'top_off', fluidMl: topOffMl),
      ];
    } else {
      // Everything below T_REF is a Mealvana design choice in a region no
      // source addresses. hydrationCheck is advisory copy here, not a code
      // path — the athlete has drunk nothing, so there is nothing to evaluate.
      hydrationCheckUsed = hydrationCheck.wireValue;

      final double snackMl;
      final double topOffMl;
      if (t >= tierTopOffMax) {
        snackMl = f(t);
        topOffMl = 0.0;
      } else {
        snackMl = 0.0;
        topOffMl = f(t);
      }

      final ceiling = rCeiling * math.exp(k * t);
      fluidMl = snackMl + topOffMl;
      fluidLowMl = 0.0; // 0, NOT null — "nothing is required"
      fluidHighMl = math.min(citedFluidHighMlKg * bw, ceiling);
      regime = ceiling < citedFluidHighMlKg * bw
          ? 'clearance_bound'
          : 'extrapolated';
      targetBasis = 'design_choice';
      tiers = <PreWorkoutFluidTier>[
        if (t >= tierTopOffMax)
          PreWorkoutFluidTier(tier: 'snack', fluidMl: snackMl),
        PreWorkoutFluidTier(tier: 'top_off', fluidMl: topOffMl),
      ];
    }

    return PreWorkoutHydrationResult(
      gateTriggered: false,
      fluidMl: fluidMl,
      fluidLowMl: fluidLowMl,
      fluidHighMl: fluidHighMl,
      tiers: List.unmodifiable(tiers),
      regime: regime,
      targetBasis: targetBasis,
      hydrationCheckUsed: hydrationCheckUsed,
      // Sodium v3: Mealvana sets NO pre-workout sodium target, in any tier and
      // on the gate path. null, never 0 — 0 would be the recommendation
      // "consume no sodium", which is not what is meant.
      sodiumMg: null,
      sodiumLowMg: null,
      sodiumHighMg: null,
    );
  }

  // ---------------------------------------------------------------------------
  // Brick hydration (multi-segment)
  // ---------------------------------------------------------------------------

  /// Segment descriptor for brick hydration calculation.
  /// [sport] is 'running' | 'cycling' | 'swimming'.
  /// [order] is the 0-based segment index (matches segment.order from the API).

  /// Calculate multi-segment (brick) hydration targets per spec.
  ///
  /// Mirrors calculateBrickHydration from brick-workout.ts exactly.
  static BrickHydrationResult calculateBrickHydration({
    required double weightKg,
    required List<BrickSegmentInput> segments,
    required String sweatRateCategory,
    required String sweatSodiumCat,
    double? tempC,
    double? humidityPct,
    bool isIndoor = false,
    double? knownSweatRateMlPerHour,
    double? knownSodiumConcMgPerL,
  }) {
    final safetyFlags = <String>[];

    // Effective sweat rate
    final effectiveSweatRateLph = calculateActualSweatRate(
      baseCategory: sweatRateCategory,
      tempC: tempC,
      humidityPct: humidityPct,
      isIndoor: isIndoor,
      knownSweatRateMlPerHour: knownSweatRateMlPerHour,
    );
    final effectiveSweatRateMlph = effectiveSweatRateLph * 1000.0;

    // Sodium concentration
    final sodiumConcMgPerL =
        knownSodiumConcMgPerL?.round() ??
        sodiumConcentrationFromCategory(sweatSodiumCat);

    // Total duration → replacement %
    final totalDurationMin = segments.fold<double>(
      0.0,
      (s, seg) => s + seg.durationMin,
    );
    final replacementPct = replacementPctForDuration(totalDurationMin);

    // Per-segment sweat losses (swim uses 0.4× modifier)
    double totalLossMl = 0.0;
    for (final seg in segments) {
      final durationH = seg.durationMin / 60.0;
      if (seg.sport.toLowerCase() == 'swimming') {
        totalLossMl +=
            effectiveSweatRateMlph * swimmingSweatModifier * durationH;
      } else {
        totalLossMl += effectiveSweatRateMlph * durationH;
      }
    }

    // Detect transitions — identity is POSITIONAL `T{i+1}` per brick.md R8
    // (fixes D-008: the sport-pair naming collided on repeat legs and made a
    // plain bike→run brick emit T2); the sport pair survives as a display
    // label only.
    final transitions = <_BrickTransitionRaw>[];
    for (int i = 0; i < segments.length - 1; i++) {
      transitions.add(
        _BrickTransitionRaw(
          index: i,
          name: 'T${i + 1}',
          afterSport: segments[i].sport.toLowerCase(),
          beforeSport: segments[i + 1].sport.toLowerCase(),
        ),
      );
    }

    final transitionCount = transitions.length;
    final totalTransitionFluidMl = transitionCount * _transitionFluidMl;

    // Required total based on replacement %
    final requiredTotalMl = totalLossMl * replacementPct;

    // Floor: covers deficit down to 2% BW
    final maxDeficitMl = weightKg * 1000.0 * 0.02;
    final rawFloorTotalMl = totalLossMl - maxDeficitMl;
    final floorTotalMl = math.max(0.0, rawFloorTotalMl);

    // Subtract transition intake
    final remainingRequired = math.max(
      0.0,
      requiredTotalMl - totalTransitionFluidMl,
    );
    final remainingFloor = math.max(0.0, floorTotalMl - totalTransitionFluidMl);

    // Drinkable hours: non-swim segments only
    final drinkableMinutes = segments
        .where((s) => s.sport.toLowerCase() != 'swimming')
        .fold<double>(0.0, (s, seg) => s + seg.durationMin);
    final drinkableHours = drinkableMinutes / 60.0;

    // Recommended ml/hr across drinkable segments
    int recommendedMlHr = drinkableHours > 0
        ? (remainingRequired / drinkableHours).round()
        : 0;
    final floorMlHr = drinkableHours > 0
        ? (remainingFloor / drinkableHours).round()
        : 0;

    // Apply floor
    recommendedMlHr = math.max(recommendedMlHr, floorMlHr);

    // Per-segment ceilings
    final segmentCeilings = <String, int>{
      'cycling': math
          .min(_giCeilingMlHr['cycling']!, effectiveSweatRateMlph)
          .round(),
      'running': math
          .min(_giCeilingMlHr['running']!, effectiveSweatRateMlph)
          .round(),
      'swimming': 0,
    };

    // Assign initial rates per segment, capped by segment ceiling
    final segmentRates = <int, int>{};
    for (final seg in segments) {
      final sport = seg.sport.toLowerCase();
      if (sport == 'swimming') {
        segmentRates[seg.order] = 0;
      } else {
        final ceiling = segmentCeilings[sport] ?? _giCeilingMlHr['running']!;
        segmentRates[seg.order] = math.min(recommendedMlHr, ceiling);
      }
    }

    // Run→bike redistribution
    final nonSwimSegs = segments
        .where((s) => s.sport.toLowerCase() != 'swimming')
        .toList();

    var redistributionFailed = false;
    for (final seg in nonSwimSegs) {
      if (seg.sport.toLowerCase() != 'running') continue;

      final runCeiling = segmentCeilings['running']!;
      if (floorMlHr > runCeiling) {
        // Shortfall from run
        final runDurationH = seg.durationMin / 60.0;
        final shortfallTotal = (floorMlHr - runCeiling) * runDurationH;

        // Distribute to bike segments
        final bikeSegs = nonSwimSegs
            .where((s) => s.sport.toLowerCase() == 'cycling')
            .toList();
        final totalBikeHours = bikeSegs.fold<double>(
          0.0,
          (s, b) => s + b.durationMin / 60.0,
        );

        if (totalBikeHours > 0) {
          final addPerHr = shortfallTotal / totalBikeHours;
          final bikeCeiling = segmentCeilings['cycling']!;
          for (final bikeSeg in bikeSegs) {
            final current = segmentRates[bikeSeg.order]!.toDouble();
            final newRate = math.min(
              current + addPerHr,
              bikeCeiling.toDouble(),
            );
            segmentRates[bikeSeg.order] = newRate.round();
          }
        }

        // Cap run at ceiling
        segmentRates[seg.order] = runCeiling;

        // Check if shortfall remains (compute actual intake)
        final actualBikeIntake = nonSwimSegs
            .where((s) => s.sport.toLowerCase() == 'cycling')
            .fold<double>(
              0.0,
              (s, b) => s + segmentRates[b.order]! * b.durationMin / 60.0,
            );
        final actualRunIntake = segmentRates[seg.order]! * runDurationH;
        final totalActualIntake =
            actualBikeIntake + actualRunIntake + totalTransitionFluidMl;
        final netDeficit = totalLossMl - totalActualIntake;

        if (netDeficit > maxDeficitMl) {
          redistributionFailed = true;
        }
      }
    }

    if (redistributionFailed) {
      safetyFlags.add(
        'Even at maximum intake on all segments, you will exceed 2% BW loss.',
      );
    }

    // Total intake safety check
    double totalIntakeMl = totalTransitionFluidMl.toDouble();
    for (final seg in segments) {
      final rate = segmentRates[seg.order] ?? 0;
      totalIntakeMl += rate * seg.durationMin / 60.0;
    }
    final netDeficitMl = totalLossMl - totalIntakeMl;
    if (weightKg > 0 && netDeficitMl > 0) {
      final deficitPct = netDeficitMl / (weightKg * 1000.0);
      if (deficitPct > 0.03) {
        final pctStr = (deficitPct * 100).toStringAsFixed(1);
        safetyFlags.add('Significant dehydration expected (>$pctStr% BW).');
      }
    }

    // Build result segments
    final resultSegments = segments.map((seg) {
      final rate = segmentRates[seg.order] ?? 0;
      final sport = seg.sport.toLowerCase();
      final ceiling = segmentCeilings[sport] ?? 0;
      final sodiumRate = ((rate / 1000.0) * sodiumConcMgPerL).round();
      final segEffectiveLph = sport == 'swimming'
          ? effectiveSweatRateLph * swimmingSweatModifier
          : effectiveSweatRateLph;
      return BrickHydrationSegmentResult(
        sport: seg.sport,
        order: seg.order,
        durationMin: seg.durationMin,
        hydrationRateMlph: rate,
        sodiumRateMgph: sodiumRate,
        ceilingMlHr: ceiling,
        floorMlHr: sport == 'swimming' ? 0 : floorMlHr,
        effectiveSweatRateLph: ((segEffectiveLph * 1000).round() / 1000.0),
      );
    }).toList();

    // Build result transitions — spec §6.4: sodium_mg = (fluid_ml / 1000) ×
    // sodium_conc_mg_per_l. The phantom 0.3 factor was a ~3.3× under-estimate
    // and has been removed to match the edge function.
    final resultTransitions = transitions.map((t) {
      final sodiumMg = ((_transitionFluidMl / 1000.0) * sodiumConcMgPerL)
          .round();
      return BrickHydrationTransitionResult(
        transitionName: t.name,
        sportPair: '${t.afterSport}→${t.beforeSport}',
        afterSport: t.afterSport,
        beforeSport: t.beforeSport,
        waterMl: _transitionFluidMl,
        sodiumMg: sodiumMg,
      );
    }).toList();

    return BrickHydrationResult(
      segments: resultSegments,
      transitions: resultTransitions,
      safetyFlags: List.unmodifiable(safetyFlags),
      effectiveSweatRateLph: effectiveSweatRateLph,
      sodiumConcMgPerL: sodiumConcMgPerL,
      replacementPct: replacementPct,
      isTested: knownSweatRateMlPerHour != null,
    );
  }
}

// =============================================================================
// Result value types
// =============================================================================

/// Result from [OfflineMacroCalculator.calculateDuringWorkoutHydration].
class DuringWorkoutHydrationResult {
  const DuringWorkoutHydrationResult({
    required this.hydrationRateMlph,
    required this.sodiumRateMgph,
    required this.hydrationTotalMl,
    required this.sodiumTotalMg,
    required this.sweatRateLph,
    required this.sodiumConcMgPerL,
    required this.effectiveSweatRateLph,
    required this.replacementPct,
    required this.floorMlHr,
    required this.ceilingMlHr,
    required this.safetyFlags,
    required this.isTested,
  });

  final int hydrationRateMlph;
  final int sodiumRateMgph;
  final int hydrationTotalMl;
  final int sodiumTotalMg;
  final double sweatRateLph;
  final int sodiumConcMgPerL;
  final double effectiveSweatRateLph;
  final double replacementPct;
  final int floorMlHr;
  final int ceilingMlHr;
  final List<String> safetyFlags;
  final bool isTested;
}

// -----------------------------------------------------------------------------
// PRE-WORKOUT value types
// SSOT: docs/ssot/spec/fueling/pre-workout-hydration.md v6
//       docs/ssot/spec/fueling/pre-workout-carbs.md      v2
//       docs/ssot/spec/fueling/pre-workout-sodium.md     v3
// -----------------------------------------------------------------------------

/// The athlete's urine-colour self-check.
///
/// SSOT: pre-workout-hydration.md v6. Collected by the consumer inline with the
/// snack-window fluid card, never scheduled by the engine, and it only affects
/// output when `timeBeforeWorkoutMin >= T_REF`.
///
/// `unknown` is treated as `pale` — a **PROVISIONAL** Mealvana design choice —
/// and only inside that branch.
enum HydrationCheck {
  pale('pale'),
  dark('dark'),
  unknown('unknown');

  const HydrationCheck(this.wireValue);

  /// The string form used on the wire and echoed in
  /// [PreWorkoutHydrationResult.hydrationCheckUsed].
  final String wireValue;

  /// Parse a wire value, defaulting to [HydrationCheck.unknown] for anything
  /// unrecognised (including null) — the spec's own default.
  static HydrationCheck fromWire(String? value) {
    for (final check in HydrationCheck.values) {
      if (check.wireValue == value) return check;
    }
    return HydrationCheck.unknown;
  }
}

/// One fluid feeding occasion within the pre-workout plan.
///
/// SSOT: pre-workout-hydration.md v6 "Tier integration". The tier is a
/// **presentation container** — `targetBasis` is per-nutrient and per-minute and
/// MUST NOT be derived from it.
class PreWorkoutFluidTier {
  const PreWorkoutFluidTier({required this.tier, required this.fluidMl});

  /// `'meal'` · `'snack'` · `'top_off'`.
  final String tier;

  /// Exact ml for this occasion. Never rounded by the engine.
  final double fluidMl;
}

/// Result from [OfflineMacroCalculator.calculatePreWorkoutHydration].
///
/// SSOT: pre-workout-hydration.md v6 (fluid) + pre-workout-sodium.md v3
/// (sodium). The v1 integer `tier` field is **RETIRED** and is not emitted.
class PreWorkoutHydrationResult {
  const PreWorkoutHydrationResult({
    required this.gateTriggered,
    required this.fluidMl,
    required this.fluidLowMl,
    required this.fluidHighMl,
    required this.tiers,
    required this.regime,
    required this.targetBasis,
    required this.hydrationCheckUsed,
    required this.sodiumMg,
    required this.sodiumLowMg,
    required this.sodiumHighMg,
  });

  /// True when the short-and-cool carve-out fired
  /// (`workoutDurationMin < 60 AND tempC < 30`).
  final bool gateTriggered;

  /// Exact ml — the **plan total** across all tiers. `null` on the gate path,
  /// where no statement is made at all.
  final double? fluidMl;

  /// Exact ml — the permissible range.
  ///
  /// `fluidLowMl` is `0.0` below `T_REF` ("nothing is required"), and `null`
  /// only on the gate path ("no statement is made"). These are different
  /// things; a consumer that conflates them will misreport both.
  final double? fluidLowMl;
  final double? fluidHighMl;

  /// Ordered furthest-out first. Never null; empty on the gate path.
  final List<PreWorkoutFluidTier> tiers;

  /// `'cited'` · `'extrapolated'` · `'clearance_bound'` · `'gated'`.
  final String regime;

  /// `'evidenced_band'` · `'design_choice'` · `'none'`.
  final String targetBasis;

  /// Echo of the check value actually applied: the normalised value above
  /// `T_REF` (`unknown` → `pale`), the raw value below it, `null` on the gate
  /// path.
  final String? hydrationCheckUsed;

  /// **Always `null`.** SSOT: pre-workout-sodium.md v3 — Mealvana sets no
  /// pre-workout sodium target, in any tier and on the gate path. A `0` in any
  /// of these three is a conformance failure, not a pass: zero would be the
  /// recommendation "consume no sodium".
  final int? sodiumMg;
  final int? sodiumLowMg;
  final int? sodiumHighMg;
}

/// One carbohydrate feeding occasion within the pre-workout plan.
///
/// SSOT: pre-workout-carbs.md v2.
class PreWorkoutCarbTier {
  const PreWorkoutCarbTier({
    required this.tier,
    required this.carbsG,
    required this.rangeLowG,
    required this.rangeHighG,
    required this.composition,
  });

  /// `'meal'` · `'snack'` · `'top_off'`.
  final String tier;

  /// Exact grams — the aim for this occasion.
  final double carbsG;

  /// The **food-match window**: ±12.5 % of this feeding's portion. Distinct in
  /// job from the plan-level `carbsLowG`/`carbsHighG` — this one says how
  /// loosely one feeding may be matched, not what the plan may be.
  final double rangeLowG;
  final double rangeHighG;

  /// Mirrors [tier]. The value set and its rules are owned by
  /// `docs/ssot/spec/fueling/pre-workout-food-composition.md`; this spec only
  /// carries the tag through.
  final String composition;
}

/// Result from [OfflineMacroCalculator.calculatePreWorkoutCarbs].
///
/// SSOT: pre-workout-carbs.md v2. No integer `tier`, ever.
class PreWorkoutCarbResult {
  const PreWorkoutCarbResult({
    required this.carbsG,
    required this.carbsLowG,
    required this.carbsHighG,
    required this.tiers,
    required this.targetBasis,
  });

  /// Exact grams — the **plan total** across all tiers, not one feeding.
  final double carbsG;

  /// Plan-level permissible range: Thomas's cited `[1, 4] g/kg` inside the
  /// window, ±12.5 % of the total outside it.
  final double carbsLowG;
  final double carbsHighG;

  /// Ordered furthest-out first. Empty (not null) when `isFasted`.
  ///
  /// **Load-bearing**: a consumer reading only [carbsG] will present a plan
  /// total as a single feeding — exactly the misreading v1 encouraged.
  final List<PreWorkoutCarbTier> tiers;

  /// `'evidenced_band'` · `'design_choice'` · `'none'`.
  final String targetBasis;
}

/// Compile-time carrier for the hydration↔carbs tier-boundary pin.
///
/// A `const` invocation whose `assert` fails is a compile-time error, so
/// `T_REF` drifting away from `TIER_MEAL_MIN` breaks the build rather than
/// silently shipping two disagreeing tier boundaries.
/// SSOT: pre-workout-hydration.md v6 invariant 10; pre-workout-carbs.md v2
/// invariant 10.
class _CrossSpecPin {
  const _CrossSpecPin(double tRef, double tierMealMin)
    : assert(
        tRef == tierMealMin,
        'CROSS-SPEC PIN BROKEN: pre-workout-hydration.T_REF != '
        'pre-workout-carbs.TIER_MEAL_MIN. See invariant 10 in both specs.',
      );
}

/// Segment input for [OfflineMacroCalculator.calculateBrickHydration].
class BrickSegmentInput {
  const BrickSegmentInput({
    required this.sport,
    required this.order,
    required this.durationMin,
  });

  final String sport;
  final int order;
  final double durationMin;
}

/// Per-segment output from [OfflineMacroCalculator.calculateBrickHydration].
class BrickHydrationSegmentResult {
  const BrickHydrationSegmentResult({
    required this.sport,
    required this.order,
    required this.durationMin,
    required this.hydrationRateMlph,
    required this.sodiumRateMgph,
    required this.ceilingMlHr,
    required this.floorMlHr,
    required this.effectiveSweatRateLph,
  });

  final String sport;
  final int order;
  final double durationMin;
  final int hydrationRateMlph;
  final int sodiumRateMgph;
  final int ceilingMlHr;
  final int floorMlHr;
  final double effectiveSweatRateLph;
}

/// Segment descriptor for [OfflineMacroCalculator.calculateTransitionCarbDose].
class TransitionDoseSegment {
  const TransitionDoseSegment({required this.sport, required this.durationMin});

  /// 'running' | 'cycling' | 'swimming'.
  final String sport;
  final double durationMin;
}

/// Result of [OfflineMacroCalculator.calculateTransitionCarbDose] —
/// transition-nutrition.md T-1. [doseG] is whole grams (T-4); the band is
/// `[0, 30]` on every transition.
class TransitionCarbDoseResult {
  const TransitionCarbDoseResult({
    required this.doseG,
    required this.bandLowG,
    required this.bandHighG,
    required this.rateGPerH,
    required this.effectiveGapMin,
    required this.transitionMin,
  });

  final int doseG;
  final int bandLowG;
  final int bandHighG;
  final double rateGPerH;
  final double effectiveGapMin;
  final double transitionMin;
}

/// Per-transition output from [OfflineMacroCalculator.calculateBrickHydration].
class BrickHydrationTransitionResult {
  const BrickHydrationTransitionResult({
    required this.transitionName,
    required this.sportPair,
    required this.afterSport,
    required this.beforeSport,
    required this.waterMl,
    required this.sodiumMg,
  });

  /// Positional identity `T{i+1}` — brick.md R8 (fixes D-008).
  final String transitionName;

  /// Display label only, no identity (brick.md R8), e.g. 'cycling→running'.
  final String sportPair;
  final String afterSport;
  final String beforeSport;
  final int waterMl;
  final int sodiumMg;
}

/// Top-level result from [OfflineMacroCalculator.calculateBrickHydration].
class BrickHydrationResult {
  const BrickHydrationResult({
    required this.segments,
    required this.transitions,
    required this.safetyFlags,
    required this.effectiveSweatRateLph,
    required this.sodiumConcMgPerL,
    required this.replacementPct,
    required this.isTested,
  });

  final List<BrickHydrationSegmentResult> segments;
  final List<BrickHydrationTransitionResult> transitions;
  final List<String> safetyFlags;
  final double effectiveSweatRateLph;
  final int sodiumConcMgPerL;
  final double replacementPct;
  final bool isTested;
}

// Internal helper — not part of public API
class _BrickTransitionRaw {
  const _BrickTransitionRaw({
    required this.index,
    required this.name,
    required this.afterSport,
    required this.beforeSport,
  });

  final int index;
  final String name;
  final String afterSport;
  final String beforeSport;
}
