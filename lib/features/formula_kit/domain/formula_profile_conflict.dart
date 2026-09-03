/// Profile-conflict model + copy for the formula-pin surface.
///
/// Spec: `docs/ssot/spec/design/components/formula-pin-surface.md`
/// (RATIFIED Xuan, 2026-09-03) — FP-4a pre-pin warning, FP-4b post-pin label,
/// FP-7 detail DIETARY emphasis, FP-8 authoring save-time disclosure.
/// Policy: `food-recommendation.md` §1/§1a — pins are honored
/// unconditionally; conflicts are LABELED, never blocked.
///
/// The allergy-conflict gate is the ratified §1a kernel
/// [pinConflictLabelRequired] (imported, never re-implemented). This file
/// only adds the diet-exclusion check, the allergy-precedence rule, and the
/// human copy the FP rows pin verbatim.
library;

import '../../nutrition_plan/domain/selection_precedence.dart'
    show pinConflictLabelRequired;
import '../../onboarding/domain/allergy.dart';
import '../../onboarding/domain/dietary_preference.dart';
import 'formula_macros.dart';

/// The slice of the athlete's profile the conflict checks read: allergy and
/// diet db values, as stored on `users.allergies` / `users.dietary_preference`.
class AthleteConflictProfile {
  const AthleteConflictProfile({
    this.allergyDbValues = const [],
    this.dietDbValue,
  });

  /// e.g. `['gluten', 'tree_nuts']`.
  final List<String> allergyDbValues;

  /// e.g. `'keto'`. Null (or `'none'`, normalized by the provider) means no
  /// diet constraint.
  final String? dietDbValue;

  static const empty = AthleteConflictProfile();
}

enum FormulaConflictKind { allergy, diet }

/// One labeled conflict between a formula and the athlete's profile.
/// Allergy takes precedence when both kinds conflict (FP-4a).
class FormulaProfileConflict {
  const FormulaProfileConflict.allergy(String this.allergenDbValue)
    : kind = FormulaConflictKind.allergy,
      dietDbValue = null;

  const FormulaProfileConflict.diet(String this.dietDbValue)
    : kind = FormulaConflictKind.diet,
      allergenDbValue = null;

  final FormulaConflictKind kind;

  /// The conflicting allergen's db value (allergy kind only).
  final String? allergenDbValue;

  /// The athlete's diet db value the formula excludes (diet kind only).
  final String? dietDbValue;

  /// Human, lowercase allergen — "gluten", "tree nuts".
  String get allergenDisplay => humanAllergen(allergenDbValue ?? '');

  /// Human, lowercase diet — "keto", "low-carb".
  String get dietDisplay => humanDietLower(dietDbValue ?? '');
}

/// Evaluate a formula's allergen/diet metadata against the profile.
/// Returns null when nothing conflicts. Allergy beats diet (FP-4a).
FormulaProfileConflict? evaluateFormulaProfileConflict({
  required List<String> templateAllergens,
  required List<String> excludedDiets,
  required AthleteConflictProfile profile,
}) {
  // §1a kernel is the authority on whether an allergy label is required.
  if (pinConflictLabelRequired(templateAllergens, profile.allergyDbValues)) {
    final athlete = profile.allergyDbValues
        .map((a) => a.toLowerCase())
        .toSet();
    final matched = templateAllergens.firstWhere(
      (a) => athlete.contains(a.toLowerCase()),
    );
    return FormulaProfileConflict.allergy(matched);
  }
  final diet = profile.dietDbValue;
  if (diet != null &&
      excludedDiets.any((d) => d.toLowerCase() == diet.toLowerCase())) {
    return FormulaProfileConflict.diet(diet);
  }
  return null;
}

/// First component of a personal-formula draft that conflicts with the
/// profile (FP-8). Components snapshot their food's allergen / excluded-diet
/// db values at add time ([FormulaMacros.kAllergens] /
/// [FormulaMacros.kExcludedDiets]); legacy components without the keys are
/// treated as conflict-free.
({String foodName, FormulaProfileConflict conflict})? firstComponentConflict(
  List<Map<String, dynamic>> components,
  AthleteConflictProfile profile,
) {
  List<String> strings(Object? v) =>
      v is List ? v.map((e) => e.toString()).toList(growable: false) : const [];
  // Allergy conflicts outrank diet conflicts across the whole formula.
  for (final c in components) {
    final conflict = evaluateFormulaProfileConflict(
      templateAllergens: strings(c[FormulaMacros.kAllergens]),
      excludedDiets: const [],
      profile: profile,
    );
    if (conflict != null) {
      return (foodName: FormulaMacros.nameOf(c), conflict: conflict);
    }
  }
  for (final c in components) {
    final conflict = evaluateFormulaProfileConflict(
      templateAllergens: const [],
      excludedDiets: strings(c[FormulaMacros.kExcludedDiets]),
      profile: profile,
    );
    if (conflict != null) {
      return (foodName: FormulaMacros.nameOf(c), conflict: conflict);
    }
  }
  return null;
}

// ── Human copy (verbatim from the FP rows) ─────────────────────────────────

/// "gluten", "tree nuts" — via the [Allergy] display name when the db value
/// is a known enum, else underscores → spaces (never a machine string, FP-7).
String humanAllergen(String dbValue) {
  final known = Allergy.fromDbValue(dbValue);
  if (known != null) return known.displayName.toLowerCase();
  return dbValue.replaceAll('_', ' ').toLowerCase();
}

/// "Keto", "Low-Carb", "Gluten Free" — capitalized diet name for the FP-7
/// "Not Keto" chip (no machine strings like `gluten_free`).
String humanDietTitle(String dbValue) {
  final known = DietaryPreference.fromDbValue(dbValue);
  if (known != null) return known.displayName;
  return dbValue
      .split('_')
      .where((s) => s.isNotEmpty)
      .map((s) => '${s[0].toUpperCase()}${s.substring(1)}')
      .join(' ');
}

/// "keto", "low-carb" — lowercase diet name for the softer one-line notes.
String humanDietLower(String dbValue) => humanDietTitle(dbValue).toLowerCase();

/// FP-4a allergy warning (full, naming the allergen).
String pinAllergyWarningText(String allergenDisplay) =>
    'This formula contains $allergenDisplay, which you\'ve listed as an '
    'allergy. Pinning it means Mealvana will always include it.';

/// FP-4a / FP-8 diet one-liner (softer, no action pair — R-02 option 1).
String dietConflictNoteText(String dietDisplay) =>
    'Doesn\'t match your $dietDisplay preference.';

/// FP-4b collapsed label line.
String conflictLabelCollapsedText(FormulaProfileConflict conflict) =>
    conflict.kind == FormulaConflictKind.allergy
    ? 'Pinned despite your ${conflict.allergenDisplay} allergy'
    : 'Pinned despite your ${conflict.dietDisplay} preference';

/// FP-4b expanded policy sentence — pins are never auto-removed when the
/// profile changes; this label is presentation only.
const String pinPolicySentence =
    'Pins always win: this formula stays in your plans even though it '
    'conflicts with the profile you added later.';

/// FP-8 closing sentence (exact — the conformance suite pins it).
const String saveDisclosureClosingSentence =
    'You can still save — Mealvana will always include your own formulas.';

/// FP-8 allergy disclosure: names the food and the allergen, ends with
/// [saveDisclosureClosingSentence] exactly.
String saveAllergyDisclosureText(String foodName, String allergenDisplay) =>
    '“$foodName” contains $allergenDisplay, which you\'ve listed as an '
    'allergy. $saveDisclosureClosingSentence';
