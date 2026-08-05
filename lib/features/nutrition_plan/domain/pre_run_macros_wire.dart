import 'macro_targets.dart';

/// Defensive parsing of the pre-workout fields on the `calculate-macros` edge
/// function's response.
///
/// **PW-013 — coordinated-release hazard.** Retiring the integer
/// `pre_run_hydration_tier` in favour of the `pre_run_hydration_regime` string
/// requires the client, the edge function and the engine to move together, and
/// they do not: a Flutter build and a Supabase function deploy ship
/// independently, and users run old builds for weeks. So every reader must
/// accept **both** shapes:
///
/// * new server → old client: the client sees no `..._tier` and falls back to
///   its offline path rather than crashing on a missing key.
/// * old server → new client: this helper maps the retired integer forward.
///
/// Neither direction may throw. An unrecognised value yields `null`, which
/// every consumer already treats as "regime unknown, don't claim one".
abstract final class PreRunMacrosWire {
  /// Wire key for the hydration v6 regime string.
  static const String regimeKey = 'pre_run_hydration_regime';

  /// Retired wire key for the integer hydration tier. Read-only, never
  /// written.
  static const String legacyTierKey = 'pre_run_hydration_tier';

  static const Set<String> _knownRegimes = {
    PreRunHydrationRegime.cited,
    PreRunHydrationRegime.extrapolated,
    PreRunHydrationRegime.clearanceBound,
    PreRunHydrationRegime.gated,
  };

  /// Reads the hydration regime from an edge-function `macros` map, accepting
  /// the new string field or the retired integer tier, in that order.
  static String? regimeFrom(Map<String, dynamic> macros) {
    final raw = macros[regimeKey];
    if (raw is String && _knownRegimes.contains(raw)) return raw;
    // A server that emits an unrecognised regime string is ahead of this
    // build. Prefer "unknown" over guessing — but still try the legacy tier,
    // since a transitional server may emit both.
    return regimeFromLegacyTier(_asInt(macros[legacyTierKey]));
  }

  /// Best-effort forward map of the retired integer tier onto a v6 regime.
  ///
  /// Shares [PreRunMacros.regimeFromLegacyTier] with the cached-JSON path so
  /// an old server and an old cached plan can never disagree about what a
  /// given tier meant.
  static String? regimeFromLegacyTier(int? tier) =>
      PreRunMacros.regimeFromLegacyTier(tier);

  /// Reads a target-basis string, rejecting values this build doesn't know.
  static String? targetBasisFrom(Map<String, dynamic> macros, String key) {
    final raw = macros[key];
    if (raw is! String) return null;
    return const {
          PreRunTargetBasis.evidencedBand,
          PreRunTargetBasis.designChoice,
          PreRunTargetBasis.none,
        }.contains(raw)
        ? raw
        : null;
  }

  /// Reads the per-feeding fluid split. Missing or malformed → `null` (the
  /// consumer falls back to the plan total), never a throw.
  static List<PreRunFluidTier>? fluidTiersFrom(dynamic raw) {
    if (raw is! List) return null;
    final tiers = <PreRunFluidTier>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final tier = entry['tier'];
      final ml = entry['fluid_ml'] ?? entry['fluidMl'];
      if (tier is! String || ml is! num) continue;
      tiers.add(PreRunFluidTier(tier: tier, fluidMl: ml.toDouble()));
    }
    return tiers;
  }

  /// Reads the per-feeding carbohydrate split. Missing or malformed → `null`.
  static List<PreRunCarbTier>? carbTiersFrom(dynamic raw) {
    if (raw is! List) return null;
    final tiers = <PreRunCarbTier>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final tier = entry['tier'];
      final carbs = entry['carbs_g'] ?? entry['carbsG'];
      if (tier is! String || carbs is! num) continue;
      final low = entry['range_low_g'] ?? entry['rangeLowG'];
      final high = entry['range_high_g'] ?? entry['rangeHighG'];
      final composition = entry['composition'];
      tiers.add(
        PreRunCarbTier(
          tier: tier,
          carbsG: carbs.toDouble(),
          rangeLowG: low is num ? low.toDouble() : carbs.toDouble() * 0.875,
          rangeHighG: high is num ? high.toDouble() : carbs.toDouble() * 1.125,
          composition: composition is String ? composition : tier,
        ),
      );
    }
    return tiers;
  }

  static int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
