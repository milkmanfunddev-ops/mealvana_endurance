import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/mock_supabase_client.dart';
import '../helpers/test_logger.dart';

void main() {
  late AppDatabase database;
  late MockSupabaseClient mockSupabase;
  late AppLogger logger;
  late CarbLoadingRepository repository;

  setUp(() async {
    // Initialize SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});

    // Create in-memory database
    database = AppDatabase.testInstance(NativeDatabase.memory());

    // Create mock Supabase client
    mockSupabase = MockSupabaseClient();

    // Create test logger
    logger = TestLogger();

    // Create repository
    repository = CarbLoadingRepository(
      supabase: mockSupabase as SupabaseClient,
      database: database,
      logger: logger,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('CarbLoadingRepository - SyncableRepository', () {
    test('repositoryKey returns correct value', () {
      expect(repository.repositoryKey, 'carb_loading_plans');
    });

    test('dependencies include users and events', () {
      expect(repository.dependencies, ['users', 'events']);
    });

    test('isStale returns true when never synced', () async {
      final isStale = await repository.isStale();
      expect(isStale, true);
    });

    test('isStale returns false when recently synced', () async {
      await repository.setLastSyncTime(DateTime.now());
      final isStale = await repository.isStale();
      expect(isStale, false);
    });

    test('syncFromRemote syncs plans, days, and meals successfully', () async {
      const userId = 'test-user-id';
      const planId = 'plan-123';
      const dayId = 'day-456';
      const mealId = 'meal-789';

      // Mock Supabase responses
      final plansResponse = [
        {
          'id': planId,
          'user_id': userId,
          'event_id': 'event-123',
          'total_days': 3,
          'start_date': '2026-01-15',
          'end_date': '2026-01-17',
          'daily_carb_target_grams': 600,
          'generated_at': '2026-01-14T12:00:00Z',
          'algorithm_version': 'v1.0',
          'adherence_score': null,
          'completed_at': null,
        }
      ];

      final daysResponse = [
        {
          'id': dayId,
          'carb_loading_plan_id': planId,
          'plan_date': '2026-01-15',
          'day_number': 1,
          'carb_target_grams': 600,
          'carb_protocol_g_per_kg': 8.0,
          'meal_count': 6,
          'breakfast_percent': 16.67,
          'morning_snack_percent': 16.67,
          'lunch_percent': 16.67,
          'afternoon_snack_percent': 16.67,
          'dinner_percent': 16.67,
          'evening_snack_percent': 16.67,
          'logged_carbs_grams': null,
          'logged_calories': null,
          'completed': false,
        }
      ];

      final mealsResponse = [
        {
          'id': mealId,
          'carb_loading_day_id': dayId,
          'food_id': 'food-123',
          'meal_time': 'breakfast',
          'servings': 1.5,
          'carbs_grams': 100,
          'completed': false,
        }
      ];

      mockSupabase.setResponse('carb_loading_plans', plansResponse);
      mockSupabase.setResponse('carb_loading_days', daysResponse);
      mockSupabase.setResponse('carb_loading_day_meals', mealsResponse);

      // Sync from remote
      final result = await repository.syncFromRemote(userId);

      // Verify result
      expect(result.success, true);
      expect(result.count, 3); // 1 plan + 1 day + 1 meal

      // Verify data saved to Drift
      final plans = await database.select(database.carbLoadingPlansTable).get();
      expect(plans.length, 1);
      expect(plans.first.id, planId);
      expect(plans.first.userId, userId);
      expect(plans.first.needsUpload, false); // Should not be dirty

      final days = await database.select(database.carbLoadingDaysTable).get();
      expect(days.length, 1);
      expect(days.first.id, dayId);
      expect(days.first.carbLoadingPlanId, planId);
      expect(days.first.needsUpload, false);

      final meals = await database.select(database.carbLoadingDayMealsTable).get();
      expect(meals.length, 1);
      expect(meals.first.id, mealId);
      expect(meals.first.carbLoadingDayId, dayId);
      expect(meals.first.needsUpload, false);

      // Verify last sync time updated
      final lastSync = await repository.getLastSyncTime();
      expect(lastSync, isNotNull);
    });

    test('syncFromRemote handles empty plans gracefully', () async {
      const userId = 'test-user-id';

      // Mock empty response
      mockSupabase.setResponse('carb_loading_plans', []);

      // Sync from remote
      final result = await repository.syncFromRemote(userId);

      // Verify result
      expect(result.success, true);
      expect(result.count, 0);

      // Verify last sync time updated even with no data
      final lastSync = await repository.getLastSyncTime();
      expect(lastSync, isNotNull);
    });

    test('syncFromRemote handles error gracefully', () async {
      const userId = 'test-user-id';

      // Mock error
      mockSupabase.setError('carb_loading_plans', 'Network error');

      // Sync from remote
      final result = await repository.syncFromRemote(userId);

      // Verify result
      expect(result.success, false);
      expect(result.error, contains('Network error'));
    });

    test('uploadDirtyRecords uploads all dirty records successfully', () async {
      const userId = 'test-user-id';
      const planId = 'plan-123';
      const dayId = 'day-456';
      const mealId = 'meal-789';

      // Insert dirty records into Drift
      await database.into(database.carbLoadingPlansTable).insert(
        CarbLoadingPlansTableCompanion.insert(
          id: const Value(planId),
          userId: userId,
          totalDays: 3,
          startDate: DateTime(2026, 1, 15),
          endDate: DateTime(2026, 1, 17),
          dailyCarbTargetGrams: 600,
          generatedAt: DateTime.now(),
          needsUpload: const Value(true),
          localUpdatedAt: Value(DateTime.now()),
        ),
      );

      await database.into(database.carbLoadingDaysTable).insert(
        CarbLoadingDaysTableCompanion.insert(
          id: const Value(dayId),
          carbLoadingPlanId: planId,
          planDate: DateTime(2026, 1, 15),
          dayNumber: 1,
          carbTargetGrams: 600,
          needsUpload: const Value(true),
          localUpdatedAt: Value(DateTime.now()),
        ),
      );

      await database.into(database.carbLoadingDayMealsTable).insert(
        CarbLoadingDayMealsTableCompanion.insert(
          id: const Value(mealId),
          carbLoadingDayId: dayId,
          foodId: 'food-123',
          mealTime: 'breakfast',
          servings: 1.5,
          carbsGrams: 100,
          needsUpload: const Value(true),
          localUpdatedAt: Value(DateTime.now()),
        ),
      );

      // Upload dirty records
      final result = await repository.uploadDirtyRecords(userId);

      // Verify result
      expect(result.success, true);
      expect(result.count, 3); // 1 plan + 1 day + 1 meal

      // Verify dirty flags cleared
      final plans = await database.select(database.carbLoadingPlansTable).get();
      expect(plans.first.needsUpload, false);

      final days = await database.select(database.carbLoadingDaysTable).get();
      expect(days.first.needsUpload, false);

      final meals = await database.select(database.carbLoadingDayMealsTable).get();
      expect(meals.first.needsUpload, false);
    });

    test('uploadDirtyRecords returns nothingToUpload when no dirty records', () async {
      const userId = 'test-user-id';

      // Upload with no dirty records
      final result = await repository.uploadDirtyRecords(userId);

      // Verify result
      expect(result.success, true);
      expect(result.count, 0);
    });

    test('uploadDirtyRecords handles error gracefully', () async {
      const userId = 'test-user-id';
      const planId = 'plan-123';

      // Insert dirty plan
      await database.into(database.carbLoadingPlansTable).insert(
        CarbLoadingPlansTableCompanion.insert(
          id: const Value(planId),
          userId: userId,
          totalDays: 3,
          startDate: DateTime(2026, 1, 15),
          endDate: DateTime(2026, 1, 17),
          dailyCarbTargetGrams: 600,
          generatedAt: DateTime.now(),
          needsUpload: const Value(true),
          localUpdatedAt: Value(DateTime.now()),
        ),
      );

      // Mock upload error
      mockSupabase.setError('carb_loading_plans', 'Upload failed');

      // Upload dirty records
      final result = await repository.uploadDirtyRecords(userId);

      // Verify result
      expect(result.success, false);
      expect(result.error, contains('Upload failed'));

      // Verify dirty flags NOT cleared (will retry later)
      final plans = await database.select(database.carbLoadingPlansTable).get();
      expect(plans.first.needsUpload, true);
    });

    test('uploadDirtyRecords only uploads records for specified user', () async {
      const user1Id = 'user-1';
      const user2Id = 'user-2';

      // Insert dirty plans for both users
      await database.into(database.carbLoadingPlansTable).insert(
        CarbLoadingPlansTableCompanion.insert(
          userId: user1Id,
          totalDays: 3,
          startDate: DateTime(2026, 1, 15),
          endDate: DateTime(2026, 1, 17),
          dailyCarbTargetGrams: 600,
          generatedAt: DateTime.now(),
          needsUpload: const Value(true),
          localUpdatedAt: Value(DateTime.now()),
        ),
      );

      await database.into(database.carbLoadingPlansTable).insert(
        CarbLoadingPlansTableCompanion.insert(
          userId: user2Id,
          totalDays: 3,
          startDate: DateTime(2026, 1, 15),
          endDate: DateTime(2026, 1, 17),
          dailyCarbTargetGrams: 600,
          generatedAt: DateTime.now(),
          needsUpload: const Value(true),
          localUpdatedAt: Value(DateTime.now()),
        ),
      );

      // Upload for user1 only
      final result = await repository.uploadDirtyRecords(user1Id);

      // Verify only user1's plan uploaded
      expect(result.success, true);
      expect(result.count, 1);

      // Verify user2's plan still dirty
      final allPlans = await database.select(database.carbLoadingPlansTable).get();
      final user2Plan = allPlans.firstWhere((p) => p.userId == user2Id);
      expect(user2Plan.needsUpload, true);
    });
  });
}
