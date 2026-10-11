import 'dart:async';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/database/app_database.dart' hide CarbLoadingFood;
import '../../../shared/database/database_provider.dart';
import '../../../shared/providers/user_id_provider.dart';
import '../../../shared/services/report/report.dart';
import '../../../shared/utils/search_token_matcher.dart';
import '../../meal_logging/domain/meal_component.dart';
// The plain Provider<FoodRepository>; a differently-typed generated
// `foodRepositoryProvider` also exists elsewhere, hence the explicit `show`.
import '../../nutrition_plan/data/food_repository.dart'
    show FoodRepository, foodRepositoryProvider;
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
///
/// Two passes, in order: the exact normalized-name pass (G26) and then the
/// token pass (G25). [exactOnly] stops after the first — the provider uses
/// it to tell "the row is missing from the mirror" apart from "the token
/// pass found a sibling", so a curated row whose exact food was seeded
/// server-side AFTER this device's first sync triggers a catalog re-sync
/// instead of silently landing on a wrong food ('Rice' → 'Rice pudding').
Future<CarbFoodResolution?> resolveCarbRecommendation(
  AppDatabase database,
  String query, {
  bool exactOnly = false,
}) async {
  final tokens = tokenizeSearchQuery(query);
  if (tokens.isEmpty) return null;
  final rows = await (database.select(
    database.foodsTable,
  )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  // Exact name match wins outright (G26): with sibling rows in the mirror
  // ('Beets' vs 'Beet juice', 'Rice' vs 'Rice pudding') the token pass's
  // name-asc scan would land 'Beets' on 'Beet juice' via the singular
  // fallback. Search UX ranks exact hits first; the one-tap resolver must
  // match that.
  final normalizedQuery = normalizeSearchText(query);
  final ordered = [
    ...rows.where((f) => normalizeSearchText(f.name ?? '') == normalizedQuery),
    if (!exactOnly) ...rows,
  ];
  for (final food in ordered) {
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
///
/// Exact hit → done. Otherwise the mirror may simply predate a server-side
/// catalog seed (the `foods` sync only ever runs on an EMPTY mirror), so
/// re-sync the catalog once ([FoodRepository.refreshAfterMiss], throttled)
/// and run the FULL resolver again. Offline, throttled, or no signed-in
/// user → the refresh is a no-op and the full resolver (exact then token,
/// the ratified G25/G26 behaviour) still runs exactly once, so nothing
/// regresses: the token pass stays the fallback, and null still hands off
/// to search.
@riverpod
Future<CarbFoodResolution?> carbRecommendationResolution(
  Ref ref,
  String query,
) async {
  final database = ref.watch(appDatabaseProvider);
  // Everything `ref` must hand over is taken BEFORE the first await. This
  // provider is autoDispose and the slot page only `read`s it, so once the
  // mirror query yields to the event loop the element is already scheduled
  // for disposal and any later `ref.read` throws "Ref used after dispose".
  // The first cut read them after the await inside the catch-all below, so
  // on a device (background-isolate Drift) the refresh silently never ran
  // (simulator, 2026-10-07); the in-memory test database answered within
  // microtasks and hid it. Nothing below touches `ref` again.
  final report = ref.read(reportProvider);
  Future<String>? userIdFuture;
  FoodRepository? foodRepository;
  try {
    final pending = ref.read(userIdProvider.future);
    pending.ignore();
    userIdFuture = pending;
    foodRepository = ref.read(foodRepositoryProvider);
  } catch (e) {
    // Nothing wired behind them (no auth, no external deps in this scope):
    // the mirror is all there is, resolve against it as-is.
    unawaited(
      report.note(
        'Carb resolver has no user or food repository; mirror only',
        area: 'carb_loading',
        data: {'error': e.toString()},
      ),
    );
  }
  final exact = await resolveCarbRecommendation(
    database,
    query,
    exactOnly: true,
  );
  if (exact != null) return exact;

  if (userIdFuture != null && foodRepository != null) {
    try {
      final userId = await userIdFuture;
      await foodRepository.refreshAfterMiss(userId);
    } catch (e, stackTrace) {
      // No user profile yet, or a refresh failure the repository did not
      // swallow: the local mirror is untouched, resolve against it as-is.
      unawaited(
        report.degraded(
          e,
          stackTrace: stackTrace,
          area: 'carb_loading',
          message: 'Catalog refresh after a carb-resolution miss failed',
        ),
      );
    }
  }
  return resolveCarbRecommendation(database, query);
}
