/// `AppDatabase.clearUserData` and `sweepOtherAccounts` (ticket 102, Lee's
/// ruling of 2026-09-25): the local wipe deletes only rows the server already
/// has. A row with `needs_upload = 1` stays with the parents it re-uploads
/// through, the `users` row stays while anything unsynced stays, the two
/// local-only tables always stay, and `food_preferences` (no flag) stays only
/// when the caller says so. Account deletion still deletes everything.
library;

import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/shared/database/app_database.dart';

const _a = 'aaaaaaaa-0000-4000-8000-000000000001';
const _b = 'bbbbbbbb-0000-4000-8000-000000000002';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
    addTearDown(db.close);
  });

  Future<int> count(String table, String userId, {String where = ''}) async {
    final rows = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM $table WHERE user_id = ? $where',
          variables: [Variable<String>(userId)],
        )
        .get();
    return rows.single.read<int>('n');
  }

  Future<int> countUsers(String userId) async {
    final rows = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM users WHERE id = ? OR auth_user_id = ?',
          variables: [Variable<String>(userId), Variable<String>(userId)],
        )
        .get();
    return rows.single.read<int>('n');
  }

  Future<int> countDays(String userId, {String where = ''}) async {
    final rows = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM carb_loading_days WHERE '
          'carb_loading_plan_id IN '
          '(SELECT id FROM carb_loading_plans WHERE user_id = ?) $where',
          variables: [Variable<String>(userId)],
        )
        .get();
    return rows.single.read<int>('n');
  }

  Future<int> countDayMeals(String userId) async {
    final rows = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM carb_loading_day_meals WHERE '
          'carb_loading_day_id IN (SELECT id FROM carb_loading_days WHERE '
          'carb_loading_plan_id IN '
          '(SELECT id FROM carb_loading_plans WHERE user_id = ?))',
          variables: [Variable<String>(userId)],
        )
        .get();
    return rows.single.read<int>('n');
  }

  group('clearUserData(keepUnsynced: true), the sign-out rule', () {
    test('clean rows go, dirty rows and their parents stay', () async {
      await _seedAccount(db, _a, withDirtyRows: true);

      await db.clearUserData(_a, keepUnsynced: true);

      // Clean rows are gone.
      expect(await count('activities', _a, where: 'AND needs_upload = 0'), 0);
      expect(await count('meal_logs', _a, where: 'AND needs_upload = 0'), 0);
      expect(await count('events', _a), 0);
      expect(await count('user_entitlements', _a), 0, reason: 'no flag: goes');
      // Dirty rows stay.
      expect(await count('activities', _a, where: 'AND needs_upload = 1'), 1);
      expect(await count('meal_logs', _a, where: 'AND needs_upload = 1'), 1);
      // The dirty plan meal keeps its plan; the clean plan goes.
      expect(await count('plan_meals', _a), 1);
      expect(await count('meal_plans', _a), 1);
      final plans = await db
          .customSelect(
            'SELECT id FROM meal_plans WHERE user_id = ?',
            variables: [Variable<String>(_a)],
          )
          .get();
      expect(plans.single.read<String>('id'), 'plan-dirty-meal-$_a');
      // The dirty day keeps its plan and its meals; the clean plan goes.
      expect(await count('carb_loading_plans', _a), 1);
      expect(await countDays(_a), 1);
      expect(await countDays(_a, where: 'AND needs_upload = 1'), 1);
      expect(await countDayMeals(_a), 1);
      // The profile stays while dirty rows stay.
      expect(await countUsers(_a), 1);
    });

    test('the two local-only tables always stay', () async {
      await _seedAccount(db, _a, withDirtyRows: false);

      await db.clearUserData(_a, keepUnsynced: true);

      expect(await count('race_checklist_items', _a), 1);
      expect(await count('carb_loading_user_foods', _a), 1);
    });

    test('nothing unsynced: the profile and food preferences go too', () async {
      await _seedAccount(db, _a, withDirtyRows: false);

      await db.clearUserData(_a, keepUnsynced: true);

      expect(await countUsers(_a), 0);
      expect(await count('food_preferences_table', _a), 0);
      expect(await count('activities', _a), 0);
      expect(await count('meal_plans', _a), 0);
      expect(await count('carb_loading_plans', _a), 0);
    });

    test('keepFoodPreferences keeps them and the profile', () async {
      await _seedAccount(db, _a, withDirtyRows: false);

      await db.clearUserData(_a, keepUnsynced: true, keepFoodPreferences: true);

      expect(await count('food_preferences_table', _a), 1);
      expect(await countUsers(_a), 1);
      expect(await count('activities', _a), 0);
    });

    test('a profile that itself needs upload stays', () async {
      await _seedAccount(db, _a, withDirtyRows: false, profileDirty: true);

      await db.clearUserData(_a, keepUnsynced: true);

      expect(await countUsers(_a), 1);
    });

    test('another account is untouched', () async {
      await _seedAccount(db, _a, withDirtyRows: true);
      await _seedAccount(db, _b, withDirtyRows: true);

      await db.clearUserData(_a, keepUnsynced: true);

      expect(await count('activities', _b), 2);
      expect(await count('meal_plans', _b), 2);
      expect(await count('food_preferences_table', _b), 1);
      expect(await countUsers(_b), 1);
    });
  });

  group('clearUserData(), account deletion', () {
    test('everything of the account goes, dirty or local-only', () async {
      await _seedAccount(db, _a, withDirtyRows: true, profileDirty: true);

      await db.clearUserData(_a);

      for (final table in [
        'activities',
        'meal_logs',
        'events',
        'meal_plans',
        'plan_meals',
        'carb_loading_plans',
        'food_preferences_table',
        'race_checklist_items',
        'carb_loading_user_foods',
        'user_entitlements',
      ]) {
        expect(await count(table, _a), 0, reason: table);
      }
      expect(await countDays(_a), 0);
      expect(await countDayMeals(_a), 0);
      expect(await countUsers(_a), 0);
    });
  });

  group('sweepOtherAccounts, the sign-in rule (86-001)', () {
    test("the other account's clean rows go, its dirty rows stay; "
        'the signed-in account is untouched', () async {
      await _seedAccount(db, _a, withDirtyRows: true);
      await _seedAccount(db, _b, withDirtyRows: true);

      final swept = await db.sweepOtherAccounts(_b);

      expect(swept, [_a]);
      expect(await count('activities', _a, where: 'AND needs_upload = 0'), 0);
      expect(await count('activities', _a, where: 'AND needs_upload = 1'), 1);
      expect(await count('meal_plans', _a), 1);
      expect(await countUsers(_a), 1);
      // food_preferences stay while the account has anything unsynced.
      expect(await count('food_preferences_table', _a), 1);
      // Local-only rows stay.
      expect(await count('race_checklist_items', _a), 1);

      expect(await count('activities', _b), 2);
      expect(await count('meal_plans', _b), 2);
      expect(await count('food_preferences_table', _b), 1);
      expect(await countUsers(_b), 1);
    });

    test(
      'a fully synced other account leaves nothing but local-only rows',
      () async {
        await _seedAccount(db, _a, withDirtyRows: false);
        await _seedAccount(db, _b, withDirtyRows: false);

        await db.sweepOtherAccounts(_b);

        expect(await count('activities', _a), 0);
        expect(await count('food_preferences_table', _a), 0);
        expect(await countUsers(_a), 0);
        expect(await count('race_checklist_items', _a), 1);
        expect(await count('carb_loading_user_foods', _a), 1);
        expect(await countUsers(_b), 1);
      },
    );

    test('a legacy profile whose id differs from its auth id is the signed-in '
        'account under both ids', () async {
      const legacyId = 'device-profile-0000-4000-8000-000000000009';
      await _seedAccount(db, legacyId, withDirtyRows: false, authUserId: _b);

      final swept = await db.sweepOtherAccounts(_b);

      expect(swept, isEmpty);
      expect(await count('activities', legacyId), 2);
      expect(await countUsers(legacyId), 1);
    });
  });
}

/// Seeds one account: two activities (one dirty when [withDirtyRows]), two
/// meal logs (one dirty), an event, two meal plans (one with a dirty plan
/// meal), two carb-loading plans (one with a dirty day that has a meal), a
/// food preference, an entitlement, a race checklist item and a
/// carb-loading user food.
Future<void> _seedAccount(
  AppDatabase db,
  String userId, {
  required bool withDirtyRows,
  bool profileDirty = false,
  String? authUserId,
}) async {
  final now = DateTime.utc(2026, 9, 25, 12);
  await db
      .into(db.userProfilesTable)
      .insert(
        UserProfilesTableCompanion.insert(
          id: userId,
          deviceId: 'device-$userId',
          authUserId: Value(authUserId ?? userId),
          email: Value('$userId@example.com'),
          needsUpload: Value(profileDirty),
        ),
      );
  await db
      .into(db.carbLoadingUserFoodsTable)
      .insert(
        CarbLoadingUserFoodsTableCompanion.insert(
          id: 'cluf-$userId',
          deviceId: 'device-$userId',
          userId: userId,
          name: 'my_pasta',
          displayName: 'My pasta',
          carbsPerServing: 65,
        ),
      );
  for (final second in [false, true]) {
    final dirty = second && withDirtyRows;
    await db
        .into(db.activitiesTable)
        .insert(
          ActivitiesTableCompanion.insert(
            userId: userId,
            activityType: 'running',
            title: dirty ? 'Offline run' : 'Easy run',
            scheduledDateTime: now,
            createdAt: now,
            updatedAt: now,
            needsUpload: Value(dirty),
          ),
        );
    await db
        .into(db.mealLogsTable)
        .insert(
          MealLogsTableCompanion.insert(
            userId: userId,
            logDate: '2026-09-25',
            name: dirty ? 'Offline oats' : 'Oats',
            source: 'manual',
            createdAt: now,
            updatedAt: now,
            needsUpload: Value(dirty),
          ),
        );
  }
  await db
      .into(db.eventsTable)
      .insert(
        EventsTableCompanion.insert(
          userId: userId,
          eventType: 'running',
          createdAt: now,
          updatedAt: now,
        ),
      );

  // Two meal plans: a clean one, and one whose plan meal is dirty.
  for (final second in [false, true]) {
    final dirtyMeal = second && withDirtyRows;
    final planId = second ? 'plan-dirty-meal-$userId' : 'plan-clean-$userId';
    await db
        .into(db.mealPlansTable)
        .insert(
          MealPlansTableCompanion.insert(
            id: Value(planId),
            userId: userId,
            weekStart: dirtyMeal ? '2026-09-28' : '2026-09-21',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.planMealsTable)
        .insert(
          PlanMealsTableCompanion.insert(
            planId: planId,
            userId: userId,
            source: 'library',
            name: 'Bowl',
            mealType: 'dinner',
            createdAt: now,
            updatedAt: now,
            needsUpload: Value(dirtyMeal),
          ),
        );
  }

  // Two carb-loading plans: a clean one, and one with a dirty day + a meal.
  for (final second in [false, true]) {
    final dirtyDay = second && withDirtyRows;
    final planId = second ? 'carb-dirty-day-$userId' : 'carb-clean-$userId';
    await db
        .into(db.carbLoadingPlansTable)
        .insert(
          CarbLoadingPlansTableCompanion.insert(
            id: Value(planId),
            userId: userId,
            totalDays: 1,
            startDate: now,
            endDate: now,
            dailyCarbTargetGrams: 500,
            generatedAt: now,
          ),
        );
    final dayId = 'day-$planId';
    await db
        .into(db.carbLoadingDaysTable)
        .insert(
          CarbLoadingDaysTableCompanion.insert(
            id: Value(dayId),
            carbLoadingPlanId: planId,
            planDate: now,
            dayNumber: 1,
            carbTargetGrams: 500,
            needsUpload: Value(dirtyDay),
          ),
        );
    await db
        .into(db.carbLoadingDayMealsTable)
        .insert(
          CarbLoadingDayMealsTableCompanion.insert(
            carbLoadingDayId: dayId,
            mealTypeId: 1,
            carbLoadingUserFoodId: Value('cluf-$userId'),
            carbsConsumed: 60,
          ),
        );
  }

  await db
      .into(db.foodPreferencesTable)
      .insert(
        FoodPreferencesTableCompanion.insert(
          id: '$userId-pref-000000000000000000000'.substring(0, 36),
          userId: userId,
          foodName: 'cilantro',
          preference: 'dislike',
        ),
      );
  await db
      .into(db.userEntitlementsTable)
      .insert(
        UserEntitlementsTableCompanion.insert(
          userId: userId,
          entitlement: 'pro',
          active: const Value(true),
          updatedAt: now,
          fetchedAt: now,
        ),
      );
  await db
      .into(db.raceChecklistItemsTable)
      .insert(
        RaceChecklistItemsTableCompanion.insert(
          eventId: 'event-$userId',
          userId: userId,
          category: 'gear',
          itemName: 'Shoes',
        ),
      );
}
