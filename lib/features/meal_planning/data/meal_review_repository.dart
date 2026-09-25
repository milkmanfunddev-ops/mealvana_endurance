import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/app_external_deps.dart';
import '../domain/meal_source.dart';
import 'vana_exceptions.dart';

part 'meal_review_repository.g.dart';

@riverpod
MealReviewRepository mealReviewRepository(Ref ref) => MealReviewRepository(
  supabase: ref.watch(appExternalDepsProvider).supabaseClient,
);

/// One admin verdict on a meal, as the `meal_reviews` row carries it.
class MealReview {
  const MealReview({
    required this.mealSource,
    required this.mealId,
    required this.mealName,
    required this.isGood,
    required this.why,
    this.appVersion,
  });

  final MealSource mealSource;
  final String mealId;
  final String mealName;
  final bool isGood;
  final String why;

  /// The build that sent the review, `version+build` (Finding 89-014: the
  /// column was always empty). Null when the platform cannot say.
  final String? appVersion;

  /// `meal_reviews` insert body; `reviewer_id` is stamped by the repository.
  Map<String, dynamic> toRow(String reviewerId) => {
    'reviewer_id': reviewerId,
    'meal_source': mealSource.wire,
    'meal_id': mealId,
    'meal_name': mealName,
    'is_good': isGood,
    'why': why,
    'app_version': appVersion,
  };
}

/// Writes admin reviews to `meal_reviews` (mp-144 clause 3). Remote-ack,
/// never local-first: the team reads these cross-user, so success is only
/// reported once the server has the row. RLS refuses non-admins; the
/// PostgREST error propagates to the caller.
class MealReviewRepository {
  MealReviewRepository({required SupabaseClient supabase})
    : _supabase = supabase;

  final SupabaseClient _supabase;

  /// Inserts one review and returns the new row's id once the server acks.
  Future<String> addReview(MealReview review) async {
    final reviewerId =
        _supabase.auth.currentUser?.id ??
        (throw const VanaUnauthenticatedException());
    final row = await _supabase
        .from('meal_reviews')
        .insert(review.toRow(reviewerId))
        .select('id')
        .single();
    return row['id'] as String;
  }
}
