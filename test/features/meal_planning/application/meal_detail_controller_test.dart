/// MealDetailController.review — the admin review write path (mp-144
/// clause 3) through the real notifier: one `meal_reviews` row per send,
/// remote-ack only, failure rethrown for the screen to show.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_detail_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_review_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_detail.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/shared/providers/app_version_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/container.dart';
import '../helpers/fakes.dart';

/// Records every insert instead of calling PostgREST; [failWith] makes the
/// next insert throw the way a refused RLS policy or a dropped network would.
class _RecordingReviewRepository implements MealReviewRepository {
  final List<Map<String, dynamic>> rows = [];
  Object? failWith;

  @override
  Future<String> addReview(MealReview review) async {
    final error = failWith;
    if (error != null) throw error;
    rows.add(review.toRow('user-1'));
    return 'review-${rows.length}';
  }
}

class _SeededDetailController extends MealDetailController {
  _SeededDetailController(this._seed);
  final MealDetail? _seed;

  @override
  FutureOr<MealDetail> build(String id) {
    final seed = _seed;
    if (seed == null) throw StateError('meal_not_found');
    return seed;
  }
}

MealDetail _detail({MealSource source = MealSource.library, String? id}) =>
    MealDetail(
      meal: MealRef(
        source: source,
        id: id ?? (source == MealSource.saved ? 'saved-uuid-1' : 'D-048'),
        name: 'Marathon Bolognese over pasta',
        mealType: MealType.dinner,
        kcal: 700,
      ),
      directions: const MealDirections(),
      servings: 4,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingReviewRepository reviews;
  late FakeLogger logger;

  ProviderContainer containerFor(MealDetail? seed, String id) {
    reviews = _RecordingReviewRepository();
    logger = FakeLogger();
    return testContainer([
      ...baseOverrides(logger: logger),
      mealReviewRepositoryProvider.overrideWithValue(reviews),
      appVersionProvider.overrideWith((ref) async => '1.27.1+4'),
      mealDetailControllerProvider(
        id,
      ).overrideWith(() => _SeededDetailController(seed)),
    ]);
  }

  test('a review writes one meal_reviews row shaped for the insert', () async {
    final container = containerFor(_detail(), 'D-048');
    await container.read(mealDetailControllerProvider('D-048').future);

    await container
        .read(mealDetailControllerProvider('D-048').notifier)
        .review(isGood: false, why: '  Too much sauce for the pasta.  ');

    expect(reviews.rows, hasLength(1));
    expect(reviews.rows.single, {
      'reviewer_id': 'user-1',
      'meal_source': 'library',
      'meal_id': 'D-048',
      'meal_name': 'Marathon Bolognese over pasta',
      'is_good': false,
      'why': 'Too much sauce for the pasta.',
      // Ticket 130 (Finding 89-014): the build that sent it, as Sentry
      // reads it (version+build).
      'app_version': '1.27.1+4',
    });
    // The detail state is untouched — the review is not part of the meal.
    final after = container.read(mealDetailControllerProvider('D-048')).value;
    expect(after?.vote, 0);
    expect(logger.warnings, isEmpty);
  });

  test(
    'a saved meal is reviewed under its uuid and the saved source',
    () async {
      final container = containerFor(
        _detail(source: MealSource.saved),
        'saved-uuid-1',
      );
      await container.read(mealDetailControllerProvider('saved-uuid-1').future);

      await container
          .read(mealDetailControllerProvider('saved-uuid-1').notifier)
          .review(isGood: true, why: 'Reheats well.');

      expect(reviews.rows.single['meal_source'], 'saved');
      expect(reviews.rows.single['meal_id'], 'saved-uuid-1');
      expect(reviews.rows.single['is_good'], true);
    },
  );

  test('an empty why sends nothing', () async {
    final container = containerFor(_detail(), 'D-048');
    await container.read(mealDetailControllerProvider('D-048').future);

    await container
        .read(mealDetailControllerProvider('D-048').notifier)
        .review(isGood: true, why: '   ');

    expect(reviews.rows, isEmpty);
  });

  test('why is capped at the column limit (2000)', () async {
    final container = containerFor(_detail(), 'D-048');
    await container.read(mealDetailControllerProvider('D-048').future);

    await container
        .read(mealDetailControllerProvider('D-048').notifier)
        .review(isGood: true, why: 'x' * 2500);

    expect((reviews.rows.single['why'] as String).length, 2000);
  });

  test('a refused insert (RLS: not an admin) rethrows and logs', () async {
    final container = containerFor(_detail(), 'D-048');
    await container.read(mealDetailControllerProvider('D-048').future);
    reviews.failWith = const PostgrestException(
      message:
          'new row violates row-level security policy for table "meal_reviews"',
      code: '42501',
    );

    await expectLater(
      container
          .read(mealDetailControllerProvider('D-048').notifier)
          .review(isGood: true, why: 'Great.'),
      throwsA(isA<PostgrestException>()),
    );

    expect(reviews.rows, isEmpty);
    expect(logger.warnings, ['meal_reviews insert failed']);
    // Nothing was reported as sent and the meal is still there.
    expect(
      container.read(mealDetailControllerProvider('D-048')).hasValue,
      isTrue,
    );
  });
}
