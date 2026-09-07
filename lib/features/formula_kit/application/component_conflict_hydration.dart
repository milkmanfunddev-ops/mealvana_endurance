import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../nutrition_plan/data/template_foods_repository.dart';
import '../domain/formula_macros.dart';
import 'formula_conflict_json.dart';

/// Refresh `kAllergens`/`kExcludedDiets` on persisted formula components
/// from the live `template_foods` catalog (FP-8 implementation note,
/// AMENDED 2026-09-03).
///
/// The catalog is the source of TRUTH for catalog-backed components: rows
/// persisted before the metadata fixes carry either no keys (old forks) or
/// stale empty lists (old Add Food saves) — both previously defeated the
/// conflict detector, so presence of a key is not trustworthy. Components
/// whose food id has no catalog row (user foods) keep their snapshot.
///
/// Returns fresh maps; never mutates the input.
Future<List<Map<String, dynamic>>> hydrateComponentConflictMetadata(
  Ref ref,
  List<Map<String, dynamic>> components,
) async {
  if (components.isEmpty) return components;
  final templateFoods = await ref
      .read(templateFoodsRepositoryProvider)
      .getAllTemplateFoods();
  final byId = {for (final tf in templateFoods) tf.id: tf};

  return [
    for (final c in components)
      () {
        final tf = byId[c[FormulaMacros.kFoodId]];
        if (tf == null) return Map<String, dynamic>.from(c);
        return Map<String, dynamic>.from(c)
          ..[FormulaMacros.kAllergens] = decodeDbStringArray(tf.allergens)
          ..[FormulaMacros.kExcludedDiets] = decodeDbStringArray(
            tf.excludedDiets,
          );
      }(),
  ];
}
