import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/database/app_database.dart' hide CarbLoadingFood;
import '../../../shared/database/database_provider.dart';
import '../../../shared/utils/search_token_matcher.dart';
import '../../meal_logging/domain/meal_component.dart';
import '../data/carb_loading_food_repository.dart';
import '../domain/carb_loading_food.dart';
import '../domain/meal_type.dart';

part 'carb_slot_recommendations.g.dart';

/// One row of the slot page's "Recommended for {slot}" section (G21-B,
/// Xuan 2026-09-25): release-1 reads the EXISTING `carb_loading_foods`
/// store — its `meal_types` are the per-slot suitability — via the shipping
/// sync path. The S9 one-store unification is D-022, deliberately deferred.
class CarbSlotRecommendation {
  const CarbSlotRecommendation({
    required this.id,
    required this.name,
    required this.subStr,
    required this.query,
  });

  /// Store row id — the row key.
  final String id;

  /// Display line, serving included: 'Cereal (1/2 cup dry)'.
  final String name;

  /// 'N g carbs per serving' — prototype-verbatim sub line.
  final String subStr;

  /// What the shipping Log-a-Meal search gets seeded with on tap: the
  /// display name without its serving parenthetical ('Cereal').
  final String query;
}

/// Curation-order + copy assembly, pure. The store has no order column, so
/// the FIXED order (ruled: deterministic, never DB-arbitrary) is the store's
/// internal curation key `name` ascending, id as the total-order tiebreak —
/// identical on every device regardless of sync arrival order.
List<CarbSlotRecommendation> assembleSlotRecommendations(
  List<CarbLoadingFood> foods,
) {
  final sorted = List<CarbLoadingFood>.of(foods)
    ..sort((a, b) {
      final byName = a.name.compareTo(b.name);
      return byName != 0 ? byName : a.id.compareTo(b.id);
    });
  return [
    for (final f in sorted)
      CarbSlotRecommendation(
        id: f.id,
        name: f.displayName,
        subStr: '${f.carbsPerServing.round()} g carbs per serving',
        query: _stripServing(f.displayName),
      ),
  ];
}

String _stripServing(String displayName) {
  final cut = displayName.indexOf('(');
  return (cut > 0 ? displayName.substring(0, cut) : displayName).trim();
}

/// The slot page's recommendation rows for one slot: the old store filtered
/// by `meal_types` suitability (getFoodsByMealType), fixed curation order.
/// Empty store or no suitable rows → empty list; the section renders its
/// empty state, never crashes (the G21-B empty-state red).
@riverpod
Future<List<CarbSlotRecommendation>> carbSlotRecommendations(
  Ref ref,
  MealType slot,
) async {
  final repository = ref.watch(carbLoadingFoodRepositoryProvider);
  final foods = await repository.getFoodsByMealType(slot.id);
  return assembleSlotRecommendations(foods);
}

/// A curated row resolved to a REAL food in the local `foods` mirror —
/// real macros, nothing invented (G25, Xuan 2026-09-25).
class CarbFoodResolution {
  const CarbFoodResolution({required this.title, required this.component});

  /// The resolved food's display title — what the committed log row is named.
  final String title;

  /// One serving of the resolved food, its stored macros verbatim.
  final MealComponent component;
}

/// G25: resolve a curated row's [CarbSlotRecommendation.query] to its real
/// food so the ⊕ one-tap-logs it slot-tagged through the ordinary meal-log
/// path ("as if it clicks on the quick adds"). Resolution runs against the
/// LOCAL `foods` mirror (offline-first; the synced reference table behind
/// the unified search's local pool) with the unified search's own matcher
/// ([tokenizeSearchQuery]/[matchesSearchTokens]) over the same fields, rows
/// in the pool's name-asc order — the first hit is the top match the search
/// would surface. Null = unresolved: the caller falls back to the search
/// handoff, and the seam test enumerates every such curated row as a data
/// finding (never a silent fallback).
Future<CarbFoodResolution?> resolveCarbRecommendation(
  AppDatabase database,
  String query,
) async {
  final tokens = tokenizeSearchQuery(query);
  if (tokens.isEmpty) return null;
  final rows =
      await (database.select(database.foodsTable)
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();
  for (final food in rows) {
    final searchText = [
      food.name,
      food.displayName,
      food.displayNamePlural,
      food.description,
      food.productTypeId,
    ].whereType<String>().join(' ');
    if (!matchesSearchTokens(searchText, tokens)) continue;
    final title = (food.name?.isNotEmpty ?? false)
        ? food.name!
        : (food.displayName ?? query);
    return CarbFoodResolution(
      title: title,
      component: MealComponent(
        name: title,
        portion: food.servingSize ?? food.displayName ?? '1 serving',
        calories: food.caloriesPerServing,
        carbG: food.carbsPerServing,
        proteinG: food.proteinPerServing,
        fatG: food.fatPerServing,
        sodiumMg: food.sodiumMg?.toDouble(),
      ),
    );
  }
  return null;
}

/// Provider face of [resolveCarbRecommendation] for the slot page's tap.
@riverpod
Future<CarbFoodResolution?> carbRecommendationResolution(
  Ref ref,
  String query,
) => resolveCarbRecommendation(ref.watch(appDatabaseProvider), query);
