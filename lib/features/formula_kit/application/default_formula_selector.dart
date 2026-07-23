import 'dart:convert';

import '../../../shared/database/app_database.dart';

/// A phase-agnostic candidate system formula for default-formula selection.
///
/// Built from a local Drift template entry via [fromDuring] / [fromPost].
/// The selection mirrors the server-side `selectDefaultFormula` (see
/// `supabase/functions/_shared/nutrition/default-formula.ts`): filter by
/// activity + diet + allergens (safety), then pick the highest
/// `selection_priority` (tie → lower `template_number`).
class DefaultFormulaCandidate {
  const DefaultFormulaCandidate({
    required this.id,
    required this.templateNumber,
    required this.activityTypes,
    required this.allergens,
    required this.excludedDiets,
    required this.selectionPriority,
    required this.isActive,
    this.emptyActivityIsUniversal = false,
  });

  final String id;
  final int templateNumber;
  final List<String> activityTypes;
  final List<String> allergens;
  final List<String> excludedDiets;
  final int selectionPriority;
  final bool isActive;

  /// Post templates treat an empty `activity_types` as "applies to all"
  /// (mirrors `selectPostWorkoutTemplateCandidates`). During templates do not.
  final bool emptyActivityIsUniversal;

  static DefaultFormulaCandidate fromDuring(DuringWorkoutTemplateEntry e) {
    return DefaultFormulaCandidate(
      id: e.id,
      templateNumber: e.templateNumber,
      activityTypes: _decodeStringList(e.activityTypes),
      allergens: _decodeStringList(e.allergens),
      excludedDiets: _decodeStringList(e.excludedDiets),
      selectionPriority: e.selectionPriority,
      isActive: e.isActive,
    );
  }

  static DefaultFormulaCandidate fromPost(PostWorkoutTemplateEntry e) {
    return DefaultFormulaCandidate(
      id: e.id,
      templateNumber: e.templateNumber,
      activityTypes: _decodeStringList(e.activityTypes),
      allergens: _decodeStringList(e.allergens),
      excludedDiets: _decodeStringList(e.excludedDiets),
      selectionPriority: e.selectionPriority,
      isActive: e.isActive,
      emptyActivityIsUniversal: true,
    );
  }

  static List<String> _decodeStringList(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {
      // Fall through to empty on malformed JSON.
    }
    return const [];
  }
}

/// Selects the best-fit SYSTEM formula for a phase so onboarding can seed real
/// pins for a new user's primary sport.
///
/// Mirrors the server-side selector's constraints exactly so a client-seeded
/// pin behaves the same as the server would have chosen:
///   - activity match (diet + allergens are SAFETY filters, always applied),
///   - highest `selection_priority`, tie-broken by lower `template_number`,
///   - returns null when nothing fits → onboarding simply skips that phase.
///
/// Food-availability is intentionally NOT checked here: the client doesn't
/// load the food pool at onboarding, the system templates' components live in
/// the shared catalog, and the edge honor-pin path backfills fluids/sodium.
/// A pin that can't render degrades gracefully (`pinned_template_unrenderable`
/// → solver), so best-effort selection is safe.
class DefaultFormulaSelector {
  const DefaultFormulaSelector._();

  /// Pick the best-fit candidate id for [activityType], or null.
  static String? pickBest(
    List<DefaultFormulaCandidate> candidates, {
    required String activityType,
    String? diet,
    List<String> allergies = const [],
  }) {
    final activity = activityType.toLowerCase();
    final dietLower = diet?.toLowerCase();
    final allergiesLower = allergies.map((a) => a.toLowerCase()).toSet();

    DefaultFormulaCandidate? best;
    for (final c in candidates) {
      if (!c.isActive) continue;

      // Activity overlap.
      final activitiesLower = c.activityTypes.map((a) => a.toLowerCase());
      final activityMatch =
          (c.emptyActivityIsUniversal && c.activityTypes.isEmpty) ||
          activitiesLower.contains(activity);
      if (!activityMatch) continue;

      // Diet exclusion (safety).
      if (dietLower != null && dietLower.isNotEmpty) {
        final excluded = c.excludedDiets.any(
          (d) => d.toLowerCase() == dietLower,
        );
        if (excluded) continue;
      }

      // Allergen overlap (safety).
      if (allergiesLower.isNotEmpty && c.allergens.isNotEmpty) {
        final overlaps = c.allergens.any(
          (a) => allergiesLower.contains(a.toLowerCase()),
        );
        if (overlaps) continue;
      }

      if (best == null ||
          c.selectionPriority > best.selectionPriority ||
          (c.selectionPriority == best.selectionPriority &&
              c.templateNumber < best.templateNumber)) {
        best = c;
      }
    }
    return best?.id;
  }

  /// Best-fit during-system template id for the activity, or null.
  static String? selectDuring(
    List<DuringWorkoutTemplateEntry> templates, {
    required String activityType,
    String? diet,
    List<String> allergies = const [],
  }) {
    return pickBest(
      templates.map(DefaultFormulaCandidate.fromDuring).toList(),
      activityType: activityType,
      diet: diet,
      allergies: allergies,
    );
  }

  /// Best-fit post-system template id for the activity, or null.
  static String? selectPost(
    List<PostWorkoutTemplateEntry> templates, {
    required String activityType,
    String? diet,
    List<String> allergies = const [],
  }) {
    return pickBest(
      templates.map(DefaultFormulaCandidate.fromPost).toList(),
      activityType: activityType,
      diet: diet,
      allergies: allergies,
    );
  }
}
