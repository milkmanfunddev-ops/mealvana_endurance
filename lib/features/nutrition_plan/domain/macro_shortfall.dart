/// A macro target the algorithm could not satisfy because viable foods were
/// filtered out by the user's preferences (dislikes, allergens, diet
/// exclusions). Surfaced to the UI as guidance instead of a silent zero or
/// a forced-disliked food. Issues #14 and #15.
///
/// Mirrors the edge-function shape (PreWorkoutShortfall, PhaseShortfall,
/// SubPhaseShortfall) so deserialization is a 1:1 mapping. Added in 2026-05-06
/// to give picky / restricted athletes (vegan + GF, dislikes-heavy users) a
/// clear gap explanation rather than an empty plan.
class MacroShortfall {
  const MacroShortfall({
    required this.macro,
    required this.delivered,
    required this.target,
    required this.unit,
    required this.reason,
  });

  /// Which macro fell short.
  final ShortfallMacro macro;

  /// What the algorithm actually delivered for this phase.
  final num delivered;

  /// What the target was for this phase.
  final num target;

  /// Display unit for delivered/target ('g', 'mg', 'ml').
  final String unit;

  /// Why this shortfall occurred — drives the guidance copy.
  final ShortfallReason reason;

  /// The gap (target − delivered), never negative.
  num get gap => target > delivered ? target - delivered : 0;

  factory MacroShortfall.fromJson(Map<String, dynamic> json) {
    return MacroShortfall(
      macro: _parseMacro(json['macro'] as String?),
      delivered: (json['delivered'] as num?) ?? 0,
      target: (json['target'] as num?) ?? 0,
      unit: (json['unit'] as String?) ?? 'g',
      reason: _parseReason(json['reason'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    'macro': macro.wireValue,
    'delivered': delivered,
    'target': target,
    'unit': unit,
    'reason': reason.wireValue,
  };

  static ShortfallMacro _parseMacro(String? raw) {
    switch (raw) {
      case 'sodium':
        return ShortfallMacro.sodium;
      case 'fluid':
        return ShortfallMacro.fluid;
      case 'protein':
        return ShortfallMacro.protein;
      case 'caffeine':
        return ShortfallMacro.caffeine;
      case 'carbs':
      default:
        return ShortfallMacro.carbs;
    }
  }

  static ShortfallReason _parseReason(String? raw) {
    switch (raw) {
      case 'no_diet_match':
        return ShortfallReason.noDietMatch;
      case 'all_templates_filtered':
        return ShortfallReason.allTemplatesFiltered;
      case 'template_constraint':
        return ShortfallReason.templateConstraint;
      case 'all_disliked':
      default:
        return ShortfallReason.allDisliked;
    }
  }
}

enum ShortfallMacro {
  carbs('carbs'),
  sodium('sodium'),
  fluid('fluid'),
  protein('protein'),
  caffeine('caffeine');

  const ShortfallMacro(this.wireValue);
  final String wireValue;

  /// Human-readable label used in copy.
  String get label {
    switch (this) {
      case ShortfallMacro.carbs:
        return 'carbs';
      case ShortfallMacro.sodium:
        return 'sodium';
      case ShortfallMacro.fluid:
        return 'fluids';
      case ShortfallMacro.protein:
        return 'protein';
      case ShortfallMacro.caffeine:
        return 'caffeine';
    }
  }
}

enum ShortfallReason {
  allDisliked('all_disliked'),
  noDietMatch('no_diet_match'),
  allTemplatesFiltered('all_templates_filtered'),

  /// The chosen template/formula physically can't meet the target within its
  /// ingredient constraints (e.g. a pinned drink-only formula capped by
  /// max-servings-per-hour on a short run). Not a preference problem.
  templateConstraint('template_constraint');

  const ShortfallReason(this.wireValue);
  final String wireValue;
}
