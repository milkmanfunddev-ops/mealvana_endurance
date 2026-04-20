import '../../../shared/domain/activity_type.dart';
import '../domain/carb_transparency_data.dart';
import '../domain/macro_targets.dart';
import '../domain/resolved_during_target.dart';

/// Structured explanation data for a single macro within a phase
class MacroExplanation {
  const MacroExplanation({
    required this.macroName,
    required this.value,
    required this.unit,
    this.rangeLow,
    this.rangeHigh,
    required this.formulaText,
    required this.rangeRationale,
    this.actualValue,
  });

  final String macroName;
  final String value;
  final String unit;
  final String? rangeLow;
  final String? rangeHigh;
  final String formulaText;
  final String rangeRationale;

  /// The actual food total (e.g. "194") when foods are provided
  final String? actualValue;

  /// Header: "Carbohydrates: 194g" (actual) or "Carbohydrates: 191g" (target)
  String get displayHeader {
    final displayVal = actualValue ?? value;
    return '$macroName: $displayVal$unit';
  }

  /// Sub-header shown when actuals are present: "Target: 191g (range: 167-215g)"
  String? get displaySubHeader {
    if (actualValue == null) return null;
    final rangeStr = (rangeLow != null && rangeHigh != null)
        ? ' (range: $rangeLow-$rangeHigh$unit)'
        : '';
    return 'Target: $value$unit$rangeStr';
  }
}

/// Phase types for explanation context
enum ExplanationPhase { before, during, after, transition1, transition2 }

/// Generates personalized explanation text for each phase/macro combination.
///
/// Pure Dart class - no Riverpod, no async. Takes macro targets and user data
/// and returns structured explanation data derived from algorithm-v4.md.
class MacroExplanationService {
  const MacroExplanationService();

  /// Get the display title for the explanation sheet
  String getSheetTitle(ExplanationPhase phase, String? sportLabel) {
    final sport = sportLabel ?? 'Run';
    switch (phase) {
      case ExplanationPhase.before:
        return 'How We Calculate Your Before $sport Targets';
      case ExplanationPhase.during:
        return 'How We Calculate Your During $sport Targets';
      case ExplanationPhase.after:
        return 'How We Calculate Your After $sport Targets';
      case ExplanationPhase.transition1:
        return 'How We Calculate Your Transition 1 Targets';
      case ExplanationPhase.transition2:
        return 'How We Calculate Your Transition 2 Targets';
    }
  }

  /// Generate explanations for all macros in a given phase.
  ///
  /// [actuals] - optional map of actual food totals keyed by macro name
  /// (e.g. {'carbs': 194, 'protein': 25, 'sodium': 450, 'fluids': 600})
  List<MacroExplanation> getExplanations({
    required ExplanationPhase phase,
    required MacroTargets macroTargets,
    required double bodyWeightKg,
    bool useImperial = false,
    Map<String, int>? actuals,
    BrickSegmentMacroTarget? brickSegment,
  }) {
    switch (phase) {
      case ExplanationPhase.before:
        return _beforeExplanations(
          macroTargets,
          bodyWeightKg,
          useImperial,
          actuals,
        );
      case ExplanationPhase.during:
        return _duringExplanations(
          macroTargets,
          bodyWeightKg,
          useImperial,
          actuals,
          brickSegment: brickSegment,
        );
      case ExplanationPhase.after:
        return _afterExplanations(
          macroTargets,
          bodyWeightKg,
          useImperial,
          actuals,
        );
      case ExplanationPhase.transition1:
        return _transitionExplanations(1, actuals);
      case ExplanationPhase.transition2:
        return _transitionExplanations(2, actuals);
    }
  }

  /// Sport-specific carb ceiling for during phase (g/hr)
  int _sportCarbCeiling(ActivityType sport) {
    switch (sport) {
      case ActivityType.running:
        return 70;
      case ActivityType.cycling:
        return 120;
      case ActivityType.swimming:
        return 0;
      case ActivityType.triathlon:
      case ActivityType.duathlon:
      case ActivityType.multisport:
      case ActivityType.brick:
        return 70; // brick/multi-sport segments use per-segment sport
    }
  }

  String _sportLabel(ActivityType sport) {
    switch (sport) {
      case ActivityType.running:
        return 'running';
      case ActivityType.cycling:
        return 'cycling';
      case ActivityType.swimming:
        return 'swimming';
      case ActivityType.triathlon:
        return 'triathlon';
      case ActivityType.duathlon:
        return 'duathlon';
      case ActivityType.multisport:
        return 'multisport';
      case ActivityType.brick:
        return 'brick';
    }
  }

  // ── Before Phase ────────────────────────────────────────────────────

  List<MacroExplanation> _beforeExplanations(
    MacroTargets mt,
    double weightKg,
    bool useImperial,
    Map<String, int>? actuals,
  ) {
    final pre = mt.preRun;
    final hoursBeforeEst = weightKg > 0
        ? (pre.carbsG / weightKg).clamp(0.5, 4.0)
        : 3.0;
    final carbPerKg = hoursBeforeEst;
    final wt = weightKg.round();

    // Determine meal type from hours_before estimate
    final mealType = hoursBeforeEst >= 2.5
        ? 'full meal'
        : (hoursBeforeEst >= 1.0 ? 'snack' : 'top-up');

    final explanations = <MacroExplanation>[];

    // Carbs — same formula for all sports
    explanations.add(
      MacroExplanation(
        macroName: 'Carbohydrates',
        value: '${pre.carbsG.round()}',
        unit: 'g',
        rangeLow: pre.carbsLowG?.round().toString(),
        rangeHigh: pre.carbsHighG?.round().toString(),
        actualValue: actuals != null ? '${actuals['carbs'] ?? 0}' : null,
        formulaText:
            'Your pre-workout carb target scales with your body weight '
            'and how far out you eat before your activity.\n\n'
            'Formula:  weight  x  hours_before g/kg\n'
            '${wt}kg  x  ${carbPerKg.toStringAsFixed(1)} g/kg  =  ${pre.carbsG.round()}g\n\n'
            'Rate: 1 g/kg per hour before workout '
            '(min 0.5, max 4.0 g/kg).\n'
            'Range: target +/- 12.5%.',
        rangeRationale:
            'Your range of '
            '${pre.carbsLowG?.round() ?? ""}–${pre.carbsHighG?.round() ?? ""}g '
            'gives you flexibility to hit your goal with real food portions.',
      ),
    );

    // Fluids (Before: Carbs, Fluids, Sodium — no Protein)
    final fluidsVal = useImperial
        ? pre.fluidsFlOz.round()
        : pre.fluidsMl.round();
    final fluidsUnit = useImperial ? 'oz' : 'mL';
    final fluidsMlPerKg = mealType == 'full meal'
        ? 6.5
        : (mealType == 'snack' ? 5.5 : 0.0);
    explanations.add(
      MacroExplanation(
        macroName: 'Fluids',
        value: '$fluidsVal',
        unit: fluidsUnit,
        rangeLow: useImperial
            ? (pre.fluidsLowMl != null
                  ? (pre.fluidsLowMl! * 0.033814).round().toString()
                  : null)
            : pre.fluidsLowMl?.round().toString(),
        rangeHigh: useImperial
            ? (pre.fluidsHighMl != null
                  ? (pre.fluidsHighMl! * 0.033814).round().toString()
                  : null)
            : pre.fluidsHighMl?.round().toString(),
        actualValue: actuals != null
            ? '${useImperial ? ((actuals['fluids'] ?? 0) * 0.033814).round() : actuals['fluids'] ?? 0}'
            : null,
        formulaText: mealType == 'top-up'
            ? 'A fixed 250mL (about 8oz) tops off your hydration in the '
                  'final minutes before your workout.\n\n'
                  'Formula:  fixed 250 mL (top-up window)'
            : 'Your pre-workout fluid target is based on your body weight '
                  'and $mealType timing.\n\n'
                  'Formula:  weight  x  $fluidsMlPerKg mL/kg\n'
                  '${wt}kg  x  $fluidsMlPerKg mL/kg  =  ${pre.fluidsMl.round()}mL\n\n'
                  'Range: 50%–150% of target.',
        rangeRationale: 'Adjust based on how thirsty you feel and the weather.',
      ),
    );

    // Sodium
    explanations.add(
      MacroExplanation(
        macroName: 'Sodium',
        value: '${pre.sodiumMg.round()}',
        unit: 'mg',
        rangeLow: pre.sodiumLowMg?.round().toString(),
        rangeHigh: pre.sodiumHighMg?.round().toString(),
        actualValue: actuals != null ? '${actuals['sodium'] ?? 0}' : null,
        formulaText:
            'Sodium helps your body absorb and retain the fluids you drink '
            'before your workout.\n\n'
            'Formula:  base_sodium (by sweat level)  +  environment_bump\n'
            'Your target of ${pre.sodiumMg.round()}mg is based on your '
            'sweat sodium level and $mealType timing.\n\n'
            'Base sodium: low=300, medium=450, high=600 mg.\n'
            'Hot weather adds +100mg.',
        rangeRationale:
            'The wide range '
            '(${pre.sodiumLowMg?.round() ?? 0}–${pre.sodiumHighMg?.round() ?? 0}mg) '
            'is intentional — sodium needs vary a lot between individuals.',
      ),
    );

    return explanations;
  }

  // ── During Phase ────────────────────────────────────────────────────

  List<MacroExplanation> _duringExplanations(
    MacroTargets mt,
    double weightKg,
    bool useImperial,
    Map<String, int>? actuals, {
    BrickSegmentMacroTarget? brickSegment,
  }) {
    final during = mt.duringRun;
    final durationH = mt.metrics.durationH;
    final durationMin = mt.metrics.durationMin;
    final sport = mt.activityType;
    final sportName = _sportLabel(sport);
    final ceiling = _sportCarbCeiling(sport);

    // Duration band from the stored abs_clamp_range
    final bandLow = during.absClampRangeGPerH.isNotEmpty
        ? during.absClampRangeGPerH[0].round()
        : 0;
    final bandHigh = during.absClampRangeGPerH.length > 1
        ? during.absClampRangeGPerH[1].round()
        : 60;

    final explanations = <MacroExplanation>[];

    // Swimming: no during nutrition
    if (sport == ActivityType.swimming) {
      explanations.add(
        MacroExplanation(
          macroName: 'Carbohydrates',
          value: '0',
          unit: 'g',
          actualValue: actuals != null ? '${actuals['carbs'] ?? 0}' : null,
          formulaText:
              'No carb fueling is possible during swimming — '
              'you can\'t eat or drink while in the water.\n\n'
              'Swimming carb ceiling: 0 g/hr.',
          rangeRationale: 'Focus on pre- and post-workout nutrition instead.',
        ),
      );
      return explanations;
    }

    // Use per-segment values from brickSegment when available,
    // otherwise fall back to total during values.
    final carbValue = brickSegment != null
        ? brickSegment.carbsG.round()
        : during.carbTotalG.round();
    final carbRangeLow = brickSegment != null
        ? brickSegment.carbsLowG?.round().toString()
        : during.carbsLowG?.round().toString();
    final carbRangeHigh = brickSegment != null
        ? brickSegment.carbsHighG?.round().toString()
        : during.carbsHighG?.round().toString();

    // Segment-specific formula details for bricks
    final String carbFormula;
    if (brickSegment != null) {
      final segSport = brickSegment.sport;
      final segDurationMin = brickSegment.durationMinutes;
      final segDurationH = segDurationMin / 60.0;
      final segRate = brickSegment.carbsRateGPerH ?? 0;
      final segCeiling = brickSegment.sportCeilingGPerH?.round() ?? ceiling;
      final segBandLow = brickSegment.rawBandLowGPerH?.round() ?? bandLow;
      final segBandHigh = brickSegment.rawBandHighGPerH?.round() ?? bandHigh;
      final penalty = brickSegment.brickPenalty;
      final penaltyNote = penalty != null && penalty < 1.0
          ? '\n4. Brick fatigue penalty: ${(penalty * 100).round()}% '
                '(running after cycling)\n'
          : '';
      final ceilingNote2 = segRate > segCeiling
          ? '\nSport ceiling ($segSport): $segCeiling g/hr — rate capped.'
          : '';

      final totalEventMin = mt.metrics.durationMin.round();
      carbFormula =
          'This is a brick workout — carb targets are calculated '
          'per segment based on total event time.\n\n'
          '1. Total event time (${totalEventMin}min) → band:  $segBandLow–$segBandHigh g/hr\n'
          '2. Gut training multiplier scales the band\n'
          '3. Midpoint of scaled band  =  ${segRate.round()} g/hr'
          '$ceilingNote2$penaltyNote\n'
          'Formula:  rate  x  segment duration\n'
          '${segRate.round()} g/hr  x  ${segDurationH.toStringAsFixed(1)}h  =  ${carbValue}g\n\n'
          'Segment: $segSport (${segDurationMin}min)';
    } else {
      final ceilingNote = during.carbRateGPerH > ceiling
          ? '\nSport ceiling ($sportName): $ceiling g/hr — rate capped.'
          : '';
      carbFormula =
          'Your fueling rate is determined by your activity duration, '
          'gut training level, and sport.\n\n'
          '1. Duration band (${durationMin.round()} min):  $bandLow–$bandHigh g/hr\n'
          '2. Gut training multiplier scales the band\n'
          '3. Midpoint of scaled band  =  ${during.carbRateGPerH.round()} g/hr'
          '$ceilingNote\n\n'
          'Formula:  rate  x  duration\n'
          '${during.carbRateGPerH.round()} g/hr  x  ${durationH.toStringAsFixed(1)}h  =  ${during.carbTotalG.round()}g\n\n'
          'Duration bands: <60min: 0–30, 60–90min: 30–60, '
          '90–150min: 45–60, 2.5–4hr: 60–90, >4hr: 80–100 g/hr.\n'
          'Gut multipliers: low=0.7x, moderate=1.0x, high=1.2x.\n'
          'Sport ceilings: running=$ceiling g/hr, cycling=120 g/hr.';
    }

    explanations.add(
      MacroExplanation(
        macroName: 'Carbohydrates',
        value: '$carbValue',
        unit: 'g',
        rangeLow: carbRangeLow,
        rangeHigh: carbRangeHigh,
        actualValue: actuals != null ? '${actuals['carbs'] ?? 0}' : null,
        formulaText: carbFormula,
        rangeRationale:
            'The range reflects individual differences in gut '
            'tolerance and carb absorption rates.',
      ),
    );

    // Fluids — use per-segment values for bricks
    final fluidsValMl = brickSegment != null
        ? brickSegment.waterMl.round()
        : during.fluidTotalMl.round();
    final fluidsVal = useImperial
        ? (fluidsValMl * 0.033814).round()
        : fluidsValMl;
    final fluidsUnit = useImperial ? 'oz' : 'mL';
    final fluidsLowMl = brickSegment?.waterLowMl ?? during.fluidsLowMl;
    final fluidsHighMl = brickSegment?.waterHighMl ?? during.fluidsHighMl;
    explanations.add(
      MacroExplanation(
        macroName: 'Fluids',
        value: '$fluidsVal',
        unit: fluidsUnit,
        rangeLow: useImperial
            ? (fluidsLowMl != null
                  ? (fluidsLowMl * 0.033814).round().toString()
                  : null)
            : fluidsLowMl?.round().toString(),
        rangeHigh: useImperial
            ? (fluidsHighMl != null
                  ? (fluidsHighMl * 0.033814).round().toString()
                  : null)
            : fluidsHighMl?.round().toString(),
        actualValue: actuals != null
            ? '${useImperial ? ((actuals['fluids'] ?? 0) * 0.033814).round() : actuals['fluids'] ?? 0}'
            : null,
        formulaText:
            'We replace about 75% of your sweat losses during activity.\n\n'
            'Formula:  sweat_rate  x  0.75  x  duration\n'
            '${during.fluidRateMlPerH.round()} mL/hr  x  ${(brickSegment != null ? brickSegment.durationMinutes / 60.0 : durationH).toStringAsFixed(1)}h  =  ${fluidsValMl}mL\n\n'
            'Your sweat rate is estimated from your sweat profile and '
            'adjusted for temperature (linear above 20°C).',
        rangeRationale:
            'Replacing 75% of sweat losses prevents dehydration '
            'without risking overhydration.',
      ),
    );

    // Sodium — use per-segment values for bricks
    final sodiumVal = brickSegment != null
        ? brickSegment.sodiumMg.round()
        : during.sodiumTotalMg.round();
    final sodiumLow = brickSegment?.sodiumLowMg ?? during.sodiumLowMg;
    final sodiumHigh = brickSegment?.sodiumHighMg ?? during.sodiumHighMg;
    explanations.add(
      MacroExplanation(
        macroName: 'Sodium',
        value: '$sodiumVal',
        unit: 'mg',
        rangeLow: sodiumLow?.round().toString(),
        rangeHigh: sodiumHigh?.round().toString(),
        actualValue: actuals != null ? '${actuals['sodium'] ?? 0}' : null,
        formulaText:
            'We replace about 60% of your sweat sodium losses.\n\n'
            'Formula:  sweat_rate  x  sodium_conc  x  0.60  x  duration\n'
            '${during.sodiumRateMgPerH.round()} mg/hr  x  ${(brickSegment != null ? brickSegment.durationMinutes / 60.0 : durationH).toStringAsFixed(1)}h  =  ${sodiumVal}mg\n\n'
            'Sodium concentrations by sweat level: '
            'low=550, medium=925, high=1150 mg/L.\n'
            'Rate clamped to 300–1200 mg/hr for safety.',
        rangeRationale:
            'Your body handles the remaining 40% through '
            'normal sodium regulation.',
      ),
    );

    return explanations;
  }

  // ── After Phase ─────────────────────────────────────────────────────

  List<MacroExplanation> _afterExplanations(
    MacroTargets mt,
    double weightKg,
    bool useImperial,
    Map<String, int>? actuals,
  ) {
    final post = mt.postRun;
    final durationH = mt.metrics.durationH;
    final wt = weightKg.round();

    final durationMult = durationH > 2 ? 1.2 : 1.0;
    final carbPerKg = durationMult;

    final explanations = <MacroExplanation>[];

    // Carbs
    final durationNote = durationH > 2
        ? '  (1.2x multiplier for workouts > 2 hours)'
        : '  (1.0x — standard recovery)';
    explanations.add(
      MacroExplanation(
        macroName: 'Carbohydrates',
        value: '${post.carbsG.round()}',
        unit: 'g',
        rangeLow: post.carbsLowG?.round().toString(),
        rangeHigh: post.carbsHighG?.round().toString(),
        actualValue: actuals != null ? '${actuals['carbs'] ?? 0}' : null,
        formulaText:
            'Recovery carbs replenish the glycogen (energy) your muscles '
            'used during your workout.\n\n'
            'Formula:  weight  x  duration_multiplier\n'
            '${wt}kg  x  ${carbPerKg.toStringAsFixed(1)} g/kg  =  ${post.carbsG.round()}g'
            '$durationNote\n\n'
            'Range: target +/- 20%.',
        rangeRationale:
            'Eat within the first hour after your workout for the best recovery.',
      ),
    );

    // Protein (After: Carbs, Protein, Sodium — no Fluids)
    // Duration-tiered protein per kg
    final double proteinPerKg;
    final String durationTierNote;
    if (durationH <= 0.75) {
      proteinPerKg = 0.25;
      durationTierNote = '(≤ 45 min — light recovery)';
    } else if (durationH <= 1.5) {
      proteinPerKg = 0.30;
      durationTierNote = '(45 min–1.5 hr — standard recovery)';
    } else if (durationH <= 2.5) {
      proteinPerKg = 0.35;
      durationTierNote = '(1.5–2.5 hr — elevated recovery)';
    } else {
      proteinPerKg = 0.40;
      durationTierNote = '(> 2.5 hr — maximum recovery)';
    }
    explanations.add(
      MacroExplanation(
        macroName: 'Protein',
        value: '${post.proteinG.round()}',
        unit: 'g',
        rangeLow: post.proteinLowG?.round().toString(),
        rangeHigh: post.proteinHighG?.round().toString(),
        actualValue: actuals != null ? '${actuals['protein'] ?? 0}' : null,
        formulaText:
            'Post-workout protein kickstarts muscle repair and recovery.\n\n'
            'Formula:  weight  x  ${proteinPerKg.toStringAsFixed(2)} g/kg  $durationTierNote\n'
            '${wt}kg  x  ${proteinPerKg.toStringAsFixed(2)} g/kg  =  ${post.proteinG.round()}g\n\n'
            'Aim for 20–40g of high-quality protein (with 2–3g leucine) '
            'like chicken, eggs, Greek yogurt, or a protein shake.',
        rangeRationale:
            'Eat protein within the first hour after exercise '
            'for maximum muscle recovery benefit.',
      ),
    );

    // Sodium
    explanations.add(
      MacroExplanation(
        macroName: 'Sodium',
        value: '${post.sodiumMg.round()}',
        unit: 'mg',
        rangeLow: post.sodiumLowMg?.round().toString(),
        rangeHigh: post.sodiumHighMg?.round().toString(),
        actualValue: actuals != null ? '${actuals['sodium'] ?? 0}' : null,
        formulaText:
            'Sodium in your recovery meal or drink helps your body '
            'hold onto the fluids you\'re drinking.\n\n'
            'Formula:  max(300, min(700, sodium_deficit x 0.5))\n'
            'Target:  ${post.sodiumMg.round()}mg\n\n'
            'We replace 50% of your remaining sodium deficit, '
            'clamped between 300–700mg.',
        rangeRationale:
            'Adding sodium to your recovery fluids significantly '
            'improves rehydration compared to plain water.',
      ),
    );

    return explanations;
  }

  // ── Transition Phase ────────────────────────────────────────────────

  List<MacroExplanation> _transitionExplanations(
    int transitionNumber,
    Map<String, int>? actuals,
  ) {
    final isT1 = transitionNumber == 1;
    final carbs = isT1 ? 20 : 25;
    final sodium = isT1 ? 150 : 100;
    final water = isT1 ? 200 : 150;

    return [
      MacroExplanation(
        macroName: 'Carbohydrates',
        value: '$carbs',
        unit: 'g',
        actualValue: actuals != null ? '${actuals['carbs'] ?? 0}' : null,
        formulaText:
            'Quick, easily-digestible carbs to keep your blood sugar '
            'steady during the ${isT1 ? "first" : "second"} transition.\n\n'
            'Formula:  fixed ${carbs}g (${isT1 ? "T1" : "T2"} transition)\n\n'
            'Transition targets are fixed values based on race distance. '
            'Sprint (<90 min) and short Olympic (<3 hr) use reduced values.',
        rangeRationale:
            'Transitions are quick — these are fixed targets designed '
            'for fast absorption.',
      ),
      MacroExplanation(
        macroName: 'Fluids',
        value: '$water',
        unit: 'mL',
        actualValue: actuals != null ? '${(actuals['fluids'] ?? 0)}' : null,
        formulaText:
            'A small drink during transition to stay on top of '
            'hydration without overfilling your stomach.\n\n'
            'Formula:  fixed ${water}mL (${isT1 ? "T1" : "T2"} transition)',
        rangeRationale:
            'Keep it small — you\'ll resume full hydration '
            'in the next segment.',
      ),
      MacroExplanation(
        macroName: 'Sodium',
        value: '$sodium',
        unit: 'mg',
        actualValue: actuals != null ? '${actuals['sodium'] ?? 0}' : null,
        formulaText:
            'Sodium from your sports drink or gel supports fluid '
            'absorption during the transition.\n\n'
            'Formula:  fixed ${sodium}mg (${isT1 ? "T1" : "T2"} transition)',
        rangeRationale: 'A small amount to bridge between segments.',
      ),
    ];
  }

  // ===========================================================================
  // CARB TRANSPARENCY
  // ===========================================================================

  static const _preWorkoutVideoUrl =
      'https://milkman-dev.s3.us-east-2.amazonaws.com/me_videos/me101_1.1.mp4';

  /// Build structured transparency data for the carbs card.
  ///
  /// Handles: pre-workout, during single-sport, during brick segment, swim.
  CarbTransparencyData getCarbTransparencyData({
    required ExplanationPhase phase,
    required MacroTargets macroTargets,
    required double bodyWeightKg,
    required String gutTrainingLabel,
    required double gutMultiplier,
    double? personalCarbTargetGPerH,
    String? personalTargetSport,
    String? sportLabel,
    BrickSegmentMacroTarget? brickSegment,
    bool isBrick = false,
    ResolvedDuringTarget? resolvedDuringTarget,
  }) {
    if (phase == ExplanationPhase.before) {
      return _preWorkoutTransparency(
        macroTargets: macroTargets,
        bodyWeightKg: bodyWeightKg,
      );
    }

    // Swim zero-state
    final sport = brickSegment?.sport ?? sportLabel?.toLowerCase() ?? 'running';
    if (sport.contains('swim')) {
      return _swimTransparency(brickSegment: brickSegment);
    }

    if (isBrick && brickSegment != null) {
      return _brickSegmentTransparency(
        macroTargets: macroTargets,
        segment: brickSegment,
        gutTrainingLabel: gutTrainingLabel,
        gutMultiplier: gutMultiplier,
        personalCarbTargetGPerH: personalCarbTargetGPerH,
        personalTargetSport: personalTargetSport,
        resolvedDuringTarget: resolvedDuringTarget,
      );
    }

    // Brick transition (T1/T2) — no segment-level formula, just context
    if (isBrick &&
        (phase == ExplanationPhase.transition1 ||
            phase == ExplanationPhase.transition2)) {
      return _brickTransitionTransparency(
        phase: phase,
        macroTargets: macroTargets,
      );
    }

    // Brick during segment without detailed segment data — show generic brick message
    if (isBrick && phase == ExplanationPhase.during) {
      return _brickGenericTransparency(
        macroTargets: macroTargets,
        sportLabel: sportLabel ?? 'Brick',
        gutTrainingLabel: gutTrainingLabel,
        gutMultiplier: gutMultiplier,
        personalCarbTargetGPerH: personalCarbTargetGPerH,
        personalTargetSport: personalTargetSport,
      );
    }

    return _duringSingleSportTransparency(
      macroTargets: macroTargets,
      bodyWeightKg: bodyWeightKg,
      sportLabel: sportLabel ?? 'Run',
      gutTrainingLabel: gutTrainingLabel,
      gutMultiplier: gutMultiplier,
      personalCarbTargetGPerH: personalCarbTargetGPerH,
      personalTargetSport: personalTargetSport,
      resolvedDuringTarget: resolvedDuringTarget,
    );
  }

  // ---------------------------------------------------------------------------
  // PRE-WORKOUT
  // ---------------------------------------------------------------------------

  CarbTransparencyData _preWorkoutTransparency({
    required MacroTargets macroTargets,
    required double bodyWeightKg,
  }) {
    final pre = macroTargets.preRun;
    final targetG = pre.carbsG.round();
    final rangeLow = pre.carbsLowG?.round() ?? (targetG * 0.875).round();
    final rangeHigh = pre.carbsHighG?.round() ?? (targetG * 1.125).round();
    final hoursBefore = bodyWeightKg > 0
        ? (pre.carbsG / bodyWeightKg).clamp(0.5, 4.0)
        : 1.0;
    final hoursBeforeRounded = (hoursBefore * 10).round() / 10;
    final weightRounded = bodyWeightKg.round();

    // Matches pre-workout-carb.html formula-block exactly
    final tldrLines = <FormulaLine>[
      FormulaLine([
        fAccent('body weight '),
        fOp('\u00d7 '),
        fAccent('hours before workout'),
      ]),
      FormulaLine([
        fAccent('${weightRounded}kg '),
        fOp('\u00d7 '),
        fAccent('$hoursBeforeRounded hr '),
        fOp('= '),
        fResult('${targetG}g'),
      ], isResultLine: true),
    ];

    final storySections = <StorySection>[
      const StorySection(
        question: 'Why carbs before a workout?',
        answer:
            'Your muscles run on glycogen \u2014 stored from the carbs you eat. '
            'During exercise your body burns through it continuously. Fuller stores mean '
            '**better performance, focus, and a lower chance of hitting the wall.**',
      ),
      const StorySection(
        question: 'Why does timing change how much you need?',
        answer:
            'Your digestive system needs time to convert food into fuel. Researchers found '
            'athletes benefit from **1\u20134g per kg, consumed 1\u20134 hours before exercise** '
            '\u2014 roughly 1g per hour of lead time.',
        citation:
            'Kerksick et al., 2017 \u2014 ISSN Position Stand: Nutrient Timing',
      ),
      StorySection(
        question: 'Why a range and not one exact number?',
        answer:
            'Real food doesn\'t come in precise grams \u2014 a banana might be 25g or 28g. '
            'The underlying research is also a range because digestion rates and glycogen stores '
            'vary individually. **$rangeLow\u2013${rangeHigh}g reflects that honestly.**',
      ),
      const StorySection(
        question: 'Shouldn\'t a harder workout mean more carbs?',
        answer:
            'Not in the pre-workout calculation. Intensity influences **when** you should eat '
            '\u2014 harder workouts need a longer lead time. The gram target stays at '
            '1g/kg/hr regardless of intensity.',
        citation: 'Kerksick et al., 2017',
      ),
      const StorySection(
        question: '',
        answer: '',
        transparencyNote:
            'The **\u00b112.5% range** is Mealvana\'s design choice to bridge precise math '
            'and real food portioning \u2014 not from research. Everything else here is.',
      ),
    ];

    return CarbTransparencyData(
      phase: 'before',
      tldrBody:
          'The earlier you eat, the more carbs your body can use. We give you '
          '**1g of carbs per kg of body weight** for every hour before your '
          'workout. Simply put, the amount of carbs is determined by your body '
          'weight and the hours before workout.',
      tldrLines: tldrLines,
      tldrTip:
          '**${targetG}g \u00b1 12.5% = $rangeLow\u2013${rangeHigh}g** '
          '\u2014 a practical window for real food portions.',
      storySections: storySections,
      videoUrl: _preWorkoutVideoUrl,
      videoTitle: 'Watch: Pre-Workout Fueling',
      targetGrams: targetG.toDouble(),
      rangeLow: rangeLow.toDouble(),
      rangeHigh: rangeHigh.toDouble(),
      sportLabel: 'Pre-Workout',
    );
  }

  // ---------------------------------------------------------------------------
  // DURING — SINGLE SPORT
  // ---------------------------------------------------------------------------

  CarbTransparencyData _duringSingleSportTransparency({
    required MacroTargets macroTargets,
    required double bodyWeightKg,
    required String sportLabel,
    required String gutTrainingLabel,
    required double gutMultiplier,
    double? personalCarbTargetGPerH,
    String? personalTargetSport,
    ResolvedDuringTarget? resolvedDuringTarget,
  }) {
    final during = macroTargets.duringRun;
    final metrics = macroTargets.metrics;
    final durationMin = metrics.durationMin.round();
    final durationH = metrics.durationH;

    // Raw band from edge function (pre-gut)
    final rawBandLow = during.rawBandLowGPerH ?? during.absClampRangeGPerH[0];
    final rawBandHigh =
        during.rawBandHighGPerH ??
        (during.absClampRangeGPerH.length > 1
            ? during.absClampRangeGPerH[1]
            : during.absClampRangeGPerH[0]);

    // Scaled band (after gut)
    final scaledLow = during.absClampRangeGPerH[0];
    final scaledHigh = during.absClampRangeGPerH.length > 1
        ? during.absClampRangeGPerH[1]
        : during.absClampRangeGPerH[0];

    final midpoint = ((scaledLow + scaledHigh) / 2).round();
    final sportCeiling =
        during.sportCeilingGPerH?.round() ?? _defaultSportCeiling(sportLabel);
    final isCapped = midpoint > sportCeiling;
    final afterCeiling = isCapped ? sportCeiling : midpoint;
    final overrideRate =
        resolvedDuringTarget?.settingsOverrideRateGPerH ??
        personalCarbTargetGPerH;
    final isOverrideApplied = resolvedDuringTarget?.isOverrideApplied ?? false;
    final hasEligiblePersonalTarget = overrideRate != null && durationMin >= 90;
    final shouldApplyOverride =
        isOverrideApplied ||
        (resolvedDuringTarget == null && hasEligiblePersonalTarget);
    final finalRate =
        resolvedDuringTarget?.rateGPerH ??
        (shouldApplyOverride
            ? (overrideRate ?? afterCeiling.toDouble())
            : afterCeiling.toDouble());
    final totalG =
        resolvedDuringTarget?.totalG.round() ?? (finalRate * durationH).round();
    final displayRangeLow = resolvedDuringTarget?.rangeLowG ?? during.carbsLowG;
    final displayRangeHigh =
        resolvedDuringTarget?.rangeHighG ?? during.carbsHighG;

    // Matches during-workout HTML formula-block exactly
    final sl = sportLabel.toLowerCase();
    final rbl = rawBandLow.round();
    final rbh = rawBandHigh.round();
    final scl = scaledLow.round();
    final sch = scaledHigh.round();
    final pt = overrideRate?.round();

    final tldrLines = <FormulaLine>[
      // ① duration → band
      FormulaLine([
        fAccent('$durationMin min $sl '),
        fOp('\u2192 '),
        fAccent('band '),
        fDim('$rbl\u2013$rbh g/hr'),
      ], stepNumber: '\u2460'),
      // ② gut multiplier
      FormulaLine([
        fDim('$rbl\u2013$rbh '),
        fOp('\u00d7 '),
        fAccent('$gutMultiplier gut '),
        fOp('= '),
        fDim('$scl\u2013$sch g/hr'),
      ], stepNumber: '\u2461'),
      // ③ midpoint
      FormulaLine([
        fAccent('midpoint '),
        fOp('= '),
        fDim('$midpoint g/hr'),
      ], stepNumber: '\u2462'),
      // ④ sport ceiling
      FormulaLine([
        fAccent('sport ceiling '),
        fOp('= '),
        fDim('$sportCeiling g/hr '),
        fOp('\u00b7 '),
        fAccent('$midpoint '),
        fOp(isCapped ? '> ' : '< '),
        fAccent('$sportCeiling '),
        fOp('\u2192 '),
        fAccent(isCapped ? 'capped at $sportCeiling' : 'no cap'),
      ], stepNumber: '\u2463'),
      // ⑤ personal target (always shown — shows "no override" when not applicable)
      FormulaLine([
        fAccent('personal target '),
        fOp('= '),
        fDim('${pt ?? "\u2014"} g/hr '),
        fOp('\u00b7 '),
        fAccent('effort '),
        fOp(durationMin >= 90 ? '\u2265 ' : '< '),
        fAccent('90 min '),
        fOp('\u2192 '),
        shouldApplyOverride ? fResult('override') : fAccent('no override'),
      ], stepNumber: '\u2464'),
    ];

    // Result line
    tldrLines.add(
      FormulaLine(
        [
          fAccent('${finalRate.round()} g/hr '),
          fOp('\u00d7 '),
          fAccent('${_formatDuration(durationH)} hr '),
          fOp('= '),
          fResult('${totalG}g'),
        ],
        isResultLine: true,
        showDividerBefore: true,
      ),
    );

    // Full Story Q&A
    final storySections = _duringStorySections(
      hasOverride: shouldApplyOverride,
      personalCarbTargetGPerH: personalCarbTargetGPerH,
      personalTargetSport: personalTargetSport ?? sportLabel.toLowerCase(),
      isBrick: false,
    );

    return CarbTransparencyData(
      phase: 'during',
      tldrBody:
          'The longer the workout, the higher the risk your body will burn out '
          'its glycogen storage \u2014 commonly known as \u201chitting the wall\u201d '
          '\u2014 therefore the higher the per-hour carb target we recommend. '
          'However, there is an absorption limit determined by your gut training '
          'status, and it is sport-specific. For athletes who have set a personal '
          'carb target for their races, that target will override our recommendation '
          'for longer workouts.',
      tldrLines: tldrLines,
      storySections: storySections,
      videoTitle: 'Watch: During-Workout Fueling',
      targetGrams: totalG.toDouble(),
      rangeLow: displayRangeLow,
      rangeHigh: displayRangeHigh,
      sportLabel: sportLabel,
      currentGutTrainingLabel: gutTrainingLabel,
      currentPersonalTargetGPerH: overrideRate,
      personalTargetSport: personalTargetSport ?? sportLabel.toLowerCase(),
      isOverrideApplied: shouldApplyOverride,
    );
  }

  // ---------------------------------------------------------------------------
  // DURING — BRICK SEGMENT
  // ---------------------------------------------------------------------------

  CarbTransparencyData _brickSegmentTransparency({
    required MacroTargets macroTargets,
    required BrickSegmentMacroTarget segment,
    required String gutTrainingLabel,
    required double gutMultiplier,
    double? personalCarbTargetGPerH,
    String? personalTargetSport,
    ResolvedDuringTarget? resolvedDuringTarget,
  }) {
    final sport = segment.sport;
    final sportCap = sport[0].toUpperCase() + sport.substring(1);
    final durationMin = segment.durationMinutes;
    final durationH = durationMin / 60;
    final cumulativeMin = segment.cumulativeDurationMin?.round() ?? durationMin;
    // The edge function uses TOTAL event time for band lookup, not cumulative
    final totalEventMin = macroTargets.metrics.durationMin.round();

    final rawBandLow = segment.rawBandLowGPerH ?? 0;
    final rawBandHigh = segment.rawBandHighGPerH ?? 0;
    final scaledLow = segment.scaledBandLowGPerH ?? 0;
    final scaledHigh = segment.scaledBandHighGPerH ?? 0;
    final midpoint = ((scaledLow + scaledHigh) / 2).round();
    final sportCeiling =
        segment.sportCeilingGPerH?.round() ?? _defaultSportCeiling(sportCap);
    final isCapped = midpoint > sportCeiling;
    final afterCeiling = isCapped ? sportCeiling : midpoint;
    final brickPenalty = segment.brickPenalty ?? 1.0;
    final hasBrickPenalty = brickPenalty < 1.0;
    final afterPenalty = hasBrickPenalty
        ? (afterCeiling * brickPenalty).round()
        : afterCeiling;
    final overrideRate =
        resolvedDuringTarget?.settingsOverrideRateGPerH ??
        personalCarbTargetGPerH;
    final isOverrideApplied = resolvedDuringTarget?.isOverrideApplied ?? false;
    final hasEligiblePersonalTarget =
        overrideRate != null && totalEventMin >= 90;
    final shouldApplyOverride =
        isOverrideApplied ||
        (resolvedDuringTarget == null && hasEligiblePersonalTarget);
    final finalRate =
        resolvedDuringTarget?.rateGPerH ??
        (shouldApplyOverride
            ? (overrideRate ?? afterPenalty.toDouble())
            : afterPenalty.toDouble());
    final totalG =
        resolvedDuringTarget?.totalG.round() ?? (finalRate * durationH).round();
    final displayRangeLow =
        resolvedDuringTarget?.rangeLowG ?? segment.carbsLowG;
    final displayRangeHigh =
        resolvedDuringTarget?.rangeHighG ?? segment.carbsHighG;

    // Matches brick variant formula-block in HTML exactly
    final rbl = rawBandLow.round();
    final rbh = rawBandHigh.round();
    final scl = scaledLow.round();
    final sch = scaledHigh.round();
    final pt = overrideRate?.round();
    var step = 0;
    const sn = [
      '\u2460',
      '\u2461',
      '\u2462',
      '\u2463',
      '\u2464',
      '\u2465',
      '\u2466',
    ];

    final tldrLines = <FormulaLine>[
      // ① total event time → band
      FormulaLine([
        fAccent('total event time '),
        fOp('= '),
        fDim('$totalEventMin min '),
        fOp('\u2192 '),
        fAccent('band '),
        fDim('$rbl\u2013$rbh g/hr'),
      ], stepNumber: sn[step++]),
      // ② gut multiplier
      FormulaLine([
        fDim('$rbl\u2013$rbh '),
        fOp('\u00d7 '),
        fAccent('$gutMultiplier gut '),
        fOp('= '),
        fDim('$scl\u2013$sch g/hr'),
      ], stepNumber: sn[step++]),
      // ③ midpoint
      FormulaLine([
        fAccent('midpoint '),
        fOp('= '),
        fDim('$midpoint g/hr'),
      ], stepNumber: sn[step++]),
      // ④ sport ceiling
      FormulaLine([
        fAccent('sport ceiling '),
        fOp('= '),
        fDim('$sportCeiling g/hr '),
        fOp('\u00b7 '),
        fAccent('$midpoint '),
        fOp(isCapped ? '> ' : '< '),
        fAccent('$sportCeiling '),
        fOp('\u2192 '),
        fAccent(isCapped ? 'capped at $sportCeiling' : 'no cap'),
      ], stepNumber: sn[step++]),
    ];

    // ⑤ brick penalty (only for run-after-bike)
    if (hasBrickPenalty) {
      tldrLines.add(
        FormulaLine([
          fAccent('brick penalty '),
          fOp('\u00b7 '),
          fAccent('run after bike '),
          fOp('\u2192 '),
          fAccent('$afterCeiling '),
          fOp('\u00d7 '),
          fAccent('$brickPenalty '),
          fOp('= '),
          fDim('$afterPenalty g/hr'),
        ], stepNumber: sn[step++]),
      );
    }

    // ⑤/⑥ personal target
    if (hasEligiblePersonalTarget) {
      tldrLines.add(
        FormulaLine([
          fAccent('personal target '),
          fOp('= '),
          fDim('${pt ?? "\u2014"} g/hr '),
          fOp('\u00b7 '),
          fAccent('effort '),
          fOp('\u2265 '),
          fAccent('90 min '),
          fOp('\u2192 '),
          shouldApplyOverride ? fResult('override') : fAccent('no override'),
        ], stepNumber: sn[step++]),
      );
    }

    // Result
    tldrLines.add(
      FormulaLine(
        [
          fAccent('${finalRate.round()} g/hr '),
          fOp('\u00d7 '),
          fAccent('${_formatDuration(durationH)} hr '),
          fOp('= '),
          fResult('${totalG}g'),
        ],
        isResultLine: true,
        showDividerBefore: true,
      ),
    );

    final storySections = _brickStorySections(
      cumulativeMin: cumulativeMin,
      segmentMin: durationMin,
      hasBrickPenalty: hasBrickPenalty,
      hasOverride: shouldApplyOverride,
      personalCarbTargetGPerH: personalCarbTargetGPerH,
      personalTargetSport: personalTargetSport ?? sport,
    );

    return CarbTransparencyData(
      phase: 'during',
      tldrBody:
          'In a multi-sport event, your carb target is based on '
          '**total elapsed time** across the entire event \u2014 not just this '
          'segment. The longer your body has been working, the higher the risk '
          'of glycogen depletion, so the algorithm looks at your cumulative race '
          'time to set the right band.',
      tldrLines: tldrLines,
      storySections: storySections,
      videoTitle: 'Watch: During-Workout Fueling',
      targetGrams: totalG.toDouble(),
      rangeLow: displayRangeLow,
      rangeHigh: displayRangeHigh,
      sportLabel: sportCap,
      currentGutTrainingLabel: gutTrainingLabel,
      currentPersonalTargetGPerH: overrideRate,
      personalTargetSport: personalTargetSport ?? sport,
      isOverrideApplied: shouldApplyOverride,
    );
  }

  // ---------------------------------------------------------------------------
  // BRICK TRANSITION (T1 / T2)
  // ---------------------------------------------------------------------------

  CarbTransparencyData _brickTransitionTransparency({
    required ExplanationPhase phase,
    required MacroTargets macroTargets,
  }) {
    final isT1 = phase == ExplanationPhase.transition1;
    final transitionName = isT1 ? 'T1' : 'T2';
    final fromSport = isT1 ? 'swim' : 'bike';
    final toSport = isT1 ? 'bike' : 'run';

    // Look up transition targets if available
    final transitions = macroTargets.brickPhaseTargets?.transitions;
    final tIdx = isT1 ? 0 : 1;
    final transition = (transitions != null && tIdx < transitions.length)
        ? transitions[tIdx]
        : null;
    final targetG = transition?.carbsG.round();

    final tldrBody =
        'Transition $transitionName is a short window between the $fromSport '
        'and $toSport segments. Use this time to take in quick-digesting carbs '
        'and fluids before the next leg begins.';

    final tldrLines = <FormulaLine>[];
    if (targetG != null) {
      tldrLines.add(
        FormulaLine([
          fAccent('$transitionName target '),
          fOp('= '),
          fResult('${targetG}g'),
        ]),
      );
    }

    return CarbTransparencyData(
      phase: 'transition',
      tldrBody: tldrBody,
      tldrLines: tldrLines,
      storySections: [
        StorySection(
          question: 'Why eat during a transition?',
          answer:
              'Transitions are your only chance to refuel between segments. Even '
              'though they are short, consuming **quick-digesting carbs** here helps '
              'maintain blood glucose for the next leg \u2014 especially important before '
              'the $toSport where intensity often increases.',
        ),
        StorySection(
          question: 'What kinds of food work best?',
          answer:
              'Choose foods that digest fast and require minimal chewing: '
              '**gels, chews, or liquid carbs.** Avoid high-fibre or high-fat '
              'options that could cause GI distress once you start moving again.',
        ),
      ],
      targetGrams: transition?.carbsG,
      rangeLow: transition?.carbsLowG,
      rangeHigh: transition?.carbsHighG,
      sportLabel: transitionName,
    );
  }

  // ---------------------------------------------------------------------------
  // BRICK — GENERIC (no detailed segment data available)
  // ---------------------------------------------------------------------------

  CarbTransparencyData _brickGenericTransparency({
    required MacroTargets macroTargets,
    required String sportLabel,
    required String gutTrainingLabel,
    required double gutMultiplier,
    double? personalCarbTargetGPerH,
    String? personalTargetSport,
  }) {
    return CarbTransparencyData(
      phase: 'during',
      tldrBody:
          'In a multi-sport event, your carb target is based on '
          '**total elapsed time** across the entire event \u2014 not just this '
          'segment. The longer your body has been working, the higher the risk '
          'of glycogen depletion, so the algorithm looks at your cumulative race '
          'time to set the right band.',
      tldrLines: const [],
      storySections: _brickStorySections(
        cumulativeMin: 0,
        segmentMin: 0,
        hasBrickPenalty: false,
        hasOverride: false,
        personalCarbTargetGPerH: personalCarbTargetGPerH,
        personalTargetSport: personalTargetSport ?? sportLabel,
      ),
      videoTitle: 'Watch: During-Workout Fueling',
      sportLabel: sportLabel,
      currentGutTrainingLabel: gutTrainingLabel,
      currentPersonalTargetGPerH: personalCarbTargetGPerH,
      personalTargetSport: personalTargetSport ?? sportLabel,
    );
  }

  // ---------------------------------------------------------------------------
  // DURING — SWIM (zero state)
  // ---------------------------------------------------------------------------

  CarbTransparencyData _swimTransparency({
    BrickSegmentMacroTarget? brickSegment,
  }) {
    final tldrLines = <FormulaLine>[];

    final storySections = <StorySection>[
      const StorySection(
        question: 'Why is the target zero during swimming?',
        answer:
            'Swimming is the only endurance sport where fueling during the activity is '
            'physically impossible. You cannot eat or drink while in open water or a pool '
            'without stopping. All carbohydrate intake is therefore shifted to the pre-swim '
            'meal, and to T1 where you have a brief window to consume calories before the '
            'bike leg begins.',
      ),
      const StorySection(
        question: 'Does the swim time still count toward total event time?',
        answer:
            'Yes \u2014 and this is important. Even though you consume 0g during the swim, '
            'your body is still burning glycogen for the entire duration. The swim time is '
            'fully included in the cumulative elapsed time used to determine your carb band '
            'on the bike and run segments.',
      ),
      const StorySection(
        question: 'What should I eat before the swim?',
        answer:
            'Your pre-workout carb targets account for the full race duration. See the '
            '**Before Workout** section for your pre-swim meal targets. T1 transition nutrition '
            'is shown separately in the race fueling plan.',
      ),
    ];

    return CarbTransparencyData(
      phase: 'during',
      tldrBody:
          'No carbohydrates can be consumed during swimming \u2014 it is physically '
          'impossible to eat or drink while in the water. All fueling for this segment '
          'shifts to the **before-workout phase** and to **T1 transition nutrition**.',
      tldrLines: tldrLines,
      storySections: storySections,
      isSwimZero: true,
      swimCallout: 'Fueling shifts to: Before workout \u00b7 T1 transition',
      targetGrams: 0,
      rangeLow: 0,
      rangeHigh: 0,
      sportLabel: 'Swim',
    );
  }

  // ---------------------------------------------------------------------------
  // FULL STORY SECTIONS — DURING SINGLE SPORT
  // ---------------------------------------------------------------------------

  List<StorySection> _duringStorySections({
    required bool hasOverride,
    double? personalCarbTargetGPerH,
    required String personalTargetSport,
    required bool isBrick,
  }) {
    final sections = <StorySection>[
      const StorySection(
        question: 'Why does duration set the starting range?',
        answer:
            'Your body can\'t replenish muscle glycogen while exercising \u2014 consumed '
            'carbs maintain blood glucose and slow depletion instead. The longer you go, '
            'the more you need. Research gives us reliable absorption ranges by duration.',
        citation:
            'Jeukendrup (2014) \u2014 Sports Medicine; Kerksick et al. (2017) \u2014 ISSN Position Stand',
        transparencyNote:
            'No single study gives these exact bands with these specific minute cutoffs. '
            'The research anchors two points: minimal intake under 60 min (Carter et al. 2004 '
            '\u2014 mouth rinse research), and up to 90 g/hr for very long efforts (Jeukendrup '
            '2004). The five bands are **Mealvana\'s interpolation**. The direction is well-supported. '
            'The specific cutoffs are ours.',
        dataChips: [
          '<60 min \u00b7 0\u201330 g/hr',
          '60\u201390 min \u00b7 30\u201360 g/hr',
          '90\u2013150 min \u00b7 45\u201360 g/hr',
          '150\u2013240 min \u00b7 60\u201390 g/hr',
          '>240 min \u00b7 80\u2013100 g/hr',
        ],
      ),
      const StorySection(
        question: 'What is gut training and why does it matter?',
        answer:
            'Athletes who consistently fuel during workouts upregulate the transporters '
            'that move carbs from gut to bloodstream. Your gut training level scales the '
            'entire band up or down.',
        citation:
            'Jeukendrup (2017) \u2014 Training the Gut for Athletes; Costa et al. (2019)',
        inlineEditType: InlineEditType.gutTraining,
        dataChips: [
          'Low \u00b7 0.7\u00d7',
          'Moderate \u00b7 1.0\u00d7',
          'High \u00b7 1.2\u00d7',
        ],
      ),
      const StorySection(
        question: 'Why doesn\'t body weight change the target?',
        answer:
            'During-exercise carb recommendations are **not body-weight dependent.** The '
            'limiting factor is gut absorption capacity \u2014 and that doesn\'t scale '
            'with body weight.',
        citation:
            'Jeukendrup (2014) \u2014 "There is no rationale for expressing carbohydrate '
            'recommendations per kilogram of body weight."',
      ),
      const StorySection(
        question: 'Why does sport type set a ceiling?',
        answer:
            'Running\'s vertical impact stresses the gut, limiting carb processing. '
            'Cycling\'s stable position removes that stress \u2014 cyclists can sustain '
            'nearly double the carb rate of runners. Gut training expands your band, but '
            'the sport ceiling is the hard limit it can never exceed. A highly gut-trained '
            'runner capped at **70 g/hr** on the run can realize the full benefit of their '
            'training up to **120 g/hr** on the bike.',
        citation:
            'Pfeiffer et al. (2012) \u2014 GI Problems in Endurance Sports',
        dataChips: [
          'Running \u00b7 max 70 g/hr',
          'Cycling \u00b7 max 120 g/hr',
          'Swimming \u00b7 0 g/hr',
        ],
      ),
    ];

    if (hasOverride) {
      sections.add(
        StorySection(
          question: 'Why does your personal target override the algorithm?',
          answer:
              'For efforts of 90 minutes or longer, your personal carb rate replaces the '
              'algorithm\'s midpoint. A newer athlete may start at 30 g/hr to avoid GI '
              'distress. An experienced athlete may push to 80 g/hr on a long ride. The '
              'algorithm gives you the science. Your personal target gives you the control.',
          inlineEditType: InlineEditType.personalTarget,
        ),
      );
    }

    return sections;
  }

  // ---------------------------------------------------------------------------
  // FULL STORY SECTIONS — BRICK
  // ---------------------------------------------------------------------------

  List<StorySection> _brickStorySections({
    required int cumulativeMin,
    required int segmentMin,
    required bool hasBrickPenalty,
    required bool hasOverride,
    double? personalCarbTargetGPerH,
    required String personalTargetSport,
  }) {
    final sections = <StorySection>[
      StorySection(
        question: 'Why does the band use total event time, not run time?',
        answer:
            'Glycogen depletion is cumulative \u2014 your body doesn\'t reset when you '
            'dismount the bike. By the time you start the run, you\'ve already been burning '
            'fuel for $cumulativeMin minutes. Using only the run duration ($segmentMin min) '
            'would dramatically underestimate how depleted you are and recommend a carb rate '
            'suited for a fresh runner.',
        citation: 'V4 algorithm \u2014 Mealvana cumulative time model',
      ),
    ];

    if (hasBrickPenalty) {
      sections.add(
        const StorySection(
          question: 'What is the brick penalty?',
          answer:
              'Running after cycling reduces your gut\'s ability to absorb carbohydrates. '
              'During the bike leg, blood is diverted away from the gut to working muscles. '
              'Transitioning to running \u2014 with its additional vertical impact \u2014 '
              'compounds this effect. The 20% reduction reflects the reduced splanchnic blood '
              'flow and mechanical stress during the early run.',
          citation:
              'Van Wijck et al. (2012) \u2014 Splanchnic hypoperfusion during exercise',
        ),
      );
    }

    // Gut training Q&A — same as single sport
    sections.add(
      const StorySection(
        question: 'What is gut training and why does it matter?',
        answer:
            'Your gut training level scales the entire duration band up or down '
            'before the sport ceiling is applied.',
        citation: 'Jeukendrup (2017); Costa et al. (2019)',
        inlineEditType: InlineEditType.gutTraining,
        dataChips: [
          'Low \u00b7 0.7\u00d7',
          'Moderate \u00b7 1.0\u00d7',
          'High \u00b7 1.2\u00d7',
        ],
      ),
    );

    if (hasOverride) {
      sections.add(
        StorySection(
          question: 'Why does your personal target override the algorithm?',
          answer:
              'For efforts of 90 minutes or longer your personal carb rate takes over. '
              'In a race context this is especially important \u2014 your personal target '
              'reflects your race-day fueling strategy, which may account for gut sensitivity '
              'late in the race, aid station availability, or coach guidance.',
          inlineEditType: InlineEditType.personalTarget,
        ),
      );
    }

    return sections;
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  int _defaultSportCeiling(String sportLabel) {
    final s = sportLabel.toLowerCase();
    if (s.contains('run')) return 70;
    if (s.contains('cycl') || s.contains('bike')) return 120;
    if (s.contains('swim')) return 0;
    return 70;
  }

  String _formatDuration(double hours) {
    if (hours == hours.roundToDouble()) return '${hours.round()}.0';
    return (hours * 10).round() / 10 == hours
        ? hours.toStringAsFixed(1)
        : hours.toStringAsFixed(2);
  }
}
