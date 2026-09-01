/// VanaActionClient: request shape, result parsing from the contract
/// fixtures, and the shared error mapping.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';

import '../domain/fixture_helpers.dart';
import '../helpers/fakes.dart';

VanaActionClient _client(TransportHarness h) =>
    VanaActionClient(transport: h.transport, logger: h.logger);

void main() {
  test('pick_meals posts {type, payload} and folds the batch part', () async {
    final h = TransportHarness(
      status: 200,
      body: jsonEncode(loadFixture('batch')),
    );

    final result = await _client(h).run(
      const PickMealsAction(
        meals: [MealPick(source: MealSource.library, id: 'D-048')],
        servings: 4,
        conversationId: 'conv-1',
      ),
    );

    expect(h.requests.single.path, '/functions/v1/vana-action');
    expect(h.requests.single.body, {
      'type': 'pick_meals',
      'payload': {
        'conversationId': 'conv-1',
        'meals': [
          {'source': 'library', 'id': 'D-048'},
        ],
        'servings': 4,
      },
    });
    expect(result.parts.single, isA<VanaBatchPart>());
    expect(result.plan, isNotNull);
    expect(result.plan!.id, '588c137e-826c-46d4-8a73-f57b1a3d4143');
    expect(result.extras, isEmpty);
  });

  test('confirm_plan returns batch + shopping_list parts', () async {
    final h = TransportHarness(
      status: 200,
      body: jsonEncode(loadFixture('confirm_plan')),
    );
    final result = await _client(h).run(const ConfirmPlanAction());
    expect(result.plan!.isConfirmed, isTrue);
    expect(
      result.parts.whereType<VanaShoppingListPart>().single.items,
      isNotEmpty,
    );
  });

  test('get_home exposes the home payload and its batch', () async {
    final h = TransportHarness(
      status: 200,
      body: jsonEncode(loadFixture('home')),
    );
    final result = await _client(
      h,
    ).run(const GetHomeAction(date: '2026-09-01'));
    expect(h.requests.single.body['payload'], {'date': '2026-09-01'});
    final home = result.home;
    expect(home, isNotNull);
    expect(home!.batch, isNotNull);
    expect(result.plan, home.batch!.plan);
  });

  test('get_meal → mealDetail; recent_meals → recentMeals', () async {
    final meal = TransportHarness(
      status: 200,
      body: jsonEncode(loadFixture('meal_detail')),
    );
    final detail = (await _client(
      meal,
    ).run(const GetMealAction(id: 'D-048'))).mealDetail;
    expect(detail, isNotNull);
    expect(detail!.meal.id, 'D-048');
    expect(detail.methodSteps, isNotEmpty);

    final recent = TransportHarness(
      status: 200,
      body: jsonEncode(loadFixture('recent_meals')),
    );
    final meals = (await _client(
      recent,
    ).run(const RecentMealsAction(limit: 20))).recentMeals;
    expect(meals, isNotEmpty);
    expect(meals.first.meal.id, 'AD-105');
  });

  test('extras accessors: vote / notes / logId / memories', () async {
    final h = TransportHarness(
      status: 200,
      body: jsonEncode({
        'parts': [],
        'vote': -1,
        'notes': 'my way',
        'logId': 'log-1',
        'memories': [
          {
            'id': 'mem-1',
            'kind': 'preference',
            'key': null,
            'fact': 'Likes oats',
            'value': null,
            'confidence': 0.9,
            'lastConfirmedAt': '2026-09-01T12:00:00Z',
          },
        ],
      }),
    );
    final result = await _client(
      h,
    ).run(const SetMealFeedbackAction(libraryMealId: 'D-048', vote: -1));
    expect(result.vote, -1);
    expect(result.notes, 'my way');
    expect(result.logId, 'log-1');
    expect(result.memories.single.fact, 'Likes oats');
  });

  test('error mapping: 403 / 429 / 400 / offline', () async {
    expect(
      () => _client(
        TransportHarness(status: 403, body: '{"error":"pro_required"}'),
      ).run(const ListPlansAction()),
      throwsA(isA<ProRequiredException>()),
    );
    expect(
      () => _client(
        TransportHarness(
          status: 429,
          body: '{"error":"rate_limited","retry_after_seconds":3}',
        ),
      ).run(const ListPlansAction()),
      throwsA(
        isA<VanaRateLimitedException>().having(
          (e) => e.retryAfterSeconds,
          'retry',
          3,
        ),
      ),
    );
    expect(
      () => _client(
        TransportHarness(status: 400, body: '{"error":"plan meal not found"}'),
      ).run(const RemoveMealAction(planMealId: 'x')),
      throwsA(
        isA<VanaServerException>().having(
          (e) => e.error,
          'error',
          'plan meal not found',
        ),
      ),
    );
    expect(
      () => _client(
        TransportHarness(status: 200, body: '', throwOnSend: Exception('down')),
      ).run(const ListPlansAction()),
      throwsA(isA<VanaOfflineException>()),
    );
  });

  test('a non-object 200 body is a VanaServerException', () async {
    expect(
      () => _client(
        TransportHarness(status: 200, body: '[]'),
      ).run(const ListPlansAction()),
      throwsA(
        isA<VanaServerException>().having(
          (e) => e.error,
          'error',
          'invalid_response',
        ),
      ),
    );
  });
}
