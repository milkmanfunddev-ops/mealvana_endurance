import 'dart:math' as math;

/// Client-side mirror of the daily-macro formula cores in
/// `supabase/functions/calculate-daily-macros-v6/formulas/` (rmr.ts, baseline.ts,
/// session.ts, neat-tef.ts, multi-day.ts).
///
/// Every constant lives in this file so that when the daily-macro SSOT
/// document ratifies, server and client update from one place and the parity
/// fixtures (`test/features/onboarding/fixtures/plan_preview_parity.json`)
/// are regenerated alongside. Pinned by `daily_baseline_calculator_test.dart`.
///
/// The server pipeline remains authoritative once workouts sync; this mirror
/// exists so the onboarding plan preview works offline, anonymously, and
/// biometrics-free.
class DailyBaselineCalculator {
  DailyBaselineCalculator._();

  // ---------------------------------------------------------------------------
  // RMR (rmr.ts)
  // ---------------------------------------------------------------------------

  /// Cunningham: RMR = 500 + 22 × LBM_kg.
  static double cunninghamRmr(double lbmKg) => 500 + 22 * lbmKg;

  /// Mifflin-St Jeor: 10×kg + 6.25×cm − 5×age + (5 male / −161 otherwise).
  /// Matches rmr.ts exactly: any non-male sex takes the −161 branch
  /// (Gender.other included).
  static double mifflinStJeorRmr({
    required double weightKg,
    required double heightCm,
    required int age,
    required bool isMale,
  }) {
    final sexOffset = isMale ? 5.0 : -161.0;
    return 10 * weightKg + 6.25 * heightCm - 5 * age + sexOffset;
  }

  /// Automatic method selection: Cunningham when body fat % known.
  static double calculateRmr({
    required double weightKg,
    required double heightCm,
    required int age,
    required bool isMale,
    double? bodyFatPct,
  }) {
    if (bodyFatPct != null) {
      final lbmKg = weightKg * (1 - bodyFatPct / 100);
      return cunninghamRmr(lbmKg);
    }
    return mifflinStJeorRmr(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      isMale: isMale,
    );
  }

  // ---------------------------------------------------------------------------
  // Baseline macros (baseline.ts)
  // ---------------------------------------------------------------------------

  static const double baselineCarbGPerKg = 4.0;
  static const double proteinGPerKgLbm = 1.8;
  static const double proteinGPerKgFallback = 1.4;
  static const double mastersProteinMultiplier = 1.15;
  static const int mastersAge = 45;

  /// Baseline macros before sessions are added. Fat here is a placeholder
  /// (1.2 g/kg) — real fat comes out of [calculateTdee].
  static ({double carbG, double protG, double fatG}) baselineMacros({
    required double weightKg,
    double? lbmKg,
    required int age,
  }) {
    final carbG = baselineCarbGPerKg * weightKg;
    var protG = lbmKg != null
        ? proteinGPerKgLbm * lbmKg
        : proteinGPerKgFallback * weightKg;
    if (age >= mastersAge) {
      protG *= mastersProteinMultiplier;
    }
    final fatG = 1.2 * weightKg;
    return (carbG: carbG, protG: protG, fatG: fatG);
  }

  static const double carbClampMinGPerKg = 3.0;
  static const double carbClampMaxGPerKg = 12.0;
  static const double proteinClampMinGPerKg = 1.2;
  static const double proteinClampMaxGPerKg = 2.5;

  /// Clamp carb/protein to safe g/kg ranges (baseline.ts clampMacros).
  static ({double carbG, double protG}) clampMacros({
    required double carbG,
    required double protG,
    required double weightKg,
  }) {
    final carbClamped = math.max(
      carbClampMinGPerKg * weightKg,
      math.min(carbG, carbClampMaxGPerKg * weightKg),
    );
    final protClamped = math.max(
      proteinClampMinGPerKg * weightKg,
      math.min(protG, proteinClampMaxGPerKg * weightKg),
    );
    return (carbG: carbClamped, protG: protClamped);
  }

  /// Pre-load override (multi-day.ts): race eve / very high TSS → 9.0 g/kg.
  static const double carbLoadGPerKg = 9.0;

  // ---------------------------------------------------------------------------
  // Session cost & carb demand (session.ts)
  // ---------------------------------------------------------------------------

  /// IF from zone distribution via RMS:
  /// sqrt(pctConv×0.68² + pctTempo×0.88² + pctAllout×1.08²).
  static double zoneDistributionToIf({
    required double pctConversational,
    required double pctTempo,
    required double pctAllout,
  }) {
    final ifSquared =
        pctConversational * 0.68 * 0.68 +
        pctTempo * 0.88 * 0.88 +
        pctAllout * 1.08 * 1.08;
    return math.sqrt(ifSquared);
  }

  static const Map<String, double> _sessionBaseRateKcalPerKg = {
    'running': 11,
    'cycling': 9,
    'swimming': 7,
    'strength': 5,
  };

  /// Session calorie cost. Endurance sports scale quadratically with IF.
  /// Weight multiplies LAST, mirroring session.ts, so cost is exactly linear
  /// in body weight (invariant I6).
  static double sessionCost({
    required String sport,
    required double durationHr,
    required double intensityFactor,
    required double weightKg,
  }) {
    final rate = _sessionBaseRateKcalPerKg[sport] ?? 11;
    if (sport == 'strength') {
      return rate * (intensityFactor / 0.75) * durationHr * weightKg;
    }
    return rate * math.pow(intensityFactor / 0.75, 2) * durationHr * weightKg;
  }

  /// Carb oxidation anchors: [IF, g/hr at 75 kg reference] (session.ts).
  static const List<List<double>> _carbOxidationAnchors = [
    [0.55, 25],
    [0.70, 40],
    [0.80, 55],
    [0.90, 75],
    [1.00, 95],
    [1.10, 115],
  ];

  /// Piecewise-linear carb oxidation rate from IF.
  static double carbOxidationRate(double intensityFactor) {
    final anchors = _carbOxidationAnchors;
    if (intensityFactor <= anchors.first[0]) return anchors.first[1];
    if (intensityFactor >= anchors.last[0]) return anchors.last[1];
    for (var i = 0; i < anchors.length - 1; i++) {
      final ifLow = anchors[i][0];
      final rateLow = anchors[i][1];
      final ifHigh = anchors[i + 1][0];
      final rateHigh = anchors[i + 1][1];
      if (intensityFactor >= ifLow && intensityFactor <= ifHigh) {
        final t = (intensityFactor - ifLow) / (ifHigh - ifLow);
        return rateLow + t * (rateHigh - rateLow);
      }
    }
    return 60;
  }

  /// Strength carb demand is a flat rate — intensity-independent (Q-003).
  static const double strengthCarbGPerHr = 27.0;

  /// Session carb demand: oxidation rate × duration × (kg/75), ×1.15 when
  /// long (>1.5 h) or intense (IF>0.85). Strength ignores IF entirely and
  /// uses the flat 27 g/hr rate with no multiplier (Q-003).
  static double carbDemand({
    required String sport,
    required double intensityFactor,
    required double durationHr,
    required double weightKg,
  }) {
    if (sport == 'strength') {
      return strengthCarbGPerHr * durationHr * (weightKg / 75);
    }
    final rateGPerHr = carbOxidationRate(intensityFactor);
    final raw = rateGPerHr * durationHr * (weightKg / 75);
    if (durationHr > 1.5 || intensityFactor > 0.85) {
      return raw * 1.15;
    }
    return raw;
  }

  // ---------------------------------------------------------------------------
  // NEAT / TEF / TDEE (neat-tef.ts)
  // ---------------------------------------------------------------------------

  /// Base NEAT factor by typical weekly training hours (moderate default).
  static double baseNeatForWeeklyHours(double? typicalWeeklyHours) {
    if (typicalWeeklyHours == null) return 0.25;
    if (typicalWeeklyHours < 5) return 0.30;
    if (typicalWeeklyHours < 8) return 0.25;
    if (typicalWeeklyHours < 12) return 0.20;
    if (typicalWeeklyHours < 18) return 0.17;
    return 0.13;
  }

  /// Day modifier (neat-tef.ts getDayModifier), evaluated for the preview's
  /// simplified day types: double 1.15, training 1.10, rest-after-hard 0.90,
  /// rest 1.00.
  static const double trainingDayModifier = 1.10;
  static const double restDayModifier = 1.00;

  static double calculateNeat({
    required double rmr,
    required double baseNeat,
    required double dayModifier,
    double lifestyleModifier = 1.00,
  }) {
    return rmr * baseNeat * dayModifier * lifestyleModifier;
  }

  static const double fatFloorGPerKg = 0.8;

  static double _flooredFat(double fatFromTdee, double weightKg) {
    return math.max(fatFloorGPerKg * weightKg, fatFromTdee);
  }

  /// TDEE with iterative TEF convergence (neat-tef.ts calculateTDEE).
  /// Returns UNROUNDED values (R1) and the PRE-CAP fat residual floored at
  /// 0.8 g/kg — the fat ceiling lives in [applyFatCap] (assembly step 10b),
  /// not here (Q-014).
  static ({double tdee, double fatG, double tef, bool fatAtFloor})
  calculateTdee({
    required double rmr,
    required double neat,
    required double sessionKcal,
    required double carbG,
    required double protG,
    required double weightKg,
  }) {
    var tef = 0.0;
    const maxPasses = 5;

    for (var pass = 1; pass <= maxPasses; pass++) {
      final prevTef = tef;
      final tdee = rmr + neat + tef + sessionKcal;
      final fat = _flooredFat((tdee - carbG * 4 - protG * 4) / 9, weightKg);
      final intake = carbG * 4 + protG * 4 + fat * 9;
      final newTef = intake * 0.10;
      final delta = (newTef - prevTef).abs();
      tef = newTef;

      if (delta < 10) break;
    }

    final finalTdee = rmr + neat + tef + sessionKcal;
    final rawFat = (finalTdee - carbG * 4 - protG * 4) / 9;
    final finalFat = _flooredFat(rawFat, weightKg);
    return (
      tdee: finalTdee,
      fatG: finalFat,
      tef: tef,
      fatAtFloor: finalFat > rawFat,
    );
  }

  /// Assembly step 10b (pipeline.ts applyFatCap): cap fat at 30 %E of TDEE,
  /// redistributing excess energy to carbohydrate up to the 12 g/kg clamp
  /// (Q-014). Conserves energy exactly; in the corner case where the carb
  /// clamp saturates, fat keeps the remainder rather than energy dropping.
  static ({double carbG, double fatG}) applyFatCap({
    required double carbG,
    required double fatG,
    required double tdee,
    required double weightKg,
  }) {
    final fatCap = 0.30 * tdee / 9;
    if (fatG <= fatCap) return (carbG: carbG, fatG: fatG);

    final excessKcal = (fatG - fatCap) * 9;
    final headroom = carbClampMaxGPerKg * weightKg - carbG;
    return (
      carbG: carbG + math.min(excessKcal / 4, headroom),
      fatG: fatCap + math.max(0, excessKcal - headroom * 4) / 9,
    );
  }
}
