import 'package:supabase_flutter/supabase_flutter.dart';

/// The remote half of [MealPlanRepository] — the Supabase calls it makes when
/// replaying local-first edits and pulling the user's plans. An interface so
/// repository tests can record the exact RPC / payload each edit turns into
/// without a Supabase client.
///
/// Every write here targets a row the user already owns (RLS
/// `user_id = auth.uid()`); rows are only ever *created* through
/// `vana-action` (remote-ack).
abstract class MealPlanRemote {
  /// Non-deleted, non-archived `meal_plans` rows for [userId].
  Future<List<Map<String, dynamic>>> fetchPlans(String userId);

  /// `plan_meals` rows for [planIds] (server has no tombstones — a missing
  /// row is a deleted row).
  Future<List<Map<String, dynamic>>> fetchPlanMeals(
    String userId,
    List<String> planIds,
  );

  /// `plan_remove_meal(p_plan_meal_id)`.
  Future<void> removeMeal(String planMealId);

  /// `plan_set_servings(p_plan_meal_id, p_servings)`.
  Future<void> setServings(String planMealId, int servings);

  /// `UPDATE plan_meals SET … WHERE id = …` for the fields with no RPC
  /// (`session`, `comments`, `swaps_applied`).
  Future<void> updatePlanMeal(String planMealId, Map<String, dynamic> fields);

  /// `UPDATE meal_plans SET … WHERE id = …` (`shopping`, `days`).
  Future<void> updatePlan(String planId, Map<String, dynamic> fields);
}

/// Production [MealPlanRemote] over PostgREST + the `plan_*` RPCs
/// (`docs/database/meal-planning-rpcs.md`).
class SupabaseMealPlanRemote implements MealPlanRemote {
  const SupabaseMealPlanRemote(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<List<Map<String, dynamic>>> fetchPlans(String userId) async {
    final rows = await _supabase
        .from('meal_plans')
        .select('*')
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .neq('status', 'archived')
        .order('week_start', ascending: false)
        .order('updated_at', ascending: false);
    return _maps(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPlanMeals(
    String userId,
    List<String> planIds,
  ) async {
    if (planIds.isEmpty) return const [];
    final rows = await _supabase
        .from('plan_meals')
        .select('*')
        .eq('user_id', userId)
        .inFilter('plan_id', planIds)
        .order('position')
        .order('created_at');
    return _maps(rows);
  }

  @override
  Future<void> removeMeal(String planMealId) async {
    await _supabase.rpc(
      'plan_remove_meal',
      params: {'p_plan_meal_id': planMealId},
    );
  }

  @override
  Future<void> setServings(String planMealId, int servings) async {
    await _supabase.rpc(
      'plan_set_servings',
      params: {'p_plan_meal_id': planMealId, 'p_servings': servings},
    );
  }

  @override
  Future<void> updatePlanMeal(
    String planMealId,
    Map<String, dynamic> fields,
  ) async {
    await _supabase.from('plan_meals').update(fields).eq('id', planMealId);
  }

  @override
  Future<void> updatePlan(String planId, Map<String, dynamic> fields) async {
    await _supabase.from('meal_plans').update(fields).eq('id', planId);
  }

  static List<Map<String, dynamic>> _maps(Object? rows) => [
    for (final row in rows as List<dynamic>)
      if (row is Map) Map<String, dynamic>.from(row),
  ];
}
