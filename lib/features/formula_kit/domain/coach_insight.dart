import 'dart:convert';

import 'formula_macros.dart';
import 'formula_phase.dart';

/// The draft context sent to the `ai-coach` edge function (`mode: "insight"`)
/// to get one short piece of coach-tone guidance about a personal formula.
///
/// Built in the presentation layer from the live editor draft. Carries the
/// macro-bearing component snapshots (same shape as [FormulaMacros]) so the
/// edge function can recompute totals + derived state server-side without any
/// food lookups.
class CoachInsightContext {
  const CoachInsightContext({
    required this.phase,
    required this.components,
    this.subPhase,
    this.durations,
    this.activities,
    this.name,
  });

  final FormulaPhase phase;

  /// Component maps in the [FormulaMacros] canonical shape.
  final List<Map<String, dynamic>> components;

  final String? subPhase;
  final List<String>? durations;
  final List<String>? activities;
  final String? name;

  /// Wire payload for the edge function's `context` field. Only the keys the
  /// edge function reads are sent (per-serving macros + quantity + name).
  Map<String, dynamic> toJson() {
    return {
      'phase': phase.wireValue,
      if (subPhase != null) 'sub_phase': subPhase,
      if (durations != null) 'durations': durations,
      if (activities != null) 'activities': activities,
      if (name != null && name!.trim().isNotEmpty) 'name': name!.trim(),
      'components': components
          .map((c) => <String, dynamic>{
                FormulaMacros.kFoodName: FormulaMacros.nameOf(c),
                FormulaMacros.kQuantity: FormulaMacros.quantityOf(c),
                FormulaMacros.kCarbsPerServing: c[FormulaMacros.kCarbsPerServing],
                FormulaMacros.kProteinPerServing: c[FormulaMacros.kProteinPerServing],
                FormulaMacros.kFatPerServing: c[FormulaMacros.kFatPerServing],
                FormulaMacros.kSodiumMg: c[FormulaMacros.kSodiumMg],
                FormulaMacros.kFluidMlPerServing: c[FormulaMacros.kFluidMlPerServing],
                FormulaMacros.kCaloriesPerServing: c[FormulaMacros.kCaloriesPerServing],
              })
          .toList(),
    };
  }

  /// A stable marker that changes whenever any insight-relevant field of the
  /// draft changes. The client caches `(staleMarker → insight)`; when the live
  /// draft's marker no longer matches the cached insight's marker, the panel
  /// goes "Outdated" and offers a refresh.
  ///
  /// Computed as an FNV-1a hash of a canonical projection of the draft, so it's
  /// short, deterministic, and stable across app restarts (unlike `hashCode`).
  String get staleMarker {
    final canonical = jsonEncode({
      'p': phase.wireValue,
      'sp': subPhase,
      'd': durations,
      'a': activities,
      'n': name?.trim(),
      'c': components
          .map((c) => [
                FormulaMacros.nameOf(c),
                FormulaMacros.quantityOf(c),
                c[FormulaMacros.kCarbsPerServing],
                c[FormulaMacros.kProteinPerServing],
                c[FormulaMacros.kFatPerServing],
                c[FormulaMacros.kSodiumMg],
                c[FormulaMacros.kFluidMlPerServing],
              ])
          .toList(),
    });
    return _fnv1a(canonical);
  }

  static String _fnv1a(String input) {
    // 32-bit FNV-1a — deterministic, no external dependency.
    var hash = 0x811c9dc5;
    for (final code in input.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

/// The result of a coach-insight call: the guidance text plus the draft marker
/// it was generated for, so the panel knows whether it's still current.
class CoachInsight {
  const CoachInsight({
    required this.insight,
    required this.staleMarker,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.model,
  });

  /// The coach-tone guidance sentence (~15-28 words).
  final String insight;

  /// The [CoachInsightContext.staleMarker] this insight was generated against.
  final String staleMarker;

  final int inputTokens;
  final int outputTokens;
  final String? model;

  /// Whether this insight still reflects [liveMarker].
  bool isCurrentFor(String liveMarker) => staleMarker == liveMarker;
}
