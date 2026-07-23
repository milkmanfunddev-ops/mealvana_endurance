import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression coverage for Bug 38be3fdb — "Duplicate SiS salted strawberry
/// gels appear in food/fuel list".
///
/// The same catalog food could be persisted through two save paths that
/// assigned different `device_id` values (profile.id vs profile.deviceId), so
/// the `UNIQUE(device_id, client_food_id)` constraint never fired and the food
/// showed up twice. The fix dedupes by `client_food_id` at read time and adds a
/// `client_food_id`-based duplicate check used by the Add Food screen.
void main() {
  late AppDatabase database;

  const userId = 'user-uuid-123';
  const legacyDeviceId = 'legacy-device-456';
  const clientFoodId = 'sis-salted-strawberry-gel';

  // UserFoodsTable.id requires 36-char (UUID-length) ids.
  const id1 = '00000000-0000-0000-0000-000000000001';
  const id2 = '00000000-0000-0000-0000-000000000002';
  const idOther = '00000000-0000-0000-0000-000000000003';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> saveGel({
    required String id,
    required String deviceId,
    required String userId,
  }) {
    return database.foodsDao.saveUserFood(
      deviceId: deviceId,
      userId: userId,
      id: id,
      clientFoodId: clientFoodId,
      name: 'SiS Salted Strawberry Gel',
      categories: const ['during_run'],
    );
  }

  test('getUserFoods returns one row when the same client_food_id is saved via '
      'two paths with different device_id values', () async {
    // Path 1 (AddFoodScreen, pre-fix): device_id == user_id.
    await saveGel(id: id1, deviceId: userId, userId: userId);
    // Path 2 (UserFoodCrudService): device_id == legacy device id.
    await saveGel(id: id2, deviceId: legacyDeviceId, userId: userId);

    final foods = await database.foodsDao.getUserFoods(userId);

    final gels = foods.where((f) => f.clientFoodId == clientFoodId).toList();
    expect(
      gels,
      hasLength(1),
      reason: 'duplicate catalog food should be collapsed to one entry',
    );
  });

  test(
    'getUserFoods keeps distinct foods and null-clientFoodId rows',
    () async {
      await saveGel(id: id1, deviceId: userId, userId: userId);
      // A different catalog food.
      await database.foodsDao.saveUserFood(
        deviceId: userId,
        userId: userId,
        id: idOther,
        clientFoodId: 'maurten-gel-100',
        name: 'Maurten Gel 100',
        categories: const ['during_run'],
      );

      final foods = await database.foodsDao.getUserFoods(userId);
      expect(foods, hasLength(2));
    },
  );

  test('hasUserFoodWithClientFoodId detects an existing food saved via the '
      'legacy device_id path', () async {
    await saveGel(id: id1, deviceId: legacyDeviceId, userId: userId);

    // The Add Food screen now checks by user_id, even though the existing row
    // was persisted with a different device_id.
    final hasDuplicate = await database.foodsDao.hasUserFoodWithClientFoodId(
      userId,
      clientFoodId,
    );
    expect(hasDuplicate, isTrue);
  });

  test(
    'hasUserFoodWithClientFoodId returns false for an unknown food',
    () async {
      await saveGel(id: id1, deviceId: userId, userId: userId);

      final hasDuplicate = await database.foodsDao.hasUserFoodWithClientFoodId(
        userId,
        'never-saved-food',
      );
      expect(hasDuplicate, isFalse);
    },
  );
}
