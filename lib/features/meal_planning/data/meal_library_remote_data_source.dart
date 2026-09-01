import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../domain/meal_context.dart';
import '../domain/meal_detail.dart';
import '../domain/meal_icon_classifier.dart';
import '../domain/meal_ref.dart';
import '../domain/meal_source.dart';
import '../domain/meal_type.dart';
import '../domain/ui_action.dart';
import '../domain/wire_record.dart';
import 'vana_action_client.dart';
import 'vana_exceptions.dart';

part 'meal_library_remote_data_source.g.dart';

@riverpod
MealLibraryRemoteDataSource mealLibraryRemoteDataSource(Ref ref) {
  final deps = ref.watch(appExternalDepsProvider);
  return MealLibraryRemoteDataSource(
    supabase: deps.supabaseClient,
    actions: ref.watch(vanaActionClientProvider),
    logger: deps.logger,
  );
}

/// One `library_pair_support` row: how many library meals pair two
/// components (the "does this combination make sense" signal).
class LibraryPairSupport {
  const LibraryPairSupport({
    required this.compA,
    required this.compB,
    required this.meals,
  });

  final String compA;
  final String compB;
  final int meals;
}

/// Online-only reads of `meal_library` (+ saved meals through
/// `search_meals`) and the app-only `vana-action` reads that wrap them.
///
/// `meal_library` is **not** mirrored in Drift (1,922 rows + pgvector;
/// search is server-side — 05 §2). Callers cache results in memory per
/// session (`keepAlive` family providers). Everything here throws on
/// failure; nothing is written locally.
class MealLibraryRemoteDataSource {
  MealLibraryRemoteDataSource({
    required SupabaseClient supabase,
    required VanaActionClient actions,
    required AppLogger logger,
  }) : _supabase = supabase,
       _actions = actions,
       _logger = logger;

  final SupabaseClient _supabase;
  final VanaActionClient _actions;
  final AppLogger _logger;

  static const _context = 'MEAL_LIBRARY_REMOTE';

  String get _userId =>
      _supabase.auth.currentUser?.id ??
      (throw const VanaUnauthenticatedException());

  // ── search_meals ───────────────────────────────────────────────────────────

  /// `search_meals(...)` — allergy/diet-filtered library + saved meals in one
  /// call. Mirrors the prototype's `searchMeals` minus the query embedding
  /// (the client never embeds; trigram search covers typed queries).
  ///
  /// [includeDisliked] should be true only when browsing (catalog), never
  /// when suggesting — a −1 vote hides the meal from suggestions.
  Future<List<MealRef>> searchMeals({
    String? query,
    MealType? mealType,
    List<MealContext>? contexts,
    bool? batch,
    bool includeSaved = true,
    int limit = 12,
    List<String>? excludeAllergens,
    String? requireDiet,
    MealKind? kind,
    bool includeDisliked = false,
    Set<String> excludeIds = const {},
  }) async {
    final params = <String, dynamic>{
      'p_user_id': _userId,
      'p_query': (query == null || query.trim().isEmpty) ? null : query.trim(),
      'p_embedding': null,
      'p_meal_type': mealType?.wire,
      'p_contexts': (contexts == null || contexts.isEmpty)
          ? null
          : contexts.map((c) => c.wire).toList(),
      'p_batch': batch,
      'p_include_saved': includeSaved,
      'p_limit': limit + excludeIds.length,
      'p_exclude_allergens':
          (excludeAllergens == null || excludeAllergens.isEmpty)
          ? null
          : excludeAllergens,
      'p_require_diet': requireDiet,
      'p_kind': kind?.wire,
      'p_include_disliked': includeDisliked,
    };

    final rows = await _supabase.rpc('search_meals', params: params);
    final out = <MealRef>[];
    for (final row in rows as List<dynamic>) {
      final map = asJsonMap(row);
      if (map == null) continue;
      final ref = rowToMealRef(map);
      if (ref == null || excludeIds.contains(ref.id)) continue;
      out.add(ref);
      if (out.length >= limit) break;
    }
    _logger.debug(
      'search_meals → ${out.length}',
      context: _context,
      data: {'query': query, 'mealType': mealType?.wire, 'kind': kind?.wire},
    );
    return out;
  }

  /// `library_pair_support(components)` — pair counts for a set of
  /// components, ascending by support (weakest pair first).
  Future<List<LibraryPairSupport>> libraryPairSupport(
    List<String> components,
  ) async {
    if (components.length < 2) return const [];
    final rows = await _supabase.rpc(
      'library_pair_support',
      params: {'p_components': components},
    );
    return [
      for (final row in rows as List<dynamic>)
        if (asJsonMap(row) case final map?)
          LibraryPairSupport(
            compA: readString(map, 'comp_a') ?? '',
            compB: readString(map, 'comp_b') ?? '',
            meals: readInt(map, 'n_meals') ?? 0,
          ),
    ];
  }

  /// `set_meal_feedback(...)` — the only sanctioned write to `meal_feedback`
  /// (its uniques are partial indexes). Returns the stored vote.
  Future<int> setMealFeedback({
    String? libraryMealId,
    String? savedMealId,
    required int vote,
    String? reason,
  }) async {
    assert((libraryMealId == null) != (savedMealId == null));
    final result = await _supabase.rpc(
      'set_meal_feedback',
      params: {
        'p_library_meal_id': libraryMealId,
        'p_saved_meal_id': savedMealId,
        'p_vote': vote,
        'p_reason': reason,
      },
    );
    return (result as num?)?.toInt() ?? vote;
  }

  // ── vana-action reads ──────────────────────────────────────────────────────

  /// `get_meal{id}` — a library id (`D-048`) or a saved-meal uuid.
  Future<MealDetail> getMeal(String id) async {
    final result = await _actions.run(GetMealAction(id: id));
    final detail = result.mealDetail;
    if (detail == null) {
      throw VanaServerException(200, '', error: 'meal_not_found');
    }
    return detail;
  }

  /// `recent_meals{limit}` — the server's union of logs + plan meals resolved
  /// to [MealRef]s (server caps at 200).
  Future<List<RecentMeal>> recentMeals({int limit = 20}) async {
    final result = await _actions.run(RecentMealsAction(limit: limit));
    return result.recentMeals;
  }

  // ── Row mapping ────────────────────────────────────────────────────────────

  /// Port of `rowToMealRef` (`_shared/vana/meals.ts`) for the snake_case
  /// `search_meals` row. Returns null when the row has no id/name/type.
  static MealRef? rowToMealRef(Map<String, dynamic> r) {
    final id = r['id']?.toString();
    final name = readString(r, 'name');
    final mealType = MealType.fromWire(readString(r, 'meal_type'));
    final source = MealSource.fromWire(readString(r, 'source'));
    if (id == null || name == null || mealType == null || source == null) {
      return null;
    }
    final attribution =
        readString(r, 'attribution') ?? readString(r, 'source_text') ?? '';
    final ingredients = readString(r, 'ingredients') ?? '';
    final pattern = readString(r, 'pattern');
    return MealRef(
      source: source,
      id: id,
      name: name,
      mealType: mealType,
      contexts: MealContext.listFromWire(readStringList(r, 'contexts')),
      batch: readBool(r, 'batch') ?? false,
      prepMinutes: readInt(r, 'prep_minutes'),
      kcal: readInt(r, 'kcal'),
      carbsG: readDouble(r, 'carbs_g'),
      proteinG: readDouble(r, 'protein_g'),
      fatG: readDouble(r, 'fat_g'),
      allergens: readStringList(r, 'allergens'),
      dietsOk: readStringList(r, 'diets_ok'),
      swaps: readString(r, 'swaps'),
      why: readString(r, 'why') ?? '',
      attribution: attribution,
      attributionShort:
          readString(r, 'attribution_short') ?? attributionShort(attribution),
      ingredients: ingredients,
      libraryMealId:
          readString(r, 'library_meal_id') ??
          (source == MealSource.library ? id : null),
      score: readDouble(r, 'score') ?? 0,
      kind: MealKind.fromWire(readString(r, 'kind')),
      pattern: pattern,
      frequency: readString(r, 'frequency'),
      icon: MealIconClassifier.resolve(
        readString(r, 'icon'),
        name: name,
        ingredients: ingredients,
        pattern: pattern,
      ),
      myVote: readInt(r, 'my_vote') ?? 0,
    );
  }

  static final RegExp _splitRe = RegExp(r'\s+—\s+|;|\s+\(|https?://');
  static final RegExp _leadRe = RegExp(
    r'^(reported|commonly reported|the|a)\s+',
    caseSensitive: false,
  );
  static final RegExp _possessiveRe = RegExp(
    r"'s\s+(stated|reported|fixed|regular|race-day|daily|actual|pre-race|post-stage)\s.*$",
    caseSensitive: false,
  );
  static final RegExp _statedRe = RegExp(
    r'\s+(stated|reported)\s.*$',
    caseSensitive: false,
  );

  /// Port of `attributionShort()`: the first named person/source, ≤40 chars.
  static String attributionShort(String? full) {
    if (full == null || full.isEmpty) return '';
    var s = full.split(_splitRe).first.trim();
    s = s
        .replaceFirst(_leadRe, '')
        .replaceFirst(_possessiveRe, '')
        .replaceFirst(_statedRe, '');
    if (s.length > 40) {
      s = '${s.substring(0, 38).replaceFirst(RegExp(r'\s+\S*$'), '')}…';
    }
    return s;
  }
}
