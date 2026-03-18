import '../../../shared/domain/activity_type.dart';
import '../domain/macro_targets.dart';

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
enum ExplanationPhase {
  before,
  during,
  after,
  transition1,
  transition2,
}

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
  }) {
    switch (phase) {
      case ExplanationPhase.before:
        return _beforeExplanations(macroTargets, bodyWeightKg, useImperial, actuals);
      case ExplanationPhase.during:
        return _duringExplanations(macroTargets, bodyWeightKg, useImperial, actuals);
      case ExplanationPhase.after:
        return _afterExplanations(macroTargets, bodyWeightKg, useImperial, actuals);
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
    explanations.add(MacroExplanation(
      macroName: 'Carbohydrates',
      value: '${pre.carbsG.round()}',
      unit: 'g',
      rangeLow: pre.carbsLowG?.round().toString(),
      rangeHigh: pre.carbsHighG?.round().toString(),
      actualValue: actuals != null ? '${actuals['carbs'] ?? 0}' : null,
      formulaText: 'Your pre-workout carb target scales with your body weight '
          'and how far out you eat before your activity.\n\n'
          'Formula:  weight  x  hours_before g/kg\n'
          '${wt}kg  x  ${carbPerKg.toStringAsFixed(1)} g/kg  =  ${pre.carbsG.round()}g\n\n'
          'Rate: 1 g/kg per hour before workout '
          '(min 0.5, max 4.0 g/kg).\n'
          'Range: target +/- 12.5%.',
      rangeRationale: 'Your range of '
          '${pre.carbsLowG?.round() ?? ""}–${pre.carbsHighG?.round() ?? ""}g '
          'gives you flexibility to hit your goal with real food portions.',
    ));

    // Fluids (Before: Carbs, Fluids, Sodium — no Protein)
    final fluidsVal = useImperial ? pre.fluidsFlOz.round() : pre.fluidsMl.round();
    final fluidsUnit = useImperial ? 'oz' : 'mL';
    final fluidsMlPerKg = mealType == 'full meal' ? 6.5 : (mealType == 'snack' ? 5.5 : 0.0);
    explanations.add(MacroExplanation(
      macroName: 'Fluids',
      value: '$fluidsVal',
      unit: fluidsUnit,
      rangeLow: useImperial
          ? (pre.fluidsLowMl != null ? (pre.fluidsLowMl! * 0.033814).round().toString() : null)
          : pre.fluidsLowMl?.round().toString(),
      rangeHigh: useImperial
          ? (pre.fluidsHighMl != null ? (pre.fluidsHighMl! * 0.033814).round().toString() : null)
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
    ));

    // Sodium
    explanations.add(MacroExplanation(
      macroName: 'Sodium',
      value: '${pre.sodiumMg.round()}',
      unit: 'mg',
      rangeLow: pre.sodiumLowMg?.round().toString(),
      rangeHigh: pre.sodiumHighMg?.round().toString(),
      actualValue: actuals != null ? '${actuals['sodium'] ?? 0}' : null,
      formulaText: 'Sodium helps your body absorb and retain the fluids you drink '
          'before your workout.\n\n'
          'Formula:  base_sodium (by sweat level)  +  environment_bump\n'
          'Your target of ${pre.sodiumMg.round()}mg is based on your '
          'sweat sodium level and $mealType timing.\n\n'
          'Base sodium: low=300, medium=450, high=600 mg.\n'
          'Hot weather adds +100mg.',
      rangeRationale: 'The wide range '
          '(${pre.sodiumLowMg?.round() ?? 0}–${pre.sodiumHighMg?.round() ?? 0}mg) '
          'is intentional — sodium needs vary a lot between individuals.',
    ));

    return explanations;
  }

  // ── During Phase ────────────────────────────────────────────────────

  List<MacroExplanation> _duringExplanations(
    MacroTargets mt,
    double weightKg,
    bool useImperial,
    Map<String, int>? actuals,
  ) {
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
      explanations.add(MacroExplanation(
        macroName: 'Carbohydrates',
        value: '0',
        unit: 'g',
        actualValue: actuals != null ? '${actuals['carbs'] ?? 0}' : null,
        formulaText: 'No carb fueling is possible during swimming — '
            'you can\'t eat or drink while in the water.\n\n'
            'Swimming carb ceiling: 0 g/hr.',
        rangeRationale: 'Focus on pre- and post-workout nutrition instead.',
      ));
      return explanations;
    }

    // Carbs — with full formula breakdown
    final ceilingNote = during.carbRateGPerH > ceiling
        ? '\nSport ceiling ($sportName): $ceiling g/hr — rate capped.'
        : '';
    explanations.add(MacroExplanation(
      macroName: 'Carbohydrates',
      value: '${during.carbTotalG.round()}',
      unit: 'g',
      rangeLow: during.carbsLowG?.round().toString(),
      rangeHigh: during.carbsHighG?.round().toString(),
      actualValue: actuals != null ? '${actuals['carbs'] ?? 0}' : null,
      formulaText: 'Your fueling rate is determined by your activity duration, '
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
          'Sport ceilings: running=$ceiling g/hr, cycling=120 g/hr.',
      rangeRationale: 'The range reflects individual differences in gut '
          'tolerance and carb absorption rates.',
    ));

    // Fluids
    final fluidsVal = useImperial ? during.fluidTotalFlOz.round() : during.fluidTotalMl.round();
    final fluidsUnit = useImperial ? 'oz' : 'mL';
    explanations.add(MacroExplanation(
      macroName: 'Fluids',
      value: '$fluidsVal',
      unit: fluidsUnit,
      rangeLow: useImperial
          ? (during.fluidsLowMl != null ? (during.fluidsLowMl! * 0.033814).round().toString() : null)
          : during.fluidsLowMl?.round().toString(),
      rangeHigh: useImperial
          ? (during.fluidsHighMl != null ? (during.fluidsHighMl! * 0.033814).round().toString() : null)
          : during.fluidsHighMl?.round().toString(),
      actualValue: actuals != null
          ? '${useImperial ? ((actuals['fluids'] ?? 0) * 0.033814).round() : actuals['fluids'] ?? 0}'
          : null,
      formulaText: 'We replace about 75% of your sweat losses during activity.\n\n'
          'Formula:  sweat_rate  x  0.75  x  duration\n'
          '${during.fluidRateMlPerH.round()} mL/hr  x  ${durationH.toStringAsFixed(1)}h  =  ${during.fluidTotalMl.round()}mL\n\n'
          'Your sweat rate is estimated from your sweat profile and '
          'adjusted for temperature (linear above 20°C).',
      rangeRationale: 'Replacing 75% of sweat losses prevents dehydration '
          'without risking overhydration.',
    ));

    // Sodium
    explanations.add(MacroExplanation(
      macroName: 'Sodium',
      value: '${during.sodiumTotalMg.round()}',
      unit: 'mg',
      rangeLow: during.sodiumLowMg?.round().toString(),
      rangeHigh: during.sodiumHighMg?.round().toString(),
      actualValue: actuals != null ? '${actuals['sodium'] ?? 0}' : null,
      formulaText: 'We replace about 60% of your sweat sodium losses.\n\n'
          'Formula:  sweat_rate  x  sodium_conc  x  0.60  x  duration\n'
          '${during.sodiumRateMgPerH.round()} mg/hr  x  ${durationH.toStringAsFixed(1)}h  =  ${during.sodiumTotalMg.round()}mg\n\n'
          'Sodium concentrations by sweat level: '
          'low=550, medium=925, high=1150 mg/L.\n'
          'Rate clamped to 300–1200 mg/hr for safety.',
      rangeRationale: 'Your body handles the remaining 40% through '
          'normal sodium regulation.',
    ));

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
    explanations.add(MacroExplanation(
      macroName: 'Carbohydrates',
      value: '${post.carbsG.round()}',
      unit: 'g',
      rangeLow: post.carbsLowG?.round().toString(),
      rangeHigh: post.carbsHighG?.round().toString(),
      actualValue: actuals != null ? '${actuals['carbs'] ?? 0}' : null,
      formulaText: 'Recovery carbs replenish the glycogen (energy) your muscles '
          'used during your workout.\n\n'
          'Formula:  weight  x  duration_multiplier\n'
          '${wt}kg  x  ${carbPerKg.toStringAsFixed(1)} g/kg  =  ${post.carbsG.round()}g'
          '$durationNote\n\n'
          'Range: target +/- 20%.',
      rangeRationale: 'Eat within the first hour after your workout for the best recovery.',
    ));

    // Protein (After: Carbs, Protein, Sodium — no Fluids)
    final proteinPerKg = 0.30;
    explanations.add(MacroExplanation(
      macroName: 'Protein',
      value: '${post.proteinG.round()}',
      unit: 'g',
      rangeLow: post.proteinLowG?.round().toString(),
      rangeHigh: post.proteinHighG?.round().toString(),
      actualValue: actuals != null ? '${actuals['protein'] ?? 0}' : null,
      formulaText: 'Post-workout protein kickstarts muscle repair and recovery.\n\n'
          'Formula:  weight  x  0.30 g/kg\n'
          '${wt}kg  x  $proteinPerKg g/kg  =  ${post.proteinG.round()}g\n\n'
          'Aim for 20–40g of high-quality protein (with 2–3g leucine) '
          'like chicken, eggs, Greek yogurt, or a protein shake.',
      rangeRationale: 'Eat protein within the first hour after exercise '
          'for maximum muscle recovery benefit.',
    ));

    // Sodium
    explanations.add(MacroExplanation(
      macroName: 'Sodium',
      value: '${post.sodiumMg.round()}',
      unit: 'mg',
      rangeLow: post.sodiumLowMg?.round().toString(),
      rangeHigh: post.sodiumHighMg?.round().toString(),
      actualValue: actuals != null ? '${actuals['sodium'] ?? 0}' : null,
      formulaText: 'Sodium in your recovery meal or drink helps your body '
          'hold onto the fluids you\'re drinking.\n\n'
          'Formula:  max(300, min(700, sodium_deficit x 0.5))\n'
          'Target:  ${post.sodiumMg.round()}mg\n\n'
          'We replace 50% of your remaining sodium deficit, '
          'clamped between 300–700mg.',
      rangeRationale: 'Adding sodium to your recovery fluids significantly '
          'improves rehydration compared to plain water.',
    ));

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
        formulaText: 'Quick, easily-digestible carbs to keep your blood sugar '
            'steady during the ${isT1 ? "first" : "second"} transition.\n\n'
            'Formula:  fixed ${carbs}g (${isT1 ? "T1" : "T2"} transition)\n\n'
            'Transition targets are fixed values based on race distance. '
            'Sprint (<90 min) and short Olympic (<3 hr) use reduced values.',
        rangeRationale: 'Transitions are quick — these are fixed targets designed '
            'for fast absorption.',
      ),
      MacroExplanation(
        macroName: 'Fluids',
        value: '$water',
        unit: 'mL',
        actualValue: actuals != null ? '${(actuals['fluids'] ?? 0)}' : null,
        formulaText: 'A small drink during transition to stay on top of '
            'hydration without overfilling your stomach.\n\n'
            'Formula:  fixed ${water}mL (${isT1 ? "T1" : "T2"} transition)',
        rangeRationale: 'Keep it small — you\'ll resume full hydration '
            'in the next segment.',
      ),
      MacroExplanation(
        macroName: 'Sodium',
        value: '$sodium',
        unit: 'mg',
        actualValue: actuals != null ? '${actuals['sodium'] ?? 0}' : null,
        formulaText: 'Sodium from your sports drink or gel supports fluid '
            'absorption during the transition.\n\n'
            'Formula:  fixed ${sodium}mg (${isT1 ? "T1" : "T2"} transition)',
        rangeRationale: 'A small amount to bridge between segments.',
      ),
    ];
  }
}
