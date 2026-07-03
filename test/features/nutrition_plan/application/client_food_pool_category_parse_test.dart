// Verifies the workout-phase category parser tolerates BOTH storage formats
// that legitimately occur for user_foods.categories:
//
//   1. PostgreSQL array literal  {before_run,during_run}  — locally-created rows
//   2. JSON array                ["before_run",...]        — Supabase-synced rows
//
// Regression: locally-created user foods stored categories as a pg brace-string
// while the planner parsed them with jsonDecode (which throws on braces), so the
// user's phase tags were silently dropped and the food surfaced in ALL phases.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/client_plan/client_food_pool_service.dart';

void main() {
  late ProviderContainer container;
  late ClientFoodPoolService service;

  setUp(() {
    container = ProviderContainer();
    service = container.read(clientFoodPoolServiceProvider);
  });
  tearDown(() => container.dispose());

  group('parseCategoryList', () {
    test('parses PostgreSQL array literal (locally-created user foods)', () {
      expect(
        service.parseCategoryList('{before_run,during_run}'),
        ['before_run', 'during_run'],
      );
    });

    test('parses JSON array (Supabase-synced user foods)', () {
      expect(
        service.parseCategoryList('["before_run","during_run"]'),
        ['before_run', 'during_run'],
      );
    });

    test('tolerates whitespace and quotes in the pg literal', () {
      expect(
        service.parseCategoryList('{ "after_run" , during_run }'),
        ['after_run', 'during_run'],
      );
    });

    test('empty / null / empty-collection variants return []', () {
      expect(service.parseCategoryList(null), isEmpty);
      expect(service.parseCategoryList(''), isEmpty);
      expect(service.parseCategoryList('   '), isEmpty);
      expect(service.parseCategoryList('{}'), isEmpty);
      expect(service.parseCategoryList('[]'), isEmpty);
    });

    test('single-value pg literal', () {
      expect(service.parseCategoryList('{during_run}'), ['during_run']);
    });
  });
}
